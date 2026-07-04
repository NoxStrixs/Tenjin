// DocumentPickerService_default.cpp — desktop / fallback backend.
// Compiled on every platform except iOS. Inherits the base's pickCancelled()
// default (the caller then shows the in-app Documents picker) and supplies
// this platform's create().

#include <ViewModels/DocumentPickerService.h>

namespace {

class DocumentPickerServiceDefault final : public DocumentPickerService
{
public:
    using DocumentPickerService::DocumentPickerService;
};

} // namespace

std::unique_ptr<DocumentPickerService> DocumentPickerService::create(QObject* parent)
{
    return std::make_unique<DocumentPickerServiceDefault>(parent);
}
