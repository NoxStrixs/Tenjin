#include <ViewModels/NotificationService.h>

#include <QDateTime>
#include <QSettings>
#include <QTimer>

#include <limits>


NotificationService::NotificationService(QObject* parent) : QObject(parent)
{
    loadSettings();
    m_dailyTimer = new QTimer(this);
    m_dailyTimer->setSingleShot(true);
    connect(m_dailyTimer, &QTimer::timeout, this, [this]() {
        if (m_reminderEnabled) {
            const QString body =
                m_reminderBody.isEmpty() ? tr("You have cards ready to review.") : m_reminderBody;
            deliverLocalPush(tr("Time to review"), body, {{"type", "dailyReminder"}});
        }
        rescheduleDaily(); // arm the next day
    });
    if (m_reminderEnabled)
        rescheduleDaily();
}

NotificationService::~NotificationService() = default;

// Immediate
void NotificationService::toast(const QString& message, int level)
{
    emit toastRequested(message, level);
}

void NotificationService::alert(const QString& title, const QString& body)
{
    emit alertRequested(title, body);
}

void NotificationService::localPush(const QString& title, const QString& body)
{
    deliverLocalPush(title, body);
}

// Permission
void NotificationService::requestPermission()
{
    // Platform backend performs the real request (Android 13+ runtime prompt;
    // iOS authorization is requested at first delivery). Desktop grants
    // immediately. The granted flag is optimistic on Android because the prompt
    // is async; actual denial simply means notifications won't appear, which the
    // app already tolerates (it falls back to in-app toasts while focused).
    const bool ok       = requestPermissionNative();
    m_permissionGranted = ok;
    emit permissionResult(ok);
}

// Ad-hoc scheduled reminders
int NotificationService::scheduleReminder(const QString& title, const QString& body, qint64 epochMs)
{
    const int    id      = m_nextId++;
    const qint64 nowMs   = QDateTime::currentMSecsSinceEpoch();
    const qint64 delayMs = epochMs - nowMs;

    m_pending.append({id, title, body, epochMs});

    if (delayMs <= 0) {
        deliverLocalPush(title, body, {{"reminderId", id}});
        m_pending.removeIf([id](const PendingReminder& r) { return r.id == id; });
        return id;
    }

    auto* timer = new QTimer(this);
    timer->setSingleShot(true);
    timer->setInterval(
        static_cast<int>(qMin(delayMs, static_cast<qint64>(std::numeric_limits<int>::max()))));
    timer->setProperty("reminderId", id);
    connect(timer, &QTimer::timeout, this, [this, id, title, body, timer]() {
        deliverLocalPush(title, body, {{"reminderId", id}});
        m_pending.removeIf([id](const PendingReminder& r) { return r.id == id; });
        timer->deleteLater();
    });
    timer->start();
    return id;
}

void NotificationService::cancelReminder(int id)
{
    m_pending.removeIf([id](const PendingReminder& r) { return r.id == id; });
    for (QTimer* t : findChildren<QTimer*>()) {
        if (t == m_dailyTimer)
            continue;
        if (t->property("reminderId").toInt() == id) {
            t->stop();
            t->deleteLater();
            return;
        }
    }
}

void NotificationService::cancelAllReminders()
{
    m_pending.clear();
    for (QTimer* t : findChildren<QTimer*>()) {
        if (t == m_dailyTimer)
            continue;
        t->stop();
        t->deleteLater();
    }
}

// Daily review reminder
void NotificationService::setReminderEnabled(bool v)
{
    if (m_reminderEnabled == v)
        return;
    m_reminderEnabled = v;
    saveSettings();
    if (v) {
        if (!m_permissionGranted)
            requestPermission();
        rescheduleDaily();
    } else if (m_dailyTimer) {
        m_dailyTimer->stop();
    }
    emit reminderChanged();
}

void NotificationService::setReminderHour(int h)
{
    h = qBound(0, h, 23);
    if (m_reminderHour == h)
        return;
    m_reminderHour = h;
    saveSettings();
    if (m_reminderEnabled)
        rescheduleDaily();
    emit reminderChanged();
}

void NotificationService::setReminderMinute(int m)
{
    m = qBound(0, m, 59);
    if (m_reminderMinute == m)
        return;
    m_reminderMinute = m;
    saveSettings();
    if (m_reminderEnabled)
        rescheduleDaily();
    emit reminderChanged();
}

void NotificationService::setReminderBody(const QString& body)
{
    m_reminderBody = body;
}

qint64 NotificationService::nextDailyEpochMs() const
{
    const QDateTime now = QDateTime::currentDateTime();
    QDateTime       target(now.date(), QTime(m_reminderHour, m_reminderMinute));
    if (target <= now)
        target = target.addDays(1);
    return target.toMSecsSinceEpoch();
}

void NotificationService::rescheduleDaily()
{
    if (!m_dailyTimer)
        return;
    m_dailyTimer->stop();
    cancelDailyNative();
    if (!m_reminderEnabled)
        return;

    // Prefer the OS scheduler so the reminder fires even when the app is
    // suspended or killed (mobile). If the platform scheduled it natively, no
    // in-process timer is needed. Desktop returns false and falls back to the
    // QTimer, which only fires while the app runs.
    const QString title = tr("Time to review");
    if (scheduleDailyNative(m_reminderHour, m_reminderMinute, title, m_reminderBody))
        return;

    const qint64 delay = nextDailyEpochMs() - QDateTime::currentMSecsSinceEpoch();
    const qint64 clamped =
        qBound(static_cast<qint64>(0), delay, static_cast<qint64>(std::numeric_limits<int>::max()));
    m_dailyTimer->setInterval(static_cast<int>(clamped));
    m_dailyTimer->start();
}

// Base defaults: desktop has no OS daily scheduler (falls back to QTimer).
bool NotificationService::scheduleDailyNative(int, int, const QString&, const QString&)
{
    return false;
}

void NotificationService::cancelDailyNative() {}

void NotificationService::loadSettings()
{
    QSettings s;
    m_reminderEnabled = s.value("reminders/dailyEnabled", false).toBool();
    m_reminderHour    = s.value("reminders/dailyHour", 9).toInt();
    m_reminderMinute  = s.value("reminders/dailyMinute", 0).toInt();
}

void NotificationService::saveSettings()
{
    QSettings s;
    s.setValue("reminders/dailyEnabled", m_reminderEnabled);
    s.setValue("reminders/dailyHour", m_reminderHour);
    s.setValue("reminders/dailyMinute", m_reminderMinute);
}

// Delivery (no-op default; platform backends override)
void NotificationService::deliverLocalPush(const QString&     title,
                                           const QString&     body,
                                           const QVariantMap& payload)
{
    // Try the platform backend first (real OS notification that fires even when
    // backgrounded). On iOS/Android the platform TU implements this; elsewhere
    // the weak default returns false and we fall back to an in-app toast.
    if (deliverNative(title, body, payload))
        return;
    emit toastRequested(title + QStringLiteral(": ") + body, 0);
}

// Native surface: base defaults (desktop)
// Platform subclasses override these; the base provides safe desktop behaviour
// so the app runs everywhere. Base delivery does nothing at the OS level (the
// caller falls back to an in-app toast); base permission is auto-granted.
bool NotificationService::deliverNative(const QString& /*title*/, const QString& /*body*/,
                                        const QVariantMap& /*payload*/)
{
    return false;
}

bool NotificationService::requestPermissionNative()
{
    return true;
}
