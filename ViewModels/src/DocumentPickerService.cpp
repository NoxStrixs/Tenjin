#include <ViewModels/DocumentPickerService.h>

DocumentPickerService::DocumentPickerService(QObject* parent) : QObject(parent) {}
DocumentPickerService::~DocumentPickerService() = default;

void DocumentPickerService::pickImportDocument()
{
    pickImportDocumentNative();
}

// Base default: no native picker on this platform. Emit cancellation so the
// caller falls back to the in-app Documents picker (ImportPickerDialog).
void DocumentPickerService::pickImportDocumentNative()
{
    emit pickCancelled();
}
