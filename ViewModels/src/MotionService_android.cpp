// MotionService_android.cpp — reduced-motion probe on Android.
//
// Android has no direct "reduce motion" boolean. The accessibility toggle
// "Remove animations" sets the global ANIMATOR_DURATION_SCALE to 0, so we read
// that float from Settings.Global and treat 0 as reduced-motion-on. Compiled
// only on Android.

#include <QJniObject>
#include <QtCore/qnativeinterface.h>

namespace tenjin {

bool platformPrefersReducedMotion()
{
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid())
        return false;

    QJniObject resolver =
        context.callObjectMethod("getContentResolver", "()Landroid/content/ContentResolver;");
    if (!resolver.isValid())
        return false;

    QJniObject key = QJniObject::fromString(QStringLiteral("animator_duration_scale"));

    // Settings.Global.getFloat(resolver, key, defaultValue). Using the
    // default-value overload avoids the SettingNotFoundException path entirely;
    // we pass 1.0f (animations on) as the default so an unset value reads as
    // "not reduced".
    jfloat scale = QJniObject::callStaticMethod<jfloat>(
        "android/provider/Settings$Global",
        "getFloat",
        "(Landroid/content/ContentResolver;Ljava/lang/String;F)F",
        resolver.object(),
        key.object<jstring>(),
        static_cast<jfloat>(1.0f));

    return scale == 0.0f;
}

} // namespace tenjin
