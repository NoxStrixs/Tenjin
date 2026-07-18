// MicroTeX -> QPainter bridge implementation.
//
// Verified against MicroTeX's src/graphic/graphic.h, graphic_basic.h, latex.h
// and render.h. Notes that drove the implementation:
//   * tex::color is uint32 ARGB; color_a/r/g/b() extract components.
//   * tex::Stroke carries lineWidth, cap (CAP_BUTT/ROUND/SQUARE), join
//     (JOIN_BEVEL/MITER/ROUND) and miterLimit -> maps onto QPen.
//   * drawChar/drawText are BASELINE aligned. QPainter::drawText(QPointF, ...)
//     is baseline aligned too, so those map directly.
//   * Rect is {x, y, w, h} floats.

#include <ViewModels/MicroTexGraphics_qt.h>

#include <QFontDatabase>
#include <QFontMetricsF>
#include <QPainterPath>


namespace tenjin {
namespace {

// std::numbers::pi is C++20; these two TUs compile as C++17 (they include
// MicroTeX headers that don't build under C++23). A local constant avoids both
// that and MSVC's missing M_PI.
constexpr double kPi = 3.14159265358979323846;

QColor toQColor(tex::color c)
{
    // ARGB uint32 -> QColor. tex's helpers return `color` (uint32), so narrow
    // explicitly rather than with C-style casts.
    return QColor(static_cast<int>(tex::color_r(c)),
                  static_cast<int>(tex::color_g(c)),
                  static_cast<int>(tex::color_b(c)),
                  static_cast<int>(tex::color_a(c)));
}

Qt::PenCapStyle toQtCap(tex::Cap c)
{
    switch (c) {
    case tex::CAP_BUTT:
        return Qt::FlatCap;
    case tex::CAP_ROUND:
        return Qt::RoundCap;
    case tex::CAP_SQUARE:
        return Qt::SquareCap;
    }
    return Qt::FlatCap;
}

Qt::PenJoinStyle toQtJoin(tex::Join j)
{
    switch (j) {
    case tex::JOIN_BEVEL:
        return Qt::BevelJoin;
    case tex::JOIN_MITER:
        return Qt::MiterJoin;
    case tex::JOIN_ROUND:
        return Qt::RoundJoin;
    }
    return Qt::MiterJoin;
}

QString toQString(const std::wstring& s)
{
    return QString::fromStdWString(s);
}

} // namespace

// ── QtFont ───────────────────────────────────────────────────────────────────

QtFont::QtFont(QString family, int style, float size) : m_size(size)
{
    m_font.setFamily(family);
    m_font.setPointSizeF(static_cast<qreal>(size));
    m_font.setBold((style & tex::BOLD) != 0);
    m_font.setItalic((style & tex::ITALIC) != 0);
}

QtFont::QtFont(const QFont& f) : m_font(f)
{
    m_size = static_cast<float>(f.pointSizeF() > 0 ? f.pointSizeF() : f.pixelSize());
}

float QtFont::getSize() const
{
    return m_size;
}

tex::sptr<tex::Font> QtFont::deriveFont(int style) const
{
    QFont f = m_font;
    f.setBold((style & tex::BOLD) != 0);
    f.setItalic((style & tex::ITALIC) != 0);
    return std::make_shared<QtFont>(f);
}

bool QtFont::operator==(const tex::Font& f) const
{
    const auto* other = dynamic_cast<const QtFont*>(&f);
    return other != nullptr && other->m_font == m_font;
}

bool QtFont::operator!=(const tex::Font& f) const
{
    return !(*this == f);
}

// ── QtTextLayout ─────────────────────────────────────────────────────────────

QtTextLayout::QtTextLayout(const std::wstring& src, const tex::sptr<tex::Font>& font)
    : m_text(toQString(src))
{
    const auto* qf = dynamic_cast<const QtFont*>(font.get());
    if (qf != nullptr)
        m_font = qf->qfont();
}

void QtTextLayout::getBounds(tex::Rect& bounds)
{
    const QFontMetricsF fm(m_font);
    const QRectF        r = fm.boundingRect(m_text);
    bounds.x = static_cast<float>(r.x());
    bounds.y = static_cast<float>(r.y());
    bounds.w = static_cast<float>(r.width());
    bounds.h = static_cast<float>(r.height());
}

void QtTextLayout::draw(tex::Graphics2D& g2, float x, float y)
{
    auto* qg = dynamic_cast<QtGraphics2D*>(&g2);
    if (qg == nullptr)
        return;
    QtFont f(m_font);
    qg->setFont(&f);
    qg->drawText(m_text.toStdWString(), x, y);
}

// ── QtGraphics2D ─────────────────────────────────────────────────────────────

QtGraphics2D::QtGraphics2D(QPainter* painter) : m_painter(painter)
{
    if (m_painter != nullptr)
        m_painter->setRenderHint(QPainter::Antialiasing, true);
    applyPen();
}

void QtGraphics2D::applyPen()
{
    if (m_painter == nullptr)
        return;
    QPen pen(toQColor(m_color));
    pen.setWidthF(static_cast<qreal>(m_stroke.lineWidth));
    pen.setCapStyle(toQtCap(m_stroke.cap));
    pen.setJoinStyle(toQtJoin(m_stroke.join));
    if (m_stroke.miterLimit > 0.f)
        pen.setMiterLimit(static_cast<qreal>(m_stroke.miterLimit));
    m_painter->setPen(pen);
}

void QtGraphics2D::setColor(tex::color c)
{
    m_color = c;
    applyPen();
}

tex::color QtGraphics2D::getColor() const
{
    return m_color;
}

void QtGraphics2D::setStroke(const tex::Stroke& s)
{
    m_stroke = s;
    applyPen();
}

const tex::Stroke& QtGraphics2D::getStroke() const
{
    return m_stroke;
}

void QtGraphics2D::setStrokeWidth(float w)
{
    m_stroke.lineWidth = w;
    applyPen();
}

const tex::Font* QtGraphics2D::getFont() const
{
    return m_font;
}

void QtGraphics2D::setFont(const tex::Font* font)
{
    m_font = font;
    const auto* qf = dynamic_cast<const QtFont*>(font);
    if (qf != nullptr && m_painter != nullptr)
        m_painter->setFont(qf->qfont());
}

void QtGraphics2D::translate(float dx, float dy)
{
    if (m_painter != nullptr)
        m_painter->translate(static_cast<qreal>(dx), static_cast<qreal>(dy));
}

void QtGraphics2D::scale(float sx, float sy)
{
    m_sx *= sx;
    m_sy *= sy;
    if (m_painter != nullptr)
        m_painter->scale(static_cast<qreal>(sx), static_cast<qreal>(sy));
}

void QtGraphics2D::rotate(float angle)
{
    // MicroTeX passes radians; QPainter::rotate takes degrees.
    if (m_painter != nullptr)
        m_painter->rotate(static_cast<qreal>(angle) * 180.0 / kPi);
}

void QtGraphics2D::rotate(float angle, float px, float py)
{
    if (m_painter == nullptr)
        return;
    m_painter->translate(static_cast<qreal>(px), static_cast<qreal>(py));
    m_painter->rotate(static_cast<qreal>(angle) * 180.0 / kPi);
    m_painter->translate(-static_cast<qreal>(px), -static_cast<qreal>(py));
}

void QtGraphics2D::reset()
{
    if (m_painter != nullptr)
        m_painter->resetTransform();
    m_sx = 1.f;
    m_sy = 1.f;
}

float QtGraphics2D::sx() const
{
    return m_sx;
}

float QtGraphics2D::sy() const
{
    return m_sy;
}

void QtGraphics2D::drawChar(wchar_t c, float x, float y)
{
    drawText(std::wstring(1, c), x, y);
}

void QtGraphics2D::drawText(const std::wstring& c, float x, float y)
{
    if (m_painter == nullptr)
        return;
    // Both MicroTeX and QPainter's QPointF overload are baseline aligned.
    m_painter->drawText(QPointF(static_cast<qreal>(x), static_cast<qreal>(y)),
                        toQString(c));
}

void QtGraphics2D::drawLine(float x1, float y1, float x2, float y2)
{
    if (m_painter == nullptr)
        return;
    m_painter->drawLine(QPointF(static_cast<qreal>(x1), static_cast<qreal>(y1)),
                        QPointF(static_cast<qreal>(x2), static_cast<qreal>(y2)));
}

void QtGraphics2D::drawRect(float x, float y, float w, float h)
{
    if (m_painter == nullptr)
        return;
    m_painter->setBrush(Qt::NoBrush);
    m_painter->drawRect(QRectF(static_cast<qreal>(x), static_cast<qreal>(y),
                               static_cast<qreal>(w), static_cast<qreal>(h)));
}

void QtGraphics2D::fillRect(float x, float y, float w, float h)
{
    if (m_painter == nullptr)
        return;
    m_painter->fillRect(QRectF(static_cast<qreal>(x), static_cast<qreal>(y),
                               static_cast<qreal>(w), static_cast<qreal>(h)),
                        toQColor(m_color));
}

void QtGraphics2D::drawRoundRect(float x, float y, float w, float h, float rx, float ry)
{
    if (m_painter == nullptr)
        return;
    m_painter->setBrush(Qt::NoBrush);
    m_painter->drawRoundedRect(QRectF(static_cast<qreal>(x), static_cast<qreal>(y),
                                      static_cast<qreal>(w), static_cast<qreal>(h)),
                               static_cast<qreal>(rx), static_cast<qreal>(ry));
}

void QtGraphics2D::fillRoundRect(float x, float y, float w, float h, float rx, float ry)
{
    if (m_painter == nullptr)
        return;
    QPainterPath path;
    path.addRoundedRect(QRectF(static_cast<qreal>(x), static_cast<qreal>(y),
                               static_cast<qreal>(w), static_cast<qreal>(h)),
                        static_cast<qreal>(rx), static_cast<qreal>(ry));
    m_painter->fillPath(path, toQColor(m_color));
}

} // namespace tenjin

// ── MicroTeX host factories ──────────────────────────────────────────────────
// graphic.h declares these as static members with no definition: the HOST must
// provide them. Without these three, MicroTeX links with undefined symbols.

namespace tex {

Font* Font::create(const std::string& file, float size)
{
    // MicroTeX asks for a font by FILE path (its bundled math fonts). Qt loads
    // it into the app font database, then we wrap the resulting family.
    const int id = QFontDatabase::addApplicationFont(
        QString::fromStdString(file));
    QString family;
    if (id >= 0) {
        const QStringList fams = QFontDatabase::applicationFontFamilies(id);
        if (!fams.isEmpty())
            family = fams.first();
    }
    return new tenjin::QtFont(family, PLAIN, size);
}

sptr<Font> Font::_create(const std::string& name, int style, float size)
{
    return std::make_shared<tenjin::QtFont>(QString::fromStdString(name), style, size);
}

sptr<TextLayout> TextLayout::create(const std::wstring& src, const sptr<Font>& font)
{
    return std::make_shared<tenjin::QtTextLayout>(src, font);
}

} // namespace tex
