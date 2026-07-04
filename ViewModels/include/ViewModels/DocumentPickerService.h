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

    // Present the native picker for a collection import (JSON / .apkg). The
    // result arrives asynchronously via documentPicked() with an app-readable
    // local path, or pickCancelled() if the user dismissed / no native picker
    // is available (caller then shows the in-app Documents picker).
    Q_INVOKABLE void pickImportDocument();

signals:
    // path is a sandbox-local, directly-readable file path.
    void documentPicked(const QString& path);
    void pickCancelled();

protected:
    // Native pick. Base default emits pickCancelled() (no native picker), so the
    // caller falls back to the in-app picker. Platform subclasses override to
    // present the OS picker and emit documentPicked() on completion.
    virtual void pickImportDocumentNative();
};
