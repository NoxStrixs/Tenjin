// DocumentPickerService_ios.mm — native Files/iCloud picker (iOS).
//
// Presents UIDocumentPickerViewController for opening a collection (JSON /
// .apkg). asCopy:YES hands back a sandbox-local copy, so the path is directly
// readable with no security-scoped access dance. The delegate marshals the
// async result back via std::function callbacks that emit the service's Qt
// signals. Compiled only on iOS. Verified against iOS 16+
// UIDocumentPickerViewController / UniformTypeIdentifiers.
//
// Threading: UIDocumentPickerDelegate callbacks arrive on the main thread,
// which is the Qt GUI thread, so emitting the signal from them is safe.
//
// The delegate holds std::function callbacks rather than a pointer to the C++
// subclass: an ObjC @property referencing a namespace-scoped C++ type is
// fragile across Clang/Xcode versions, whereas std::function is a plain value
// type ObjC++ handles cleanly.

#include <ViewModels/DocumentPickerService.h>

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <functional>

@interface TenjinDocPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic) std::function<void(QString)> onPicked;
@property(nonatomic) std::function<void()>        onCancelled;
@end

@implementation TenjinDocPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController*)controller
    didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    Q_UNUSED(controller)
    if (urls.count == 0) {
        if (self.onCancelled) self.onCancelled();
        return;
    }
    if (self.onPicked)
        self.onPicked(QString::fromNSString(urls.firstObject.path));
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    Q_UNUSED(controller)
    if (self.onCancelled) self.onCancelled();
}
@end

namespace {

UIViewController* keyRootViewController()
{
    UIWindow* keyWindow = nil;
    for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class])
            continue;
        for (UIWindow* w in static_cast<UIWindowScene*>(scene).windows) {
            if (w.isKeyWindow) { keyWindow = w; break; }
        }
        if (keyWindow) break;
    }
    return keyWindow ? keyWindow.rootViewController : nil;
}

class DocumentPickerServiceIos final : public DocumentPickerService
{
public:
    explicit DocumentPickerServiceIos(QObject* parent = nullptr)
        : DocumentPickerService(parent)
    {
        m_delegate = [TenjinDocPickerDelegate new];
        // Callbacks capture `this`; the service owns the delegate, so the
        // delegate never outlives the service.
        m_delegate.onPicked    = [this](QString p) { emit documentPicked(p); };
        m_delegate.onCancelled = [this]() { emit pickCancelled(); };
    }

    ~DocumentPickerServiceIos() override
    {
        m_delegate.onPicked    = nullptr;
        m_delegate.onCancelled = nullptr;
        m_delegate = nil;
    }

protected:
    void pickImportDocumentNative() override
    {
        UIViewController* rootVc = keyRootViewController();
        if (!rootVc) {
            emit pickCancelled();
            return;
        }

        UTType* apkg = [UTType typeWithFilenameExtension:@"apkg"];
        NSArray<UTType*>* types = @[ UTTypeJSON, apkg ? apkg : UTTypeData ];

        UIDocumentPickerViewController* picker =
            [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
        picker.delegate = m_delegate;
        [rootVc presentViewController:picker animated:YES completion:nil];
    }

private:
    TenjinDocPickerDelegate* m_delegate = nil;
};

} // namespace

std::unique_ptr<DocumentPickerService> DocumentPickerService::create(QObject* parent)
{
    return std::make_unique<DocumentPickerServiceIos>(parent);
}
