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
#include <QQuickWindow>

#if defined(Q_OS_WIN)
#    include <dwmapi.h>
#    include <windows.h>
#endif
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

// On a static Qt (iOS) the QML module plugins must be force-linked or the engine
// reports "module ... is not installed" and shows a black screen. This is
// handled by qt_import_qml_plugins() in App/CMakeLists.txt, which runs
// qmlimportscanner and links the correct plugin targets automatically (their
// symbol names vary by Qt version, so we deliberately do NOT hand-name them
// here). The Controls style is pinned to Basic via the module IMPORTS list and
// QQuickStyle::setStyle("Basic") below, so the scanner bundles the Basic style
// rather than the unbuilt QtQuick.Controls.iOS platform style.

#include <TenjinConfig.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/CloudService.h>
#include <ViewModels/CloudSyncService.h>
#include <ViewModels/DocumentPickerService.h>
#include <ViewModels/HapticsService.h>
#include <ViewModels/LogViewModel.h>
#include <ViewModels/NotificationService.h>
#include <ViewModels/TimePickerService.h>

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
    // Suppress benign Windows DirectWrite noise: Qt's font database probes the
    // legacy raster aliases 8514oem / Fixedsys, which have no scalable face, so
    // DirectWrite logs CreateFontFaceFromHDC() failures. These are harmless and
    // cannot be prevented from the app side (they fire during font-db init), so
    // we drop them here rather than spam the log.
    if (msg.contains(QLatin1String("CreateFontFaceFromHDC")) &&
        (msg.contains(QLatin1String("8514oem")) || msg.contains(QLatin1String("Fixedsys")))) {
        return;
    }

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

#if defined(Q_OS_WIN)
    // Windows' DirectWrite backend logs CreateFontFaceFromHDC() failures when
    // Qt's QFontDatabase probes legacy raster aliases (8514oem, Fixedsys) that
    // have no scalable face. Redirect those aliases to a real UI family so the
    // probe resolves cleanly and the log spam stops. Harmless on any Windows
    // install that has Segoe UI (Vista+).
    QFont::insertSubstitution(QStringLiteral("8514oem"), QStringLiteral("Segoe UI"));
    QFont::insertSubstitution(QStringLiteral("Fixedsys"), QStringLiteral("Consolas"));
    QFont::insertSubstitution(QStringLiteral("System"), QStringLiteral("Segoe UI"));
    QFont::insertSubstitution(QStringLiteral("MS Sans Serif"), QStringLiteral("Segoe UI"));
#endif

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
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QDir().mkpath(appDataDir());

    // AppViewModel (initialises database)
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

    // Standalone services (compile-time platform factories)
    // create() returns the platform-appropriate subclass; only the target
    // platform's backend TU is compiled in (see ViewModels/CMakeLists.txt).
    auto                   notifServicePtr = NotificationService::create();
    auto                   cloudServicePtr = CloudService::create();
    auto                   cloudSyncPtr    = CloudSyncService::create();
    auto                   hapticsPtr      = HapticsService::create();
    auto                   pickerPtr       = DocumentPickerService::create();
    auto                   timePickerPtr   = TimePickerService::create();
    NotificationService&   notifService    = *notifServicePtr;
    CloudService&          cloudService    = *cloudServicePtr;
    CloudSyncService&      cloudSync       = *cloudSyncPtr;
    HapticsService&        haptics         = *hapticsPtr;
    DocumentPickerService& picker          = *pickerPtr;
    TimePickerService&     timePicker      = *timePickerPtr;

    // Inject the picker so AppViewModel can drive native import and receive the
    // async documentPicked() result.
    appVM.setDocumentPicker(&picker);

    // Children's-privacy gate: keep CloudService's data-collection flag in sync
    // with the app's age/consent state. Fail-closed by default (CloudService
    // initialises to false), and updated whenever consent changes. This is the
    // single point that authorises any off-device data transmission.
    cloudService.setDataCollectionAllowed(appVM.dataCollectionAllowed());
    QObject::connect(
        &appVM, &AppViewModel::consentChanged, &cloudService, [&appVM, &cloudService]() {
            cloudService.setDataCollectionAllowed(appVM.dataCollectionAllowed());
        });

    // Log model + message handler
    LogViewModel logModel;
    g_logModel        = &logModel;
    g_previousHandler = qInstallMessageHandler(tenjinMessageHandler);

    // QML engine
    QQmlApplicationEngine engine;
    appVM.setQmlEngine(&engine);

    // Context properties — all services accessible from any QML file.
    engine.rootContext()->setContextProperty(QStringLiteral("appVM"), &appVM);
    engine.rootContext()->setContextProperty(QStringLiteral("logModel"), &logModel);
    engine.rootContext()->setContextProperty(QStringLiteral("notifService"), &notifService);
    engine.rootContext()->setContextProperty(QStringLiteral("cloudService"), &cloudService);
    engine.rootContext()->setContextProperty(QStringLiteral("cloudSync"), &cloudSync);
    engine.rootContext()->setContextProperty(QStringLiteral("haptics"), &haptics);
    engine.rootContext()->setContextProperty(QStringLiteral("timePicker"), &timePicker);

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

#if defined(Q_OS_WIN)
    // Match the Windows title bar (the OS-drawn caption) to the app's light/dark
    // theme via the DWM immersive-dark-mode attribute. Qt does not do this
    // automatically. Re-applied whenever the theme changes. This is a Win32-only
    // path; the attribute value 20 (DWMWA_USE_IMMERSIVE_DARK_MODE) is stable on
    // Windows 10 2004+ and Windows 11.
    {
        auto applyDarkTitleBar = [&engine](bool dark) {
            const auto roots = engine.rootObjects();
            if (roots.isEmpty())
                return;
            auto* win = qobject_cast<QQuickWindow*>(roots.first());
            if (!win)
                return;
            const HWND hwnd = reinterpret_cast<HWND>(win->winId());
            if (!hwnd)
                return;
            const BOOL value = dark ? TRUE : FALSE;
            // DWMWA_USE_IMMERSIVE_DARK_MODE == 20.
            DwmSetWindowAttribute(hwnd, 20, &value, sizeof(value));
        };
        applyDarkTitleBar(appVM.theme() == 1 || (appVM.theme() == 2 && appVM.customIsDark()));
        QObject::connect(&appVM, &AppViewModel::themeChanged, &app, [&appVM, applyDarkTitleBar]() {
            applyDarkTitleBar(appVM.theme() == 1 || (appVM.theme() == 2 && appVM.customIsDark()));
        });
        QObject::connect(
            &appVM, &AppViewModel::customThemeChanged, &app, [&appVM, applyDarkTitleBar]() {
                applyDarkTitleBar(appVM.theme() == 1 ||
                                  (appVM.theme() == 2 && appVM.customIsDark()));
            });
    }
#endif

    return app.exec();
}
