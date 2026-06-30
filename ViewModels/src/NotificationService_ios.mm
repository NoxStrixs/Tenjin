// NotificationService_ios.mm — iOS notification backend.
//
// Posts an immediate local notification via UserNotifications. Permission is
// requested lazily on first delivery. Daily scheduling is driven by the Qt/C++
// timer in NotificationService; this only needs to display when called.
// Compiled only on iOS.

#include <QString>
#include <QVariantMap>

#import <UserNotifications/UserNotifications.h>

namespace tenjin {

bool platformDeliverLocalPush(const QString& title, const QString& body,
                              const QVariantMap& /*payload*/)
{
    UNUserNotificationCenter* center =
        [UNUserNotificationCenter currentNotificationCenter];

    UNAuthorizationOptions opts =
        UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;

    NSString* nsTitle = title.toNSString();
    NSString* nsBody  = body.toNSString();

    // Ensure authorization, then post. requestAuthorization is a no-op if the
    // user already decided; the completion still fires with the current grant.
    [center requestAuthorizationWithOptions:opts
                          completionHandler:^(BOOL granted, NSError* _Nullable error) {
        if (!granted || error != nil)
            return;

        UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
        content.title = nsTitle;
        content.body  = nsBody;
        content.sound = [UNNotificationSound defaultSound];

        // Fire almost immediately (1s); the C++ timer decides *when* to call us.
        UNTimeIntervalNotificationTrigger* trigger =
            [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1
                                                               repeats:NO];

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

bool platformRequestNotificationPermission()
{
    // iOS requests authorization lazily inside platformDeliverLocalPush, so the
    // explicit request is a no-op here. We still proactively ask so the prompt
    // can appear when the user enables reminders, not only at first fire.
    UNUserNotificationCenter* center =
        [UNUserNotificationCenter currentNotificationCenter];
    UNAuthorizationOptions opts =
        UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
    [center requestAuthorizationWithOptions:opts
                          completionHandler:^(BOOL /*granted*/, NSError* _Nullable /*error*/) {}];
    return true;
}

} // namespace tenjin
