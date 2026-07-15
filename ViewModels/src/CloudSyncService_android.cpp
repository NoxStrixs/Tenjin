// CloudSyncService_android.cpp — Android backend over the Storage Access
// Framework. The user picks a folder once (typically in Google Drive); we hold a
// persistable read/write grant on that tree.
//
// SAF has no filesystem path, so we keep a local staging directory:
//   syncFolder()  -> the staging dir (callers export/import through it)
//   publish(path) -> copies the staged file into the SAF tree
//   listSnapshots -> queries the tree; "pulling" copies back into staging
// This keeps the AppViewModel export/import calls (which take file paths)
// working unchanged.

#include <ViewModels/CloudSyncService.h>

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QJniEnvironment>
#include <QJniObject>
#include <QStandardPaths>
#include <QtCore/private/qandroidextras_p.h>
#include <QtCore/qnativeinterface.h>

namespace {

constexpr const char* kClient      = "app/tenjin/Tenjin/CloudSyncClient";
constexpr int         kReqPickTree = 4001;

QJniObject appContext()
{
    return QNativeInterface::QAndroidApplication::context();
}

// Local staging directory that mirrors the SAF tree.
QString stagingDir()
{
    const QString d = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
                      QStringLiteral("/cloudsync");
    QDir().mkpath(d);
    return d;
}

class CloudSyncServiceAndroid;
CloudSyncServiceAndroid* g_instance = nullptr;

// Receives the SAF folder-picker result.
class TreePickListener : public QtAndroidPrivate::ActivityResultListener
{
public:
    bool handleActivityResult(jint requestCode, jint resultCode, jobject data) override;
};

} // namespace

class CloudSyncServiceAndroid final : public CloudSyncService
{
public:
    explicit CloudSyncServiceAndroid(QObject* parent = nullptr) : CloudSyncService(parent)
    {
        g_instance     = this;
        QJniObject ctx = appContext();
        if (ctx.isValid()) {
            QJniObject::callStaticMethod<void>(
                kClient, "init", "(Landroid/content/Context;)V", ctx.object());
        }
        QtAndroidPrivate::registerActivityResultListener(&m_listener);
    }

    ~CloudSyncServiceAndroid() override
    {
        QtAndroidPrivate::unregisterActivityResultListener(&m_listener);
        g_instance = nullptr;
    }

    bool available() const override
    {
        QJniObject ctx = appContext();
        if (!ctx.isValid())
            return false;
        return QJniObject::callStaticMethod<jboolean>(
            kClient, "hasTree", "(Landroid/content/Context;)Z", ctx.object());
    }

    QString locationLabel() const override
    {
        if (!available())
            return tr("No folder selected");
        QJniObject ctx  = appContext();
        QJniObject name = QJniObject::callStaticObjectMethod(
            kClient, "treeLabel", "(Landroid/content/Context;)Ljava/lang/String;", ctx.object());
        const QString n = name.isValid() ? name.toString() : QString();
        return n.isEmpty() ? tr("Selected folder") : n;
    }

    QString syncFolder() const override
    {
        return stagingDir();
    }

    void chooseLocation() override
    {
        // context() is the QtActivity on Android, which is what
        // startActivityForResult needs. The result comes back through
        // TreePickListener under kReqPickTree.
        QJniObject activity = appContext();
        if (!activity.isValid()) {
            emit locationChosen(false);
            return;
        }
        QJniObject::callStaticMethod<void>(
            kClient, "pickTree", "(Landroid/app/Activity;)V", activity.object());
    }

    QVariantList listSnapshots() const override
    {
        QVariantList out;
        QJniObject   ctx = appContext();
        if (!ctx.isValid() || !available())
            return out;

        QJniObject arr =
            QJniObject::callStaticObjectMethod(kClient,
                                               "listSnapshots",
                                               "(Landroid/content/Context;)[Ljava/lang/String;",
                                               ctx.object());
        if (!arr.isValid())
            return out;

        QJniEnvironment env;
        auto            jarr = arr.object<jobjectArray>();
        const jsize     n    = env->GetArrayLength(jarr);
        for (jsize i = 0; i < n; ++i) {
            QJniObject        item(env->GetObjectArrayElement(jarr, i));
            const QString     s = item.toString(); // name|size|millis
            const QStringList p = s.split(QLatin1Char('|'));
            if (p.size() != 3)
                continue;
            out.append(QVariantMap{
                {QStringLiteral("name"), p[0]},
                // Path is resolved on demand by pulling into staging.
                {QStringLiteral("path"), stagingDir() + QLatin1Char('/') + p[0]},
                {QStringLiteral("sizeBytes"), p[1].toLongLong()},
                {QStringLiteral("modified"),
                 QDateTime::fromMSecsSinceEpoch(p[2].toLongLong()).toString(Qt::ISODate)}});
        }
        return out;
    }

    // Copy a freshly-exported staged file into the SAF tree.
    void publish(const QString& localPath) override
    {
        QJniObject ctx = appContext();
        if (!ctx.isValid() || localPath.isEmpty())
            return;
        const QString name = QFileInfo(localPath).fileName();
        const bool    ok   = QJniObject::callStaticMethod<jboolean>(
            kClient,
            "pushFile",
            "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
            ctx.object(),
            QJniObject::fromString(localPath).object<jstring>(),
            QJniObject::fromString(name).object<jstring>());
        if (!ok)
            emit error(tr("Couldn't write to the selected cloud folder."));
    }

    // Copy a snapshot out of the SAF tree into staging so importData() (which
    // takes a real path) can read it.
    QString materialize(const QString& name) override
    {
        QJniObject ctx = appContext();
        if (!ctx.isValid())
            return {};
        const QString local = stagingDir() + QLatin1Char('/') + name;
        const bool    ok    = QJniObject::callStaticMethod<jboolean>(
            kClient,
            "pullFile",
            "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)Z",
            ctx.object(),
            QJniObject::fromString(name).object<jstring>(),
            QJniObject::fromString(local).object<jstring>());
        return ok ? local : QString();
    }

    void onTreeChosen(bool ok)
    {
        emit availableChanged();
        emit locationChosen(ok);
    }

private:
    TreePickListener m_listener;
};

namespace {
bool TreePickListener::handleActivityResult(jint requestCode, jint resultCode, jobject data)
{
    if (requestCode != kReqPickTree)
        return false;
    constexpr jint RESULT_OK = -1;
    if (resultCode != RESULT_OK || data == nullptr) {
        if (g_instance)
            g_instance->onTreeChosen(false);
        return true;
    }
    QJniObject intent(data);
    QJniObject uri = intent.callObjectMethod("getData", "()Landroid/net/Uri;");
    QJniObject ctx = appContext();
    if (uri.isValid() && ctx.isValid()) {
        QJniObject::callStaticMethod<void>(kClient,
                                           "saveTree",
                                           "(Landroid/content/Context;Landroid/net/Uri;)V",
                                           ctx.object(),
                                           uri.object());
    }
    if (g_instance)
        g_instance->onTreeChosen(uri.isValid());
    return true;
}
} // namespace

std::unique_ptr<CloudSyncService> CloudSyncService::create(QObject* parent)
{
    return std::make_unique<CloudSyncServiceAndroid>(parent);
}
