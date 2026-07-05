// Native Files/iCloud picker (iOS). UIDocumentPickerViewController asCopy:YES
// -> sandbox-local path. Delegate uses std::function callbacks (ObjC @property
// can't hold a namespace-scoped C++ type) and emits on the main/GUI thread.

#include <ViewModels/DocumentPickerService.h>

#include <QString>

#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <PhotosUI/PhotosUI.h>

#include <functional>

@interface TenjinDocPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic) std::function<void(QString)> onPicked;
@property(nonatomic) std::function<void()>        onCancelled;
@end

// Media delegate: handles both the Photos picker (PHPickerViewControllerDelegate)
// and the camera (UIImagePickerControllerDelegate). std::function callbacks
// avoid holding a namespace-scoped C++ pointer in an ObjC property.
@interface TenjinMediaPickerDelegate : NSObject
    <PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property(nonatomic) std::function<void(QString)> onPicked;
@property(nonatomic) std::function<void()>        onCancelled;
@end

@implementation TenjinMediaPickerDelegate

// PHPicker: load the picked item's file representation and copy it into the
// app's temporary dir (sandbox-local, directly readable).
- (void)picker:(PHPickerViewController*)picker didFinishPicking:(NSArray<PHPickerResult*>*)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) {
        if (self.onCancelled) self.onCancelled();
        return;
    }

    NSItemProvider* provider = results.firstObject.itemProvider;
    NSArray<NSString*>* types = provider.registeredTypeIdentifiers;
    NSString* typeId = types.firstObject ?: (NSString*)UTTypeImage.identifier;

    __weak TenjinMediaPickerDelegate* weakSelf = self;
    [provider loadFileRepresentationForTypeIdentifier:typeId
                                    completionHandler:^(NSURL* _Nullable url, NSError* _Nullable error) {
        // This completion runs off the main thread; marshal back for the emit.
        dispatch_async(dispatch_get_main_queue(), ^{
            TenjinMediaPickerDelegate* s = weakSelf;
            if (!s) return;
            if (!url || error) { if (s.onCancelled) s.onCancelled(); return; }

            NSString* fileName = url.lastPathComponent ?: @"media";
            NSURL* tmp = [[NSFileManager.defaultManager temporaryDirectory]
                URLByAppendingPathComponent:
                    [NSString stringWithFormat:@"tenjin-%@-%@",
                        [[NSUUID UUID] UUIDString], fileName]];
            [NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
            NSError* copyErr = nil;
            [NSFileManager.defaultManager copyItemAtURL:url toURL:tmp error:&copyErr];
            if (copyErr) { if (s.onCancelled) s.onCancelled(); return; }
            if (s.onPicked) s.onPicked(QString::fromNSString(tmp.path));
        });
    }];
}

// Camera: save the captured image as JPEG into the temp dir.
- (void)imagePickerController:(UIImagePickerController*)picker
    didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id>*)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage* image = info[UIImagePickerControllerOriginalImage];
    if (!image) { if (self.onCancelled) self.onCancelled(); return; }

    NSData* jpeg = UIImageJPEGRepresentation(image, 0.9);
    NSURL* tmp = [[NSFileManager.defaultManager temporaryDirectory]
        URLByAppendingPathComponent:
            [NSString stringWithFormat:@"tenjin-camera-%@.jpg", [[NSUUID UUID] UUIDString]]];
    if ([jpeg writeToURL:tmp atomically:YES]) {
        if (self.onPicked) self.onPicked(QString::fromNSString(tmp.path));
    } else {
        if (self.onCancelled) self.onCancelled();
    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (self.onCancelled) self.onCancelled();
}

@end
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

        m_mediaDelegate = [TenjinMediaPickerDelegate new];
        m_mediaDelegate.onPicked    = [this](QString p) { emit mediaPicked(p); };
        m_mediaDelegate.onCancelled = [this]() { emit pickCancelled(); };
    }

    ~DocumentPickerServiceIos() override
    {
        m_delegate.onPicked    = nullptr;
        m_delegate.onCancelled = nullptr;
        m_delegate = nil;
        m_mediaDelegate.onPicked    = nullptr;
        m_mediaDelegate.onCancelled = nullptr;
        m_mediaDelegate = nil;
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

    void pickMediaNative(MediaSource source) override
    {
        UIViewController* rootVc = keyRootViewController();
        if (!rootVc) {
            emit pickCancelled();
            return;
        }

        switch (source) {
        case MediaSource::Photos: {
            // PHPickerViewController: out-of-process, no photo-library
            // permission prompt required. Images and videos.
            PHPickerConfiguration* config = [[PHPickerConfiguration alloc] init];
            config.selectionLimit = 1;
            config.filter = [PHPickerFilter anyFilterMatchingSubfilters:@[
                PHPickerFilter.imagesFilter, PHPickerFilter.videosFilter ]];
            PHPickerViewController* picker =
                [[PHPickerViewController alloc] initWithConfiguration:config];
            picker.delegate = m_mediaDelegate;
            [rootVc presentViewController:picker animated:YES completion:nil];
            break;
        }
        case MediaSource::Camera: {
            if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
                emit pickCancelled();
                return;
            }
            UIImagePickerController* cam = [[UIImagePickerController alloc] init];
            cam.sourceType = UIImagePickerControllerSourceTypeCamera;
            cam.delegate = m_mediaDelegate;
            [rootVc presentViewController:cam animated:YES completion:nil];
            break;
        }
        case MediaSource::Files:
        default: {
            NSArray<UTType*>* types = @[ UTTypeImage, UTTypeMovie, UTTypeAudio ];
            UIDocumentPickerViewController* picker =
                [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
            // A dedicated document-picker delegate routes file picks to
            // mediaPicked (distinct from the import delegate's documentPicked).
            picker.delegate = mediaFileDelegate();
            [rootVc presentViewController:picker animated:YES completion:nil];
            break;
        }
        }
    }

private:
    // A doc-picker delegate that routes to mediaPicked (distinct from the import
    // delegate which routes to documentPicked).
    TenjinDocPickerDelegate* mediaFileDelegate()
    {
        if (!m_mediaFileDel) {
            m_mediaFileDel = [TenjinDocPickerDelegate new];
            m_mediaFileDel.onPicked    = [this](QString p) { emit mediaPicked(p); };
            m_mediaFileDel.onCancelled = [this]() { emit pickCancelled(); };
        }
        return m_mediaFileDel;
    }

    TenjinDocPickerDelegate*   m_delegate = nil;
    TenjinMediaPickerDelegate* m_mediaDelegate = nil;
    TenjinDocPickerDelegate*   m_mediaFileDel = nil;
};

} // namespace

std::unique_ptr<DocumentPickerService> DocumentPickerService::create(QObject* parent)
{
    return std::make_unique<DocumentPickerServiceIos>(parent);
}
