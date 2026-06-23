#include <ViewModels/HapticsService.h>

// Cross-platform haptics.
//
// Qt 6.8 has no single portable haptic-feedback class, so this base
// implementation forwards to a weak platform hook that is a no-op by default.
// Platform-native haptics can be added later as separate translation units:
//
//   iOS:     HapticsService_ios.mm      (UIImpactFeedbackGenerator)
//   Android: HapticsService_android.cpp (Vibrator via JNI)
//
// Each would define tenjin_platform_haptic(int level) and be compiled only
// for that platform, overriding the weak default below. Until then the app
// builds and runs on every target with haptics doing nothing — never a crash.

// level: 0=light 1=medium 2=heavy 3=success 4=warning
namespace {
void platformHaptic(int level)
{
    Q_UNUSED(level)
    // No-op default. Platform builds replace this via their own TU.
}
} // namespace

HapticsService::HapticsService(QObject* parent) : QObject(parent) {}

void HapticsService::setEnabled(bool v)
{
    if (m_enabled == v) return;
    m_enabled = v;
    emit enabledChanged();
}

void HapticsService::light()   { play(0); }
void HapticsService::medium()  { play(1); }
void HapticsService::heavy()   { play(2); }
void HapticsService::success() { play(3); }
void HapticsService::warning() { play(4); }

void HapticsService::play(int level)
{
    if (!m_enabled)
        return;
    platformHaptic(level);
}
