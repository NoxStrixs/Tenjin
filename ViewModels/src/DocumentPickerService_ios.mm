// DocumentPickerService_ios.mm — native Files/iCloud picker for importing a
// collection (UIDocumentPickerViewController). asCopy:YES makes iOS hand back
// a sandbox-local copy, so no security-scoped access dance is needed and the
// path is directly readable by the importer. Compiled only on iOS.

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <functional>

#include <QString>

@interface TenjinDocPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic) std::function<void(QString)> onPicked;
@end

@implementation TenjinDocPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController*)controller
    didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    Q_UNUSED(controller)
    if (urls.count == 0 || !self.onPicked)
        return;
    // asCopy:YES → this is already an app-local temporary copy.
    self.onPicked(QString::fromNSString(urls.firstObject.path));
}
@end

// The delegate must outlive the (async) presentation.
static TenjinDocPickerDelegate* g_docPickerDelegate = nil;

namespace tenjin {

bool platformPickImportDocument(const std::function<void(const QString&)>& onPicked)
{
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

    if (!g_docPickerDelegate)
        g_docPickerDelegate = [TenjinDocPickerDelegate new];
    g_docPickerDelegate.onPicked = [onPicked](const QString& p) { onPicked(p); };

    // JSON exports plus Anki packages; UTType for the .apkg extension falls
    // back to generic data if the system has no registration for it.
    UTType* apkg = [UTType typeWithFilenameExtension:@"apkg"];
    NSArray<UTType*>* types = @[ UTTypeJSON, apkg ? apkg : UTTypeData ];

    UIDocumentPickerViewController* picker =
        [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types
                                                                    asCopy:YES];
    picker.delegate = g_docPickerDelegate;
    [keyWindow.rootViewController presentViewController:picker
                                               animated:YES
                                             completion:nil];
    return true;
}

} // namespace tenjin
