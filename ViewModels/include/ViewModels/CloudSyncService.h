#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

#include <memory>

// CloudSyncService — manual export/import to the user's OWN cloud storage.
//
// Deliberately file-based rather than API-based: Tenjin's JSON export is already
// self-contained (text, decks, tags, relations, scheduling, and media embedded
// as base64), so "sync" reduces to writing that file into a folder the OS
// already syncs, and reading it back on another device. No OAuth, no per-service
// API keys, no server, and no user data passing through us.
//
// Platform backends resolve `syncFolder()`:
//   - Apple  : iCloud Drive ubiquity container (Documents), so the file appears
//              in the user's iCloud and syncs to their other Apple devices.
//   - Android: a Storage Access Framework tree the user picks once (Google
//              Drive, or any provider that exposes a document tree).
//   - Desktop: a plain folder path the user chooses (their OneDrive/Dropbox/
//              Drive client folder), persisted in settings.
//
// This is whole-file backup/restore, not record-level merge: importing replaces
// local data from the chosen snapshot. Files are timestamped so a device never
// silently clobbers another's snapshot — the user picks which to restore.
class CloudSyncService : public QObject
{
    Q_OBJECT
    // True when a sync folder is configured/available on this platform.
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    // Human-readable description of where files go (shown in Settings).
    Q_PROPERTY(QString locationLabel READ locationLabel NOTIFY availableChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit CloudSyncService(QObject* parent = nullptr);
    ~CloudSyncService() override;

    // Per-platform backend factory (iCloud / SAF / folder).
    static std::unique_ptr<CloudSyncService> create(QObject* parent = nullptr);

    virtual bool    available() const;
    virtual QString locationLabel() const;
    bool            busy() const
    {
        return m_busy;
    }

    // Let the user choose/authorize the sync location. On Apple this is a no-op
    // (iCloud container is implicit); on Android it opens the SAF tree picker;
    // on desktop it opens a folder picker. Emits locationChosen(ok).
    Q_INVOKABLE virtual void chooseLocation();

    // Desktop: QML's FolderDialog supplies the chosen folder (the project links
    // no QtWidgets, so there's no native C++ folder picker). Accepts a file://
    // URL or a plain path. No-op on platforms with an implicit/native location.
    Q_INVOKABLE virtual void setFolder(const QString& urlOrPath);

    // Absolute writable path of the sync folder, or empty when unavailable.
    // On Android this is a local mirror path that the backend syncs to the SAF
    // tree; callers should treat it as opaque and use it with export/import.
    virtual QString syncFolder() const;

    // Snapshots currently in the sync folder, newest first. Each map:
    //   name (QString), path (QString), sizeBytes (qint64), modified (QString)
    Q_INVOKABLE virtual QVariantList listSnapshots() const;

    // Called by AppViewModel after it writes an export into syncFolder(), so
    // backends that need an explicit push (SAF) can copy it out. Default no-op.
    virtual void publish(const QString& localPath);

    // Make a listed snapshot readable at a local path (Android copies it out of
    // the SAF tree into staging; other backends already have a real path).
    // Returns the local absolute path, or empty on failure.
    Q_INVOKABLE virtual QString materialize(const QString& name);

signals:
    void availableChanged();
    void busyChanged();
    void locationChosen(bool ok);
    void error(const QString& message);

protected:
    void setBusy(bool v);

    bool m_busy = false;
};
