#pragma once

#include <QObject>

#include <memory>

// Native time picker. On iOS a UIDatePicker (.time) modal sheet; on Android a
// TimePickerDialog; on desktop no native picker (QML uses inline text entry).
// Follows the DocumentPickerService pattern: abstract base + per-platform
// backend + compile-time create() factory. Exposed to QML as a context
// property (not a QML-module type), so no QML_ELEMENT registration.
class TimePickerService : public QObject
{
    Q_OBJECT

public:
    explicit TimePickerService(QObject* parent = nullptr) : QObject(parent) {}
    ~TimePickerService() override = default;

    static std::unique_ptr<TimePickerService> create(QObject* parent = nullptr);

    // Present the native picker seeded with hour (0-23) and minute (0-59). The
    // platform decides 12h/24h from the device locale. Result via timePicked()
    // or pickCancelled(). Desktop backends emit pickCancelled() immediately so
    // QML falls back to inline text entry.
    Q_INVOKABLE void pickTime(int hour, int minute);

    // True when a native OS picker exists (iOS/Android). QML uses this to
    // decide whether to present the native picker on tap or show text entry.
    Q_INVOKABLE bool hasNativePicker() const;

signals:
    void timePicked(int hour, int minute);
    void pickCancelled();

protected:
    // Base default: no native picker (desktop). Emits pickCancelled().
    virtual void pickTimeNative(int hour, int minute);
    virtual bool hasNativePickerImpl() const;
};
