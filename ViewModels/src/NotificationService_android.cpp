// NotificationService_android.cpp — Android notification backend.
//
// Calls the Java NotificationClient.notify() helper via JNI. Compiled only on
// Android.

#include <ViewModels/NotificationService.h>

#include <QJniObject>

#include <QtCore/private/qandroidextras_p.h>
#include <QtCore/qnativeinterface.h>

namespace {

class NotificationServiceAndroid final : public NotificationService
{
public:
    using NotificationService::NotificationService;

protected:
    bool deliverNative(const QString& title, const QString& body,
                       const QVariantMap& /*payload*/) override
    {
        QJniObject jTitle = QJniObject::fromString(title);
        QJniObject jBody  = QJniObject::fromString(body);

        QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (!context.isValid())
            return false;

        QJniObject::callStaticMethod<void>(
            "app/tenjin/Tenjin/NotificationClient",
            "notify",
            "(Landroid/content/Context;Ljava/lang/String;Ljava/lang/String;)V",
            context.object(),
            jTitle.object<jstring>(),
            jBody.object<jstring>());

        return true;
    }

    bool requestPermissionNative() override
    {
        // POST_NOTIFICATIONS is a runtime permission only on API 33+. Below
        // that the manifest declaration suffices.
        if (QNativeInterface::QAndroidApplication::sdkVersion() < 33)
            return true;

        const QString perm = QStringLiteral("android.permission.POST_NOTIFICATIONS");
        if (QtAndroidPrivate::checkPermission(perm).result() == QtAndroidPrivate::Authorized)
            return true;

        // Async request; return optimistically (denial -> in-app toast fallback).
        QtAndroidPrivate::requestPermission(perm);
        return true;
    }
};

} // namespace

std::unique_ptr<NotificationService> NotificationService::create(QObject* parent)
{
    return std::make_unique<NotificationServiceAndroid>(parent);
}
