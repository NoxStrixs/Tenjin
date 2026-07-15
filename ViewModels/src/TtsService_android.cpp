// TtsService_android.cpp — native pronunciation via the Android platform TTS
// engine (android.speech.tts.TextToSpeech), driven through the TtsClient Java
// helper. Replaces QtTextToSpeech on Android.

#include <ViewModels/TtsService.h>

#include <QCoreApplication>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>

struct TtsService::Impl {};

TtsService::TtsService(QObject* parent) : QObject(parent), d(std::make_unique<Impl>())
{
    // Kick off async engine init with the app context.
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (context.isValid()) {
        QJniObject::callStaticMethod<void>(
            "app/tenjin/Tenjin/TtsClient", "init",
            "(Landroid/content/Context;)V", context.object());
    }
}

TtsService::~TtsService() = default;

bool TtsService::hasTts() const
{
    return QJniObject::callStaticMethod<jboolean>(
        "app/tenjin/Tenjin/TtsClient", "isReady", "()Z");
}

void TtsService::speak(const QString& text, const QString& language)
{
    if (text.isEmpty())
        return;
    QJniObject::callStaticMethod<void>(
        "app/tenjin/Tenjin/TtsClient", "speak",
        "(Ljava/lang/String;Ljava/lang/String;)V",
        QJniObject::fromString(text).object<jstring>(),
        QJniObject::fromString(language).object<jstring>());
}

void TtsService::stop()
{
    QJniObject::callStaticMethod<void>("app/tenjin/Tenjin/TtsClient", "stop", "()V");
}

std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}
