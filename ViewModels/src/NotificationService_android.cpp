// NotificationService_android.cpp — Android notification backend.
//
// Calls the Java NotificationClient.notify() helper (App/android/src/...) via
// JNI, passing the app context. Compiled only on Android.

#include <QJniObject>
#include <QString>
#include <QVariantMap>

#include <QCoreApplication>
#include <QtCore/qnativeinterface.h>
#include <QtCore/private/qandroidextras_p.h>

namespace tenjin {

bool platformDeliverLocalPush(const QString& title, const QString& body,
                              const QVariantMap& /*payload*/)
{
    QJniObject jTitle = QJniObject::fromString(title);
    QJniObject jBody  = QJniObject::fromString(body);

    // Qt 6.8: QAndroidApplication::context() returns a QJniObject.
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

bool platformRequestNotificationPermission()
{
    // POST_NOTIFICATIONS is a runtime ("dangerous") permission only on Android
    // 13 (API 33) and newer. Below that, the manifest declaration suffices.
    if (QNativeInterface::QAndroidApplication::sdkVersion() < 33)
        return true;

    const QString perm = QStringLiteral("android.permission.POST_NOTIFICATIONS");

    // Already granted?
    if (QtAndroidPrivate::checkPermission(perm).result()
        == QtAndroidPrivate::Authorized)
        return true;

    // Request asynchronously (the sync variant can hang the UI thread). We
    // return optimistically; if the user denies, notifications simply won't
    // show and the app falls back to in-app toasts while focused.
    QtAndroidPrivate::requestPermission(perm);
    return true;
}

} // namespace tenjin
