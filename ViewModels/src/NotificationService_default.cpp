// NotificationService_default.cpp — desktop / fallback backend.
// Compiled on every platform except iOS and Android. Inherits the base's
// desktop defaults (no OS delivery -> in-app toast fallback; permission
// auto-granted) and supplies this platform's create().

#include <ViewModels/NotificationService.h>

namespace {

class NotificationServiceDefault final : public NotificationService
{
public:
    using NotificationService::NotificationService;
    // Inherits base deliverNative()/requestPermissionNative() (desktop).
};

} // namespace

std::unique_ptr<NotificationService> NotificationService::create(QObject* parent)
{
    return std::make_unique<NotificationServiceDefault>(parent);
}
