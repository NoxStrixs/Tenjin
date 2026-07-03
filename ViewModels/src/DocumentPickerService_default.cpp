// DocumentPickerService_default.cpp — no native document picker on this
// platform. Returning false makes the caller fall back to the in-app
// Documents-folder picker (ImportPickerDialog).

#include <functional>

#include <QString>

namespace tenjin {

bool platformPickImportDocument(const std::function<void(const QString&)>& /*onPicked*/)
{
    return false;
}

} // namespace tenjin
