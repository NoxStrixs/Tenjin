#include <ViewModels/TtsService.h>

#ifdef TENJIN_TTS
#    include <QLocale>
#    include <QTextToSpeech>
#    include <QVoice>
#endif

#ifdef TENJIN_TTS

struct TtsService::Impl {
    QTextToSpeech engine;
};

TtsService::TtsService(QObject* parent) : QObject(parent), d(std::make_unique<Impl>()) {}
TtsService::~TtsService() = default;

bool TtsService::hasTts() const
{
    return d->engine.state() != QTextToSpeech::Error;
}

void TtsService::speak(const QString& text, const QString& language)
{
    if (text.isEmpty() || d->engine.state() == QTextToSpeech::Error)
        return;

    d->engine.stop();

    if (!language.isEmpty()) {
        // Prefer a locale whose language matches the requested code. QLocale
        // parses "ja", "fr", "en", "zh_CN", etc.
        const QLocale wanted(language);
        // Pick an available engine locale with the same language.
        const auto locales = d->engine.availableLocales();
        for (const QLocale& loc : locales) {
            if (loc.language() == wanted.language()) {
                d->engine.setLocale(loc);
                break;
            }
        }
        // Within the chosen locale, the first available voice is fine; the
        // engine keeps the current voice if none is set explicitly.
        const auto voices = d->engine.availableVoices();
        if (!voices.isEmpty())
            d->engine.setVoice(voices.first());
    }

    d->engine.say(text);
}

void TtsService::stop()
{
    d->engine.stop();
}

std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}

#else // TTS_SUPPORT off — stub

struct TtsService::Impl {
};
TtsService::TtsService(QObject* parent) : QObject(parent) {}
TtsService::~TtsService() = default;
bool TtsService::hasTts() const
{
    return false;
}
void                        TtsService::speak(const QString&, const QString&) {}
void                        TtsService::stop() {}
std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}

#endif
