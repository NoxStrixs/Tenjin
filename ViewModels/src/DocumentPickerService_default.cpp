// DocumentPickerService_default.cpp — desktop / fallback backend.
// Both import and media picking inherit the base pickCancelled(): desktop has
// no OS photo/camera picker, and file selection is handled by the existing QML
// desktop dialogs (DesktopMediaDialog / ImportPickerDialog), keeping all UI in
// QML (no QtWidgets dependency in the ViewModels layer).

#include <ViewModels/DocumentPickerService.h>

namespace {

class DocumentPickerServiceDefault final : public DocumentPickerService
{
public:
    using DocumentPickerService::DocumentPickerService;
    // Inherits base pickImportDocumentNative()/pickMediaNative() (emit cancel).
};

} // namespace

std::unique_ptr<DocumentPickerService> DocumentPickerService::create(QObject* parent)
{
    return std::make_unique<DocumentPickerServiceDefault>(parent);
}
