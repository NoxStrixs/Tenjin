// Android backend for DocumentPickerService: media picking (Photo Picker,
// camera, SAF files) and collection import (SAF). Launches intents via the
// MediaPickerClient Java helper; the picked content:// URI is copied to the app
// cache in Java and the resulting path returns through two JNI natives
// (deliverResult/deliverCancelled). Activity results are forwarded to Java via
// a QtAndroidPrivate::ActivityResultListener. Compiled only on Android.

#include <ViewModels/DocumentPickerService.h>

#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/private/qandroidextras_p.h>
#include <QtCore/qnativeinterface.h>

#include <jni.h>

namespace {

class DocumentPickerServiceAndroid;
DocumentPickerServiceAndroid* g_activeAndroid = nullptr;

// Forwards Android activity results into MediaPickerClient.handleResult. One
// listener instance is registered for the process lifetime.
class TenjinActivityResultListener : public QtAndroidPrivate::ActivityResultListener
{
public:
    bool handleActivityResult(jint requestCode, jint resultCode, jobject data) override
    {
        // Only handle our own request codes (3001-3004).
        if (requestCode < 3001 || requestCode > 3004)
            return false;

        QJniObject context = QNativeInterface::QAndroidApplication::context();
        QJniObject::callStaticMethod<void>("app/tenjin/Tenjin/MediaPickerClient",
                                           "handleResult",
                                           "(Landroid/content/Context;IILandroid/content/Intent;)V",
                                           context.object(),
                                           requestCode,
                                           resultCode,
                                           data);
        return true;
    }
};

TenjinActivityResultListener* g_listener = nullptr;

class DocumentPickerServiceAndroid final : public DocumentPickerService
{
public:
    explicit DocumentPickerServiceAndroid(QObject* parent) : DocumentPickerService(parent)
    {
        g_activeAndroid = this;
        if (!g_listener) {
            g_listener = new TenjinActivityResultListener();
            QtAndroidPrivate::registerActivityResultListener(g_listener);
        }
    }
    ~DocumentPickerServiceAndroid() override
    {
        if (g_activeAndroid == this)
            g_activeAndroid = nullptr;
    }

    void emitMedia(const QString& p)
    {
        emit mediaPicked(p);
    }
    void emitDocument(const QString& p)
    {
        emit documentPicked(p);
    }
    void emitCancelled()
    {
        emit pickCancelled();
    }

protected:
    void pickImportDocumentNative() override
    {
        callPicker("pickImport");
    }

    void pickMediaNative(MediaSource source) override
    {
        switch (source) {
        case MediaSource::Photos:
            callPicker("pickPhotos");
            break;
        case MediaSource::Camera:
            callPicker("pickCamera");
            break;
        case MediaSource::Files:
            callPicker("pickFiles");
            break;
        }
    }

private:
    void callPicker(const char* method)
    {
        QJniObject activity = QNativeInterface::QAndroidApplication::context();
        if (!activity.isValid()) {
            emit pickCancelled();
            return;
        }
        QJniObject::callStaticMethod<void>("app/tenjin/Tenjin/MediaPickerClient",
                                           method,
                                           "(Landroid/app/Activity;)V",
                                           activity.object<jobject>());
    }
};

// JNI callbacks from MediaPickerClient. kind: 0 = media, 1 = import.
void JNICALL nativeDeliverResult(JNIEnv* env, jclass, jstring path, jint kind)
{
    if (!g_activeAndroid)
        return;
    const char*   utf = env->GetStringUTFChars(path, nullptr);
    const QString p   = QString::fromUtf8(utf);
    env->ReleaseStringUTFChars(path, utf);
    if (kind == 1)
        g_activeAndroid->emitDocument(p);
    else
        g_activeAndroid->emitMedia(p);
}

void JNICALL nativeDeliverCancelled(JNIEnv*, jclass)
{
    if (g_activeAndroid)
        g_activeAndroid->emitCancelled();
}

bool registerMediaPickerNatives()
{
    QJniEnvironment       env;
    const JNINativeMethod methods[] = {
        {"deliverResult", "(Ljava/lang/String;I)V", reinterpret_cast<void*>(nativeDeliverResult)},
        {"deliverCancelled", "()V", reinterpret_cast<void*>(nativeDeliverCancelled)},
    };
    return env.registerNativeMethods("app/tenjin/Tenjin/MediaPickerClient", methods, 2);
}

const bool g_registered = registerMediaPickerNatives();

} // namespace

std::unique_ptr<DocumentPickerService> DocumentPickerService::create(QObject* parent)
{
    return std::make_unique<DocumentPickerServiceAndroid>(parent);
}
