#pragma once

#include <QObject>

#include <memory>

// HapticsService — cross-platform haptic feedback (base + per-platform subclass
// + compile-time create() factory). The base owns the enabled state and the
// QML-visible surface; each platform TU defines a concrete subclass overriding
// playImpl() plus this platform's create(). CMake links exactly one TU.
//
// QML usage (unchanged): haptics.light() / medium() / heavy() / success() /
// warning(). Desktop no-ops; iOS uses UIImpactFeedbackGenerator, Android the
// system Vibrator.
class HapticsService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit HapticsService(QObject* parent = nullptr);
    ~HapticsService() override;

    static std::unique_ptr<HapticsService> create(QObject* parent = nullptr);

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

protected:
    // Native feedback. level: 0=light 1=medium 2=heavy 3=success 4=warning.
    // Default base impl is a no-op so every platform builds and runs; platform
    // subclasses override with the real engine.
    virtual void playImpl(int level);

private:
    void play(int level);
    bool m_enabled = true;
};
