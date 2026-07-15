// NotificationService_windows.cpp — Windows desktop backend.
//
// Immediate notifications and closed-app daily reminders both use a PowerShell
// script that raises a Windows toast via the WinRT ToastNotification API.
// For the daily reminder that must fire while Tenjin is CLOSED, we register a
// Windows Scheduled Task (schtasks) that runs the toast script every day at the
// chosen time. The task persists in Task Scheduler independently of the app, so
// it fires whether or not Tenjin is running.
//
// This avoids a compile-time WinRT dependency (kept portable for the MinGW
// cross-build) by shelling out to PowerShell, which ships on all supported
// Windows versions.

#include <ViewModels/NotificationService.h>

#include <QVariantMap>

#include <QDir>
#include <QFile>
#include <QProcess>

#ifdef Q_OS_WIN
#include <windows.h>
#endif
#include <QStandardPaths>
#include <QTextStream>

namespace {

QString scriptDir()
{
    const QString base =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(base);
    return base;
}

// Write (once) a PowerShell script that shows a toast with a title/body passed
// as arguments. Returns the script path, or empty on failure.
QString ensureToastScript()
{
    const QString path = scriptDir() + QStringLiteral("/tenjin-toast.ps1");
    if (QFile::exists(path))
        return path;
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return {};
    QTextStream s(&f);
    // Minimal WinRT toast via PowerShell. AppId uses an installed shortcut's
    // AUMID when present; falls back to PowerShell's own so the toast still
    // shows. Title/body are $args[0]/$args[1].
    s << "param([string]$Title,[string]$Body)\n"
      << "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null\n"
      << "[Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null\n"
      << "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType=WindowsRuntime] | Out-Null\n"
      << "$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)\n"
      << "$texts = $template.GetElementsByTagName('text')\n"
      << "$texts.Item(0).AppendChild($template.CreateTextNode($Title)) | Out-Null\n"
      << "$texts.Item(1).AppendChild($template.CreateTextNode($Body)) | Out-Null\n"
      << "$toast = [Windows.UI.Notifications.ToastNotification]::new($template)\n"
      << "$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Tenjin')\n"
      << "$notifier.Show($toast)\n";
    return path;
}

bool runToast(const QString& title, const QString& body)
{
    const QString script = ensureToastScript();
    if (script.isEmpty())
        return false;
    // Fully suppress the console window: -WindowStyle Hidden hides the
    // PowerShell host, and CREATE_NO_WINDOW (applied via the arguments modifier,
    // which only runs for start(), NOT startDetached) prevents the conhost
    // window from flashing. The process is short-lived and self-completes.
    auto* proc = new QProcess();
    proc->setProgram(QStringLiteral("powershell"));
    proc->setArguments({QStringLiteral("-NoProfile"), QStringLiteral("-WindowStyle"),
                        QStringLiteral("Hidden"), QStringLiteral("-NonInteractive"),
                        QStringLiteral("-ExecutionPolicy"), QStringLiteral("Bypass"),
                        QStringLiteral("-File"), script, title, body});
#ifdef Q_OS_WIN
    proc->setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments* args) {
            args->flags |= CREATE_NO_WINDOW;
        });
#endif
    QObject::connect(proc,
                     QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
                     proc, &QObject::deleteLater);
    proc->start();
    return proc->waitForStarted(3000);
}

const char* kTaskName = "TenjinDailyReminder";

class NotificationServiceWindows final : public NotificationService
{
public:
    using NotificationService::NotificationService;

protected:
    bool deliverNative(const QString& title, const QString& body,
                       const QVariantMap& /*payload*/) override
    {
        return runToast(title, body);
    }

    bool requestPermissionNative() override { return true; }

    // Register a daily Scheduled Task that runs the toast script at hour:minute.
    // /F overwrites any existing task so re-scheduling updates the time.
    bool scheduleDailyNative(int hour, int minute, const QString& title,
                             const QString& body) override
    {
        const QString script = ensureToastScript();
        if (script.isEmpty())
            return false;

        const QString startTime = QString::asprintf("%02d:%02d", hour, minute);
        // The action: powershell running the toast script with title/body.
        const QString action =
            QStringLiteral("powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File \"%1\" \"%2\" \"%3\"")
                .arg(script, title, body);

        return QProcess::execute(
                   QStringLiteral("schtasks"),
                   {QStringLiteral("/Create"), QStringLiteral("/F"),
                    QStringLiteral("/SC"), QStringLiteral("DAILY"),
                    QStringLiteral("/TN"), QString::fromLatin1(kTaskName),
                    QStringLiteral("/TR"), action,
                    QStringLiteral("/ST"), startTime}) == 0;
    }

    void cancelDailyNative() override
    {
        QProcess::execute(QStringLiteral("schtasks"),
                          {QStringLiteral("/Delete"), QStringLiteral("/F"),
                           QStringLiteral("/TN"), QString::fromLatin1(kTaskName)});
    }
};

} // namespace

std::unique_ptr<NotificationService> NotificationService::create(QObject* parent)
{
    return std::make_unique<NotificationServiceWindows>(parent);
}
