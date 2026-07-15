// TtsService_linux.cpp — native pronunciation on Linux via speech-dispatcher's
// `spd-say` command (the standard desktop speech front-end). No compile-time TTS
// dependency; degrades to hasTts()==false if spd-say isn't installed. Replaces
// QtTextToSpeech on Linux, removing the libspeechd link/deploy requirement.

#include <ViewModels/TtsService.h>

#include <QProcess>
#include <QStandardPaths>

namespace {
QString spdSayPath()
{
    return QStandardPaths::findExecutable(QStringLiteral("spd-say"));
}
} // namespace

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
    return !spdSayPath().isEmpty();
}

void TtsService::speak(const QString& text, const QString& language)
{
    if (text.isEmpty())
        return;
    const QString exe = spdSayPath();
    if (exe.isEmpty())
        return;
    stop();

    QStringList args;
    args << QStringLiteral("-w"); // wait so successive taps don't overlap oddly
    if (!language.isEmpty()) {
        // spd-say takes an ISO language code; strip any region ("ja_JP" -> "ja").
        QString lang = language;
        lang.replace(QStringLiteral("_"), QStringLiteral("-"));
        args << QStringLiteral("-l") << lang.section(QLatin1Char('-'), 0, 0);
    }
    args << text;

    d->proc = new QProcess();
    QObject::connect(d->proc,
                     QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                     d->proc, &QObject::deleteLater);
    d->proc->start(exe, args);
}

void TtsService::stop()
{
    // Cancel any in-progress speech across the session.
    QProcess::startDetached(QStringLiteral("spd-say"), {QStringLiteral("-C")});
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
