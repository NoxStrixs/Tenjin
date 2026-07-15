// TtsService_apple.mm — native pronunciation via AVSpeechSynthesizer on iOS and
// macOS. Replaces the QtTextToSpeech backend so the app no longer depends on the
// qtspeech module (which caused iOS static-link and Linux libspeechd issues).
//
// speak() picks an AVSpeechSynthesisVoice matching the requested BCP-47 language
// (e.g. "ja", "fr", "zh-CN"); AVFoundation ships voices for all common locales.

#include <ViewModels/TtsService.h>

#import <AVFoundation/AVFoundation.h>

struct TtsService::Impl {
    AVSpeechSynthesizer* synth = nil;
};

TtsService::TtsService(QObject* parent) : QObject(parent), d(std::make_unique<Impl>())
{
    d->synth = [[AVSpeechSynthesizer alloc] init];
}

TtsService::~TtsService() = default;

bool TtsService::hasTts() const
{
    // AVSpeechSynthesizer is always available on iOS/macOS.
    return d->synth != nil;
}

void TtsService::speak(const QString& text, const QString& language)
{
    if (text.isEmpty() || d->synth == nil)
        return;

    // Interrupt anything currently speaking.
    [d->synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

    NSString* nsText = text.toNSString();
    AVSpeechUtterance* utt = [AVSpeechUtterance speechUtteranceWithString:nsText];

    if (!language.isEmpty()) {
        // AVFoundation uses BCP-47 tags with a hyphen ("zh-CN"), while callers
        // may pass "zh_CN"; normalize underscores.
        NSString* lang = language.toNSString();
        lang = [lang stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
        AVSpeechSynthesisVoice* voice = [AVSpeechSynthesisVoice voiceWithLanguage:lang];
        if (voice == nil) {
            // Fall back to matching just the primary subtag (e.g. "ja" from
            // "ja-JP") against the available voices.
            NSString* primary = [[lang componentsSeparatedByString:@"-"] firstObject];
            for (AVSpeechSynthesisVoice* v in [AVSpeechSynthesisVoice speechVoices]) {
                if ([v.language hasPrefix:primary]) { voice = v; break; }
            }
        }
        if (voice != nil)
            utt.voice = voice;
    }

    [d->synth speakUtterance:utt];
}

void TtsService::stop()
{
    if (d->synth != nil)
        [d->synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
}

std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}
