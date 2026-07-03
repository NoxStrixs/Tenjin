#pragma once

#include <QObject>

// HapticsService — cross-platform haptic feedback for tactile UI events.
//
// On iOS/Android, triggers the device's haptic engine. On desktop, no-ops.
// QML usage:
//   haptics.light()    — selection change, toggle
//   haptics.medium()   — button press, item added
//   haptics.heavy()    — destructive action (delete), error
//   haptics.success()  — completed review session
//   haptics.warning()  — validation failure
//
// Backed by Qt 6.8's QHapticFeedbackEffect where available; falls back to a
// simple vibration on platforms without the rich haptics API.
class HapticsService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit HapticsService(QObject* parent = nullptr);

    bool enabled() const
    {
        return m_enabled;
    }
    void setEnabled(bool v);

    Q_INVOKABLE void light();
    Q_INVOKABLE void medium();
    Q_INVOKABLE void heavy();
    Q_INVOKABLE void success();
    Q_INVOKABLE void warning();

signals:
    void enabledChanged();

private:
    void play(int level); // 0=light 1=medium 2=heavy 3=success 4=warning
    bool m_enabled = true;
};
