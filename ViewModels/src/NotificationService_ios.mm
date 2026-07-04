// iOS notification backend (UserNotifications). Lazy auth on first delivery;
// daily scheduling driven by the base timer. Compiled only on iOS.

#include <ViewModels/NotificationService.h>

#import <UserNotifications/UserNotifications.h>

namespace {

class NotificationServiceIos final : public NotificationService
{
public:
    using NotificationService::NotificationService;

protected:
    bool deliverNative(const QString& title, const QString& body,
                       const QVariantMap& /*payload*/) override
    {
        UNUserNotificationCenter* center =
            [UNUserNotificationCenter currentNotificationCenter];

        UNAuthorizationOptions opts =
            UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;

        NSString* nsTitle = title.toNSString();
        NSString* nsBody  = body.toNSString();

        // Ensure authorization, then post. requestAuthorization is a no-op if
        // the user already decided; the completion still fires with the grant.
        [center requestAuthorizationWithOptions:opts
                              completionHandler:^(BOOL granted, NSError* _Nullable error) {
            if (!granted || error != nil)
                return;

            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.title = nsTitle;
            content.body  = nsBody;
            content.sound = [UNNotificationSound defaultSound];

            UNTimeIntervalNotificationTrigger* trigger =
                [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];

            NSString* identifier =
                [NSString stringWithFormat:@"tenjin.%@", [[NSUUID UUID] UUIDString]];
            UNNotificationRequest* request =
                [UNNotificationRequest requestWithIdentifier:identifier
                                                     content:content
                                                     trigger:trigger];

            [center addNotificationRequest:request withCompletionHandler:nil];
        }];

        return true;
    }

    bool requestPermissionNative() override
    {
        UNUserNotificationCenter* center =
            [UNUserNotificationCenter currentNotificationCenter];
        UNAuthorizationOptions opts =
            UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
        [center requestAuthorizationWithOptions:opts
                              completionHandler:^(BOOL /*granted*/, NSError* _Nullable /*error*/) {}];
        return true;
    }
};

} // namespace

std::unique_ptr<NotificationService> NotificationService::create(QObject* parent)
{
    return std::make_unique<NotificationServiceIos>(parent);
}
