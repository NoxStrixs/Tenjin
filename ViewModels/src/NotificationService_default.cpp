// NotificationService_default.cpp — desktop / fallback notification backend.
//
// Compiled on every platform EXCEPT iOS and Android (see ViewModels/CMakeLists).
// Returns false so NotificationService falls back to an in-app toast. The
// platform TUs (_ios.mm, _android.cpp) provide real OS notifications instead.

#include <QString>
#include <QVariantMap>

namespace tenjin {

bool platformDeliverLocalPush(const QString& /*title*/,
                              const QString& /*body*/,
                              const QVariantMap& /*payload*/)
{
    return false;
}

bool platformRequestNotificationPermission()
{
    return true; // Desktop needs no notification permission.
}

} // namespace tenjin
