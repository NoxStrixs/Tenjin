// NotificationService_linux.cpp — Linux desktop backend.
//
// Immediate notifications go through `notify-send` (libnotify / the desktop's
// D-Bus notification daemon). Daily reminders that must fire while the app is
// CLOSED are implemented with a systemd *user* timer: we write a .service +
// .timer unit under ~/.config/systemd/user and enable it. systemd then runs
// notify-send at the scheduled time regardless of whether Tenjin is running.
//
// This is the most portable "closed-app" path on modern Linux — systemd user
// instances are standard across GNOME, KDE, and most distributions. If systemd
// is unavailable the schedule call degrades (returns false) and the base
// class's in-app fallback applies.

#include <ViewModels/NotificationService.h>

#include <QVariantMap>

#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QTextStream>

namespace {

QString userSystemdDir()
{
    return QDir::homePath() + QStringLiteral("/.config/systemd/user");
}

// Locate notify-send once; used by the timer unit and immediate delivery.
QString notifySendPath()
{
    const QString p = QStandardPaths::findExecutable(QStringLiteral("notify-send"));
    return p;
}

class NotificationServiceLinux final : public NotificationService
{
public:
    using NotificationService::NotificationService;

protected:
    // Immediate desktop notification via notify-send.
    bool deliverNative(const QString& title, const QString& body,
                       const QVariantMap& /*payload*/) override
    {
        const QString exe = notifySendPath();
        if (exe.isEmpty())
            return false; // -> base falls back to in-app toast
        return QProcess::startDetached(
            exe, {QStringLiteral("-a"), QStringLiteral("Tenjin"), title, body});
    }

    bool requestPermissionNative() override { return true; }

    // Write + enable a systemd user timer that fires daily at hour:minute and
    // runs notify-send, so the reminder appears with the app closed.
    bool scheduleDailyNative(int hour, int minute, const QString& title,
                             const QString& body) override
    {
        const QString exe = notifySendPath();
        if (exe.isEmpty())
            return false;

        const QString dir = userSystemdDir();
        if (!QDir().mkpath(dir))
            return false;

        // .service — oneshot that shows the notification.
        {
            QFile svc(dir + QStringLiteral("/tenjin-reminder.service"));
            if (!svc.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return false;
            QTextStream s(&svc);
            s << "[Unit]\n"
              << "Description=Tenjin daily study reminder\n\n"
              << "[Service]\n"
              << "Type=oneshot\n"
              << "ExecStart=" << exe << " -a Tenjin \""
              << title << "\" \"" << body << "\"\n";
        }

        // .timer — fires every day at the chosen local time, and catches up if
        // the machine was asleep/off at the scheduled moment (Persistent=true).
        {
            QFile tmr(dir + QStringLiteral("/tenjin-reminder.timer"));
            if (!tmr.open(QIODevice::WriteOnly | QIODevice::Truncate))
                return false;
            QTextStream t(&tmr);
            t << "[Unit]\n"
              << "Description=Tenjin daily study reminder timer\n\n"
              << "[Timer]\n"
              << "OnCalendar=*-*-* "
              << QString::asprintf("%02d:%02d:00", hour, minute) << "\n"
              << "Persistent=true\n\n"
              << "[Install]\n"
              << "WantedBy=timers.target\n";
        }

        // Reload the user manager and enable+start the timer.
        QProcess::execute(QStringLiteral("systemctl"),
                          {QStringLiteral("--user"), QStringLiteral("daemon-reload")});
        return QProcess::execute(
                   QStringLiteral("systemctl"),
                   {QStringLiteral("--user"), QStringLiteral("enable"),
                    QStringLiteral("--now"), QStringLiteral("tenjin-reminder.timer")}) == 0;
    }

    void cancelDailyNative() override
    {
        QProcess::execute(
            QStringLiteral("systemctl"),
            {QStringLiteral("--user"), QStringLiteral("disable"),
             QStringLiteral("--now"), QStringLiteral("tenjin-reminder.timer")});
        const QString dir = userSystemdDir();
        QFile::remove(dir + QStringLiteral("/tenjin-reminder.timer"));
        QFile::remove(dir + QStringLiteral("/tenjin-reminder.service"));
        QProcess::execute(QStringLiteral("systemctl"),
                          {QStringLiteral("--user"), QStringLiteral("daemon-reload")});
    }
};

} // namespace

std::unique_ptr<NotificationService> NotificationService::create(QObject* parent)
{
    return std::make_unique<NotificationServiceLinux>(parent);
}
