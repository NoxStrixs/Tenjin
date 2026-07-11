#pragma once

#include <QObject>
#include <QString>

#include <memory>

// Text-to-speech service. Wraps QtTextToSpeech, which uses each platform's
// native engine (AVSpeechSynthesizer on Apple, SAPI on Windows, the Android TTS
// engine, speech-dispatcher on Linux). Exposed to QML as a context property.
//
// Compiled only when TTS_SUPPORT is on (TENJIN_TTS defined). When absent, a
// stub with hasTts()==false is used so QML can hide the speak affordance.
// speak() auto-selects a voice whose locale matches the requested BCP-47-ish
// language code (e.g. "ja", "fr", "en"), falling back to the engine default.
class TtsService : public QObject
{
    Q_OBJECT

public:
    explicit TtsService(QObject* parent = nullptr);
    ~TtsService() override;

    static std::unique_ptr<TtsService> create(QObject* parent = nullptr);

    // True when a speech engine is available (TTS compiled in and an engine
    // initialized). QML binds the speaker button's visibility to this.
    Q_INVOKABLE bool hasTts() const;

    // Speak `text`. If `language` is non-empty, select a matching voice/locale;
    // otherwise use the engine default. Interrupts any current utterance.
    Q_INVOKABLE void speak(const QString& text, const QString& language = QString());

    // Stop any current utterance.
    Q_INVOKABLE void stop();

private:
    struct Impl;
    std::unique_ptr<Impl> d;
};
