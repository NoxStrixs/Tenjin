#include <ViewModels/FormulaItem.h>
#include <ViewModels/MicroTexGraphics_qt.h>

#include <QDebug>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QPainter>
#include <QStandardPaths>

#include "latex.h"
#include "render.h"

namespace Tenjin {

// Defined here so MicroTeX's headers never reach FormulaItem.h.
struct FormulaItem::Impl {
    // MicroTeX hands back a raw TeXRender* whose ownership passes to us.
    std::unique_ptr<tex::TeXRender> render;
};

namespace {

// MicroTeX's LaTeX::init() takes a FILESYSTEM path to its res/ tree (fonts +
// XML symbol/parser tables, ~2 MB). Qt resources live inside the binary and are
// not real files, so on every platform we extract res/ once into the app's data
// directory and hand MicroTeX that path.
//
// This is what makes iOS work: the sandbox has no writable location next to the
// executable, and MicroTeX cannot read qrc: paths. AppDataLocation is writable
// and persistent on all five targets.
//
// Extraction is idempotent and versioned: bump kResVersion whenever the bundled
// res/ contents change so an upgraded app refreshes a stale extraction.
constexpr int kResVersion = 1;

QString resRoot()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
           + QStringLiteral("/microtex-res-v") + QString::number(kResVersion);
}

// Copy :/microtex/res/** onto disk. Returns the destination root, or empty on
// failure (in which case formulas render as an error rather than crashing).
QString extractResources()
{
    const QString dest = resRoot();
    // A marker file written last: its presence means a previous extraction
    // completed, so a half-finished copy (app killed mid-extract) is retried.
    const QString marker = dest + QStringLiteral("/.complete");
    if (QFile::exists(marker))
        return dest;

    QDir().mkpath(dest);

    const QString prefix = QStringLiteral(":/microtex/res");
    if (!QDir(prefix).exists()) {
        qWarning() << "MicroTeX resources missing from the binary"
                   << "— was Assets.cmake/qt_add_resources wired up?";
        return {};
    }

    QDirIterator it(prefix, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString src = it.next();
        // ":/microtex/res/greek/fcmrpg.ttf" -> "<dest>/greek/fcmrpg.ttf"
        const QString rel = src.mid(prefix.length() + 1);
        const QString out = dest + QLatin1Char('/') + rel;
        QDir().mkpath(QFileInfo(out).absolutePath());
        // Remove first: QFile::copy won't overwrite, and a partial file from an
        // interrupted run would otherwise persist forever.
        QFile::remove(out);
        if (!QFile::copy(src, out)) {
            qWarning() << "MicroTeX: failed to extract" << rel;
            return {};
        }
        // Qt resources are read-only; the copies inherit that. MicroTeX only
        // reads them, but make them user-writable so a future version bump can
        // replace them.
        QFile::setPermissions(out, QFile::ReadOwner | QFile::WriteOwner);
    }

    QFile m(marker);
    if (m.open(QIODevice::WriteOnly))
        m.close();
    return dest;
}

// Initialise MicroTeX exactly once per process. Returns false if the resources
// couldn't be prepared or MicroTeX rejected them.
bool ensureInit(QString* error)
{
    static bool    s_tried = false;
    static bool    s_ok    = false;
    static QString s_error;

    if (s_tried) {
        if (error != nullptr)
            *error = s_error;
        return s_ok;
    }
    s_tried = true;

    const QString root = extractResources();
    if (root.isEmpty()) {
        s_error = QObject::tr("Math resources unavailable.");
        if (error != nullptr)
            *error = s_error;
        return false;
    }

    try {
        // MicroTeX throws (ex_res_parse / ex_invalid_state) on malformed or
        // missing resources; let that surface as an error string rather than
        // taking the app down.
        tex::LaTeX::init(root.toStdString());
        s_ok = true;
    } catch (const std::exception& e) {
        s_error = QString::fromUtf8(e.what());
        qWarning() << "MicroTeX init failed:" << s_error;
    } catch (...) {
        s_error = QObject::tr("Math engine failed to start.");
        qWarning() << "MicroTeX init failed with an unknown exception";
    }

    if (error != nullptr)
        *error = s_error;
    return s_ok;
}

// MicroTeX colors are ARGB uint32.
tex::color toTexColor(const QColor& c)
{
    return tex::argb(c.alpha(), c.red(), c.green(), c.blue());
}

} // namespace

FormulaItem::FormulaItem(QQuickItem* parent)
    : QQuickPaintedItem(parent), d(std::make_unique<Impl>())
{
    // Formulas are static once laid out; cache the raster rather than
    // re-running MicroTeX's box model on every frame.
    setRenderTarget(QQuickPaintedItem::FramebufferObject);
    setAntialiasing(true);
}

FormulaItem::~FormulaItem() = default;

void FormulaItem::setLatex(const QString& v)
{
    if (m_latex == v)
        return;
    m_latex = v;
    emit latexChanged();
    rebuild();
}

void FormulaItem::setColor(const QColor& v)
{
    if (m_color == v)
        return;
    m_color = v;
    emit colorChanged();
    // Colour is baked into the render tree, so rebuild rather than repaint.
    rebuild();
}

void FormulaItem::setFontSize(qreal v)
{
    if (qFuzzyCompare(m_fontSize, v))
        return;
    m_fontSize = v;
    emit fontSizeChanged();
    rebuild();
}

void FormulaItem::setError(const QString& e)
{
    if (m_error == e)
        return;
    m_error = e;
    emit errorStringChanged();
}

void FormulaItem::rebuild()
{
    d->render.reset();

    if (m_latex.trimmed().isEmpty()) {
        setError({});
        setImplicitSize(0, 0);
        update();
        return;
    }

    QString initError;
    if (!ensureInit(&initError)) {
        setError(initError);
        setImplicitSize(0, 0);
        update();
        return;
    }

    try {
        // width=0 means "no wrapping"; MicroTeX sizes to the content.
        tex::TeXRender* r = tex::LaTeX::parse(
            m_latex.toStdWString(),
            0,
            static_cast<float>(m_fontSize),
            static_cast<float>(m_fontSize) / 3.f, // line spacing
            toTexColor(m_color));
        d->render.reset(r);
        setError({});
    } catch (const std::exception& e) {
        // Malformed LaTeX is user input, not a bug — report it and let QML fall
        // back to showing the source.
        setError(QString::fromUtf8(e.what()));
        setImplicitSize(0, 0);
        update();
        return;
    } catch (...) {
        setError(tr("Could not parse this formula."));
        setImplicitSize(0, 0);
        update();
        return;
    }

    if (d->render) {
        // getHeight() is the height above the baseline and getDepth() the part
        // below it (descenders on \frac, \sqrt, subscripts). Upstream's own
        // sample sizes its canvas with height + depth, and clipping descenders
        // is the classic failure here, so include both. If a future MicroTeX
        // makes getHeight() inclusive this over-reserves by getDepth() rather
        // than cutting glyphs off — the safe direction to be wrong in.
        const int w = d->render->getWidth();
        const int h = d->render->getHeight() + d->render->getDepth();
        setImplicitSize(w, h);
    }
    update();
}

void FormulaItem::paint(QPainter* painter)
{
    if (!d->render || painter == nullptr)
        return;
    tenjin::QtGraphics2D g2(painter);
    // draw() takes the TOP-LEFT of the formula box (it offsets to the baseline
    // internally), so painting at the item origin is correct.
    d->render->draw(g2, 0, 0);
}

} // namespace Tenjin
