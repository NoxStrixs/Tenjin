#pragma once

#include <QObject>
#include <QTime>
#include <QVariantMap>

#include <memory>

class QTimer;

class NotificationService : public QObject
{
    Q_OBJECT

    // Daily review-reminder settings, persisted via QSettings.
    Q_PROPERTY(
        bool reminderEnabled READ reminderEnabled WRITE setReminderEnabled NOTIFY reminderChanged)
    Q_PROPERTY(int reminderHour READ reminderHour WRITE setReminderHour NOTIFY reminderChanged)
    Q_PROPERTY(
        int reminderMinute READ reminderMinute WRITE setReminderMinute NOTIFY reminderChanged)
    Q_PROPERTY(bool permissionGranted READ permissionGranted NOTIFY permissionResult)

public:
    enum class Level { Info = 0, Warning = 1, Error = 2 };
    Q_ENUM(Level)

    explicit NotificationService(QObject* parent = nullptr);
    ~NotificationService() override;

    // Compile-time factory. Defined once per platform TU; CMake links one.
    static std::unique_ptr<NotificationService> create(QObject* parent = nullptr);

    // ── Immediate notifications ──────────────────────────────────────────────
    Q_INVOKABLE void toast(const QString& message, int level = 0);
    Q_INVOKABLE void alert(const QString& title, const QString& body);
    Q_INVOKABLE void localPush(const QString& title, const QString& body);

    // ── Ad-hoc scheduled reminders ───────────────────────────────────────────
    Q_INVOKABLE int  scheduleReminder(const QString& title, const QString& body, qint64 epochMs);
    Q_INVOKABLE void cancelReminder(int id);
    Q_INVOKABLE void cancelAllReminders();

    // ── Permission ───────────────────────────────────────────────────────────
    Q_INVOKABLE void requestPermission();
    bool             permissionGranted() const
    {
        return m_permissionGranted;
    }

    // ── Daily review reminder ────────────────────────────────────────────────
    // A recurring local notification fired once per day at the configured time.
    // The body text is supplied dynamically (e.g. "You have 5 cards due") by the
    // caller via setReminderBody before the next fire.
    bool reminderEnabled() const
    {
        return m_reminderEnabled;
    }
    int reminderHour() const
    {
        return m_reminderHour;
    }
    int reminderMinute() const
    {
        return m_reminderMinute;
    }
    void setReminderEnabled(bool v);
    void setReminderHour(int h);
    void setReminderMinute(int m);

    // Update the message shown at the next daily fire.
    Q_INVOKABLE void setReminderBody(const QString& body);

signals:
    void toastRequested(const QString& message, int level);
    void alertRequested(const QString& title, const QString& body);
    void notificationActivated(const QVariantMap& payload);
    void permissionResult(bool granted);
    void reminderChanged();

protected:
    // Native surface (the only platform-varying operations). Base defaults
    // are desktop behaviour: no OS delivery, permission auto-granted.
    // Return true from deliverNative() if a real OS notification was posted;
    // false falls back to an in-app toast.
    virtual bool deliverNative(const QString& title, const QString& body,
                               const QVariantMap& payload);
    virtual bool requestPermissionNative();

    // Schedule a repeating daily OS notification at hour:minute. Returns true if
    // the platform scheduled it with the OS (so it fires even when the app is
    // suspended/killed — iOS UNCalendarNotificationTrigger, Android
    // AlarmManager). Returns false on desktop, where the base falls back to an
    // in-process QTimer (only fires while running). cancelDailyNative() clears
    // any OS-scheduled daily reminder.
    virtual bool scheduleDailyNative(int hour, int minute, const QString& title,
                                     const QString& body);
    virtual void cancelDailyNative();

private:
    void
    deliverLocalPush(const QString& title, const QString& body, const QVariantMap& payload = {});
    void   rescheduleDaily(); // (re)arm the daily timer from current settings
    void   loadSettings();
    void   saveSettings();
    qint64 nextDailyEpochMs() const; // next occurrence of HH:MM, today or tomorrow

    struct PendingReminder {
        int     id;
        QString title;
        QString body;
        qint64  epochMs;
    };
    QList<PendingReminder> m_pending;
    int                    m_nextId = 1;

    bool    m_permissionGranted = false;
    bool    m_reminderEnabled   = false;
    int     m_reminderHour      = 9;
    int     m_reminderMinute    = 0;
    QString m_reminderBody;
    QTimer* m_dailyTimer = nullptr;
};
