// ShareService_default.cpp — native share is unavailable on this platform
// (desktop, and Android until a FileProvider is wired). Returning false makes
// the caller fall back to the exported-to-Documents toast.

#include <QString>

namespace tenjin {

bool platformShareFile(const QString& /*absPath*/)
{
    return false;
}

} // namespace tenjin
