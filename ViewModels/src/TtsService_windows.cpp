// TtsService_windows.cpp — native pronunciation on Windows using the built-in
// System.Speech synthesizer, invoked via a hidden PowerShell process. This
// avoids linking SAPI/COM directly (keeps the MinGW cross-build clean) while
// still using the OS speech engine. Replaces QtTextToSpeech on Windows.

#include <ViewModels/TtsService.h>

#include <QProcess>
#include <QStringList>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

struct TtsService::Impl {
    QProcess* proc = nullptr;
};

TtsService::TtsService(QObject* parent) : QObject(parent), d(std::make_unique<Impl>()) {}
TtsService::~TtsService()
{
    if (d->proc) {
        d->proc->kill();
        d->proc->deleteLater();
    }
}

bool TtsService::hasTts() const
{
    // System.Speech ships with .NET on all supported Windows versions.
    return true;
}

void TtsService::speak(const QString& text, const QString& language)
{
    if (text.isEmpty())
        return;
    stop();

    // Escape single quotes for the PowerShell string literal.
    QString safe = text;
    safe.replace(QStringLiteral("'"), QStringLiteral("''"));
    QString lang = language;
    lang.replace(QStringLiteral("_"), QStringLiteral("-"));

    // Build a script that selects a voice matching the language when possible.
    const QString script = QStringLiteral(
        "Add-Type -AssemblyName System.Speech;"
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "try { if ('%1' -ne '') { "
        "  $v = $s.GetInstalledVoices() | Where-Object { $_.VoiceInfo.Culture.Name -like '%1*' } | Select-Object -First 1;"
        "  if ($v) { $s.SelectVoice($v.VoiceInfo.Name) } } } catch {};"
        "$s.Speak('%2');").arg(lang, safe);

    d->proc = new QProcess();
    d->proc->setProgram(QStringLiteral("powershell"));
    d->proc->setArguments({QStringLiteral("-NoProfile"), QStringLiteral("-WindowStyle"),
                           QStringLiteral("Hidden"), QStringLiteral("-NonInteractive"),
                           QStringLiteral("-Command"), script});
#ifdef Q_OS_WIN
    d->proc->setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments* args) {
            args->flags |= CREATE_NO_WINDOW;
        });
#endif
    QObject::connect(d->proc,
                     QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                     d->proc, &QObject::deleteLater);
    d->proc->start();
}

void TtsService::stop()
{
    if (d->proc) {
        d->proc->kill();
        d->proc->deleteLater();
        d->proc = nullptr;
    }
}

std::unique_ptr<TtsService> TtsService::create(QObject* parent)
{
    return std::make_unique<TtsService>(parent);
}
