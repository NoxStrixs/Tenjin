// ShareService_ios.mm — presents the system share sheet
// (UIActivityViewController) for an exported file. Compiled only on iOS.

#import <UIKit/UIKit.h>

#include <QString>

#include <ViewModels/PlatformHooks.h>

namespace tenjin {

bool platformShareFile(const QString& absPath)
{
    NSURL* fileUrl = [NSURL fileURLWithPath:absPath.toNSString()];
    if (!fileUrl)
        return false;

    // Find the key window's root view controller (scene-based lookup; the
    // pre-13 keyWindow property is deprecated).
    UIWindow* keyWindow = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;
        for (UIWindow* w in static_cast<UIWindowScene*>(scene).windows) {
            if (w.isKeyWindow) {
                keyWindow = w;
                break;
            }
        }
        if (keyWindow)
            break;
    }
    if (!keyWindow || !keyWindow.rootViewController)
        return false;

    UIViewController* rootVc = keyWindow.rootViewController;
    UIActivityViewController* avc =
        [[UIActivityViewController alloc] initWithActivityItems:@[ fileUrl ]
                                          applicationActivities:nil];

    // iPad requires a popover anchor or UIKit raises at presentation time.
    if (avc.popoverPresentationController) {
        avc.popoverPresentationController.sourceView = rootVc.view;
        avc.popoverPresentationController.sourceRect =
            CGRectMake(CGRectGetMidX(rootVc.view.bounds),
                       CGRectGetMidY(rootVc.view.bounds), 1, 1);
        avc.popoverPresentationController.permittedArrowDirections = 0;
    }

    [rootVc presentViewController:avc animated:YES completion:nil];
    return true;
}

} // namespace tenjin
