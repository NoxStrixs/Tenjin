#include <ViewModels/PlatformHooks.h>
// MotionService_default.cpp — reduced-motion probe for platforms without an OS
// "reduce motion" accessibility setting (desktop). Always returns false; the
// in-app toggle still works. Compiled on every platform except iOS and Android.

namespace tenjin {

bool platformPrefersReducedMotion()
{
    return false;
}

} // namespace tenjin
