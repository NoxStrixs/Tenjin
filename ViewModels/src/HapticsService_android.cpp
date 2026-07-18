// Android haptics via system Vibrator. One-shot VibrationEffects with graded
// durations (portable API 26+; avoids the API-31 VibratorManager split).

#include <ViewModels/HapticsService.h>

#include <QCoreApplication>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>

namespace {

// Duration (ms) per level: light..warning.
constexpr int kDurations[5] = {10, 20, 35, 30, 50};

void vibrateOneShot(int ms)
{
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return;

    QJniObject vibratorSvc =
        QJniObject::getStaticObjectField("android/content/Context", "VIBRATOR_SERVICE",
                                         "Ljava/lang/String;");
    QJniObject vibrator = context.callObjectMethod(
        "getSystemService", "(Ljava/lang/String;)Ljava/lang/Object;", vibratorSvc.object());
    if (!vibrator.isValid())
        return;

    // VibrationEffect.createOneShot(long ms, int amplitude=DEFAULT_AMPLITUDE=-1)
    QJniObject effect = QJniObject::callStaticObjectMethod(
        "android/os/VibrationEffect", "createOneShot",
        "(JI)Landroid/os/VibrationEffect;",
        static_cast<jlong>(ms), static_cast<jint>(-1));
    if (!effect.isValid())
        return;

    vibrator.callMethod<void>("vibrate", "(Landroid/os/VibrationEffect;)V", effect.object());
}

class HapticsServiceAndroid final : public HapticsService
{
public:
    using HapticsService::HapticsService;

protected:
    void playImpl(int level) override
    {
        if (level < 0 || level > 4)
            return;
        vibrateOneShot(kDurations[level]);
    }
};

} // namespace

std::unique_ptr<HapticsService> HapticsService::create(QObject* parent)
{
    return std::make_unique<HapticsServiceAndroid>(parent);
}
