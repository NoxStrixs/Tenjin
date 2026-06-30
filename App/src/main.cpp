#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QPainter>
#include <QPixmap>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QSqlDatabase>
#include <QStandardPaths>
#include <QTextStream>

#include <exception>

#ifdef TENJIN_WEBVIEW
#    include <QtWebView/QtWebView>
#endif

// Static plugin imports are needed ONLY when Qt itself is built statically
// (iOS always; Android/desktop only with a static Qt). Guarding on the OS is
// wrong: Android here uses a SHARED Qt, where these qt_static_plugin_* symbols
// do not exist and the link fails. QT_STATIC is defined by Qt exactly when the
// static plugin machinery is present, so it is the correct discriminator.
#ifdef QT_STATIC
#    include <QtPlugin>
Q_IMPORT_PLUGIN(QSQLiteDriverPlugin)
Q_IMPORT_PLUGIN(QJpegPlugin)
Q_IMPORT_PLUGIN(QGifPlugin)
Q_IMPORT_PLUGIN(QSvgPlugin)
Q_IMPORT_PLUGIN(QICOPlugin)
#endif

#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(TenjinViewPlugin)

#include <TenjinConfig.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/CloudService.h>
#include <ViewModels/HapticsService.h>
#include <ViewModels/LogViewModel.h>
#include <ViewModels/NotificationService.h>

static LogViewModel*    g_logModel        = nullptr;
static QtMessageHandler g_previousHandler = nullptr;

static QString appDataDir()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

static void writeFatal(const QString& what)
{
    QDir().mkpath(appDataDir());
    QFile log(appDataDir() + QStringLiteral("/fatal.log"));
    if (log.open(QIODevice::Append | QIODevice::Text))
        QTextStream(&log) << QDateTime::currentDateTimeUtc().toString(Qt::ISODate) << ' ' << what
                          << '\n';
}

static void tenjinMessageHandler(QtMsgType type, const QMessageLogContext& ctx, const QString& msg)
{
    if (g_previousHandler)
        g_previousHandler(type, ctx, msg);

    if (!g_logModel)
        return;

    QLatin1StringView level;
    switch (type) {
    case QtDebugMsg:
        level = QLatin1StringView("debug");
        break;
    case QtInfoMsg:
        level = QLatin1StringView("info");
        break;
    case QtWarningMsg:
        level = QLatin1StringView("warning");
        break;
    case QtCriticalMsg:
        level = QLatin1StringView("critical");
        break;
    case QtFatalMsg:
        level = QLatin1StringView("fatal");
        break;
    }

    QMetaObject::invokeMethod(g_logModel,
                              "append",
                              Qt::QueuedConnection,
                              Q_ARG(QString, QString(level)),
                              Q_ARG(QString, msg));
}

static QIcon makeAppIcon()
{
    QIcon icon;
    for (int size : {16, 24, 32, 48, 64, 128, 256, 512}) {
        QPixmap pm(size, size);
        pm.fill(Qt::transparent);
        QPainter p(&pm);
        p.setRenderHint(QPainter::Antialiasing);
        p.setRenderHint(QPainter::TextAntialiasing);
        p.setBrush(QColor(0xd4, 0xa3, 0x73));
        p.setPen(Qt::NoPen);
        const qreal r = size * 0.20;
        p.drawRoundedRect(QRectF(0, 0, size, size), r, r);
        QFont f = p.font();
        f.setPixelSize(static_cast<int>(size * 0.66));
        f.setBold(true);
        p.setFont(f);
        p.setPen(QColor(0xfe, 0xfa, 0xe0));
        p.drawText(pm.rect(), Qt::AlignCenter, QStringLiteral("\u5929"));
        p.end();
        icon.addPixmap(pm);
    }
    return icon;
}

