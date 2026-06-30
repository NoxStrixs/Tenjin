// MotionService_ios.mm — reduced-motion probe on iOS.
//
// Reads the system "Reduce Motion" accessibility setting via UIAccessibility.
// Compiled only on iOS.

#import <UIKit/UIKit.h>

namespace tenjin {

bool platformPrefersReducedMotion()
{
    return UIAccessibilityIsReduceMotionEnabled() ? true : false;
}

} // namespace tenjin
