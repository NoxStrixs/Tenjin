#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFont>
#include <QGuiApplication>
#include <QIcon>
#include <QPainter>
#include <QPixmap>
#ifdef TENJIN_WEBVIEW
#    include <QtWebView/QtWebView>
#endif
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSqlDatabase>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>

#include <exception>

#include <TenjinConfig.h>

#include <ViewModels/AppViewModel.h>
#include <ViewModels/LogViewModel.h>
#include <ViewModels/ReviewViewModel.h>

#include <QtQml/qqmlextensionplugin.h>
Q_IMPORT_QML_PLUGIN(TenjinViewPlugin)

static LogViewModel*    g_logModel        = nullptr;
static QtMessageHandler g_previousHandler = nullptr;

static void tenjinMessageHandler(QtMsgType type, const QMessageLogContext& ctx, const QString& msg)
{
    if (g_previousHandler)
        g_previousHandler(type, ctx, msg);

    if (!g_logModel)
        return;

    QString level;
    switch (type) {
    case QtDebugMsg:
        level = QStringLiteral("debug");
        break;
    case QtInfoMsg:
        level = QStringLiteral("info");
        break;
    case QtWarningMsg:
        level = QStringLiteral("warning");
        break;
    case QtCriticalMsg:
        level = QStringLiteral("critical");
        break;
    case QtFatalMsg:
        level = QStringLiteral("critical");
        break;
    }
    QMetaObject::invokeMethod(
        g_logModel, "append", Qt::QueuedConnection, Q_ARG(QString, level), Q_ARG(QString, msg));
}

namespace {
// Programmatic placeholder app icon: rounded square in the app's accent color
// (Platform.accent #d4a373) with the 天 ideograph centered. Lives in code so
// the binary doesn't need a packaged icon asset until a designed one lands.
QIcon makeAppIcon()
{
    QIcon icon;
    for (int size : {16, 24, 32, 48, 64, 128, 256, 512}) {
        QPixmap pm(size, size);
        pm.fill(Qt::transparent);
        QPainter p(&pm);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::TextAntialiasing, true);
        p.setBrush(QColor(0xd4, 0xa3, 0x73));
        p.setPen(Qt::NoPen);
        const qreal r = size * 0.20;
        p.drawRoundedRect(QRectF(0, 0, size, size), r, r);
        QFont f = p.font();
        f.setPixelSize(static_cast<int>(size * 0.66));
        f.setBold(true);
        p.setFont(f);
        p.setPen(QColor(0xfe, 0xfa, 0xe0));
        p.drawText(pm.rect(), Qt::AlignCenter, QStringLiteral("\u5929")); // 天
        p.end();
        icon.addPixmap(pm);
    }
    return icon;
}
} // namespace

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

#if defined(Q_OS_IOS)
    QQuickStyle::setStyle(QStringLiteral("Basic"));
#else
    QQuickStyle::setStyle(QStringLiteral("Fusion"));
#endif

    auto writeFatal = [](const QString& what) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        QFile log(dir + "/fatal.txt");
        if (log.open(QIODevice::Append | QIODevice::Text)) {
            QTextStream(&log) << QDateTime::currentDateTime().toString(Qt::ISODate) << " " << what
                              << "\n";
        }
    };

    QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));

    std::unique_ptr<AppViewModel> appVMPtr;
    try {
        appVMPtr = std::make_unique<AppViewModel>();
    } catch (const std::exception& e) {
        const QString msg = QStringLiteral("FATAL: app/database init failed: ") + e.what();
        qCritical().noquote() << msg;
        qCritical() << "Available SQL drivers:" << QSqlDatabase::drivers();
        writeFatal(msg);
        writeFatal(QStringLiteral("  drivers=") + QSqlDatabase::drivers().join(','));
        if (!QSqlDatabase::drivers().contains(QStringLiteral("QSQLITE"))) {
            const QString hint =
                QStringLiteral("QSQLITE driver NOT registered. On a static build the driver plugin "
                               "must be linked into the app (Qt6::QSQLiteDriverPlugin).");
            qCritical().noquote() << hint;
            writeFatal(hint);
        }
        return -1;
    } catch (...) {
        const QString msg =
            QStringLiteral("FATAL: unknown exception during AppViewModel creation.");
        qCritical().noquote() << msg;
        writeFatal(msg);
        return -1;
    }
    AppViewModel& appVM = *appVMPtr;

    LogViewModel logModel;
    g_logModel        = &logModel;
    g_previousHandler = qInstallMessageHandler(tenjinMessageHandler);

    QQmlApplicationEngine engine;
    appVM.setQmlEngine(&engine);
    engine.rootContext()->setContextProperty("appVM", &appVM);
    engine.rootContext()->setContextProperty("reviewVm", appVM.reviewVM());
    engine.rootContext()->setContextProperty("logModel", &logModel);

    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        [&writeFatal](const QUrl& url) {
            const QString msg = QStringLiteral("QML creation FAILED: ") + url.toString();
            qCritical().noquote() << msg;
            writeFatal(msg);
            QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);

    const QUrl url(QStringLiteral("qrc:/qt/qml/TenjinView/Main.qml"));
    qDebug() << "Loading:" << url;
    engine.load(url);
    qDebug() << "Root objects after load:" << engine.rootObjects().size();

    if (engine.rootObjects().isEmpty()) {
        const QString msg = QStringLiteral("FAILED: no root objects for ") + url.toString();
        qCritical().noquote() << msg;
        writeFatal(msg);
        return -1;
    }
    return app.exec();
}
