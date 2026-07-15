// Android backend: shows the system TimePickerDialog via the TimePickerClient
// Java helper (dialogs must run on the UI thread). The result returns through
// two JNI native callbacks, registered here, which emit the service signals.
// Compiled only on Android.

#include <ViewModels/TimePickerService.h>

#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>

#include <jni.h>

namespace {

// The single live Android backend, so the static JNI callbacks can route the
// result to the right instance. Only one picker is ever presented at a time.
class TimePickerServiceAndroid;
TimePickerServiceAndroid* g_activeAndroid = nullptr;

class TimePickerServiceAndroid final : public TimePickerService
{
public:
    explicit TimePickerServiceAndroid(QObject* parent) : TimePickerService(parent)
    {
        g_activeAndroid = this;
    }
    ~TimePickerServiceAndroid() override
    {
        if (g_activeAndroid == this)
            g_activeAndroid = nullptr;
    }

    void emitPicked(int h, int m)
    {
        emit timePicked(h, m);
    }
    void emitCancelled()
    {
        emit pickCancelled();
    }

protected:
    void pickTimeNative(int hour, int minute) override
    {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            emit pickCancelled();
            return;
        }

        QJniObject::callStaticMethod<void>("app/tenjin/Tenjin/TimePickerClient",
                                           "show",
                                           "(Landroid/app/Activity;II)V",
                                           activity.object<jobject>(),
                                           static_cast<jint>(hour),
                                           static_cast<jint>(minute));
    }

    bool hasNativePickerImpl() const override
    {
        return true;
    }
};

// JNI callbacks invoked from TimePickerClient.java.
void JNICALL nativeOnTimePicked(JNIEnv*, jclass, jint hour, jint minute)
{
    if (g_activeAndroid)
        g_activeAndroid->emitPicked(static_cast<int>(hour), static_cast<int>(minute));
}

void JNICALL nativeOnTimeCancelled(JNIEnv*, jclass)
{
    if (g_activeAndroid)
        g_activeAndroid->emitCancelled();
}

// Register the natives once, matching the Java declarations.
bool registerTimePickerNatives()
{
    QJniEnvironment       env;
    const JNINativeMethod methods[] = {
        {"onTimePicked", "(II)V", reinterpret_cast<void*>(nativeOnTimePicked)},
        {"onTimeCancelled", "()V", reinterpret_cast<void*>(nativeOnTimeCancelled)},
    };
    return env.registerNativeMethods("app/tenjin/Tenjin/TimePickerClient", methods, 2);
}

const bool g_registered = registerTimePickerNatives();

} // namespace

std::unique_ptr<TimePickerService> TimePickerService::create(QObject* parent)
{
    return std::make_unique<TimePickerServiceAndroid>(parent);
}