int main(int argc, char* argv[])
{
    QGuiApplication app(argc, argv);

#ifdef TENJIN_WEBVIEW
    QtWebView::initialize();
#endif

    app.setApplicationName(QString::fromUtf8(Tenjin::Config::kAppName));
    app.setApplicationDisplayName(QString::fromUtf8(Tenjin::Config::kAppDisplayName));
    app.setApplicationVersion(QString::fromUtf8(Tenjin::Config::kAppVersion));
    app.setOrganizationName(QString::fromUtf8(Tenjin::Config::kOrgName));
    app.setOrganizationDomain(QString::fromUtf8(Tenjin::Config::kOrgDomain));
    app.setWindowIcon(makeAppIcon());

    // Bundled monospace family (timestamps, code, formula source). Registered
    // before any QML loads so font.family: Platform.fontMono resolves.
    {
        // addApplicationFont takes a filesystem path or a ':' resource path —
        // NOT a "qrc:" URL. The module embeds these under /qt/qml/TenjinView.
        const QStringList monoFiles = {
            QStringLiteral(":/qt/qml/TenjinView/fonts/JetBrainsMono-Regular.ttf"),
            QStringLiteral(":/qt/qml/TenjinView/fonts/JetBrainsMono-Bold.ttf"),
        };
        for (const QString& f : monoFiles) {
            const int id = QFontDatabase::addApplicationFont(f);
            if (id < 0)
                qWarning("Tenjin: failed to load bundled mono font %s", qUtf8Printable(f));
        }
    }

    // Explicit default UI font. Without this, unstyled text measurement on
    // Windows falls back to legacy raster aliases (8514oem / Fixedsys), which
    // the DirectWrite backend logs as CreateFontFaceFromHDC() failures.
    {
        QFont ui;
#if defined(Q_OS_WIN)
        ui.setFamily(QStringLiteral("Segoe UI"));
#elif defined(Q_OS_MACOS) || defined(Q_OS_IOS)
        ui.setFamily(QStringLiteral(".AppleSystemUIFont"));
#elif defined(Q_OS_ANDROID)
        ui.setFamily(QStringLiteral("Roboto"));
#else
        ui.setFamily(QStringLiteral("Noto Sans"));
#endif
        ui.setPixelSize(13);
        app.setFont(ui);
    }

    // "Basic" is the correct style for pure QtQuick apps on all platforms.
    // Fusion is a QtWidgets style and must not be set here.
    // QQuickStyle::setStyle(QStringLiteral("Basic"));

    QDir().mkpath(appDataDir());

    // ── AppViewModel (initialises database) ──────────────────────────────────
    std::unique_ptr<AppViewModel> appVMPtr;
    try {
        appVMPtr = std::make_unique<AppViewModel>();
    } catch (const std::exception& e) {
        const QString msg =
            QStringLiteral("FATAL: AppViewModel init: ") + QString::fromUtf8(e.what());
        qCritical().noquote() << msg;
        qCritical() << "Available SQL drivers:" << QSqlDatabase::drivers();
        writeFatal(msg);
        if (!QSqlDatabase::drivers().contains(QStringLiteral("QSQLITE")))
            writeFatal(
                QStringLiteral("QSQLITE not registered — Q_IMPORT_PLUGIN(QSQLiteDriverPlugin) "
                               "required on static builds."));
        return -1;
    } catch (...) {
        writeFatal(QStringLiteral("FATAL: unknown exception during AppViewModel creation."));
        return -1;
    }
    AppViewModel& appVM = *appVMPtr;

    // ── Standalone services ───────────────────────────────────────────────────
    NotificationService notifService;
    CloudService        cloudService;
    HapticsService      haptics;

    // Children's-privacy gate: keep CloudService's data-collection flag in sync
    // with the app's age/consent state. Fail-closed by default (CloudService
    // initialises to false), and updated whenever consent changes. This is the
    // single point that authorises any off-device data transmission.
    cloudService.setDataCollectionAllowed(appVM.dataCollectionAllowed());
    QObject::connect(
        &appVM, &AppViewModel::consentChanged, &cloudService, [&appVM, &cloudService]() {
            cloudService.setDataCollectionAllowed(appVM.dataCollectionAllowed());
        });

    // ── Log model + message handler ──────────────────────────────────────────
    LogViewModel logModel;
    g_logModel        = &logModel;
    g_previousHandler = qInstallMessageHandler(tenjinMessageHandler);

    // ── QML engine ───────────────────────────────────────────────────────────
    QQmlApplicationEngine engine;
    appVM.setQmlEngine(&engine);

    // Context properties — all services accessible from any QML file.
    engine.rootContext()->setContextProperty(QStringLiteral("appVM"), &appVM);
    engine.rootContext()->setContextProperty(QStringLiteral("logModel"), &logModel);
    engine.rootContext()->setContextProperty(QStringLiteral("notifService"), &notifService);
    engine.rootContext()->setContextProperty(QStringLiteral("cloudService"), &cloudService);
    engine.rootContext()->setContextProperty(QStringLiteral("haptics"), &haptics);

    // Capture QML warnings/errors so a load failure writes the real cause to
    // fatal.log instead of crashing silently before the window appears.
    QObject::connect(
        &engine, &QQmlApplicationEngine::warnings, &app, [](const QList<QQmlError>& warnings) {
            for (const QQmlError& e : warnings) {
                const QString msg = QStringLiteral("QML: ") + e.toString();
                qWarning().noquote() << msg;
                writeFatal(msg);
            }
        });

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [](const QUrl& url) {
            const QString msg = QStringLiteral("QML creation FAILED: ") + url.toString();
            qCritical().noquote() << msg;
            writeFatal(msg);
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    const QUrl rootUrl(QStringLiteral("qrc:/qt/qml/TenjinView/Main.qml"));
    engine.load(rootUrl);

    if (engine.rootObjects().isEmpty()) {
        writeFatal(QStringLiteral("FATAL: no root QML objects — load failed: ") +
                   rootUrl.toString());
        return -1;
    }

    return app.exec();
}
