#pragma once

#include <QObject>
#include <QString>

#include <memory>

// DocumentPickerService — native document import picker (base + per-platform
// subclass + compile-time create() factory). Promoted from a free-function hook
// to a QObject so its async result is delivered as a Qt signal (1a contract),
// and so it can serve as the seat for a future FilesystemService that persists
// security-scoped bookmarks / SAF URI permissions.
//
// The async native pick completes on the platform's main thread; subclasses
// marshal the result back and emit documentPicked() (or pickCancelled()).
class DocumentPickerService : public QObject
{
    Q_OBJECT

public:
    explicit DocumentPickerService(QObject* parent = nullptr);
    ~DocumentPickerService() override;

    static std::unique_ptr<DocumentPickerService> create(QObject* parent = nullptr);

    // Collection import picker (JSON/.apkg). Result via documentPicked().
    Q_INVOKABLE void pickImportDocument();

    // Media source for pickMedia(). Kept in sync with the QML chooser.
    enum class MediaSource { Files = 0, Photos = 1, Camera = 2 };
    Q_ENUM(MediaSource)

    // Media attach picker (image/audio/video for entry content). The QML layer
    // presents the custom chooser (file/photo/camera) and calls this with the
    // chosen source; each routes to the platform-native picker. Result arrives
    // via mediaPicked() with a sandbox-local, directly-readable path, or
    // pickCancelled(). Desktop supports Files only (photo/camera fall back to
    // the native file dialog filtered to media types).
    Q_INVOKABLE void pickMedia(MediaSource source);

signals:
    // path is a sandbox-local, directly-readable file path.
    void documentPicked(const QString& path);
    void mediaPicked(const QString& path);
    void pickCancelled();

protected:
    // Native pick. Base default emits pickCancelled() (no native picker), so the
    // caller falls back to the in-app picker. Platform subclasses override to
    // present the OS picker and emit documentPicked() on completion.
    virtual void pickImportDocumentNative();

    // Native media pick per source. Base default emits pickCancelled(); desktop
    // and platform subclasses override. Emits mediaPicked() on completion.
    virtual void pickMediaNative(MediaSource source);
};
