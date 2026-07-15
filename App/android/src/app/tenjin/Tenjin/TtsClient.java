package app.tenjin.Tenjin;

import android.content.Context;
import android.speech.tts.TextToSpeech;

import java.util.Locale;

// Thin wrapper over the Android platform TextToSpeech engine, driven from C++
// via JNI (TtsService_android.cpp). One instance per app; init is async so
// speak() queues until the engine is ready.
public final class TtsClient {

    private static TextToSpeech sEngine = null;
    private static boolean sReady = false;

    public static void init(Context ctx) {
        if (sEngine != null) return;
        sEngine = new TextToSpeech(ctx, status -> {
            sReady = (status == TextToSpeech.SUCCESS);
        });
    }

    public static boolean isReady() {
        return sReady;
    }

    public static void speak(String text, String language) {
        if (sEngine == null || !sReady || text == null) return;
        if (language != null && !language.isEmpty()) {
            // Accept "ja", "zh_CN", "zh-CN"; Locale.forLanguageTag wants hyphens.
            Locale loc = Locale.forLanguageTag(language.replace('_', '-'));
            int r = sEngine.setLanguage(loc);
            if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                sEngine.setLanguage(Locale.getDefault());
            }
        }
        sEngine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tenjin");
    }

    public static void stop() {
        if (sEngine != null) sEngine.stop();
    }
}
