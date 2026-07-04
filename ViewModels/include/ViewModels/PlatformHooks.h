#pragma once

#include <QString>

// Stateless platform hooks. Each is a single free function with exactly one
// implementation compiled per platform (selected in ViewModels/CMakeLists.txt):
// a *_default.cpp fallback, plus *_ios.mm / *_android.cpp where native fidelity
// exists. These carry no state and no async result, so they stay free functions
// rather than QObject services — the minimal correct shape.
//
// Services that own native state or emit async results (notifications, haptics,
// document picking) are QObject classes with a base + platform subclass +
// compile-time create() factory instead; see the *Service.h headers.

namespace tenjin {

// True if the OS "reduce motion" accessibility setting is on. Desktop returns
// false. iOS reads UIAccessibility; Android reads animator_duration_scale == 0.
bool platformPrefersReducedMotion();

// Present the OS share sheet for an exported file. Returns true if a native
// share UI was shown; false to fall back to the exported-to-Documents toast.
// Fire-and-forget: there is no completion result to marshal.
bool platformShareFile(const QString& absPath);

} // namespace tenjin
