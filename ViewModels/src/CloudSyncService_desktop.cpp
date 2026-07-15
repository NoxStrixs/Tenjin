// CloudSyncService_desktop.cpp — desktop backend: the user points Tenjin at a
// folder their cloud client already syncs (OneDrive, Dropbox, Google Drive,
// Nextcloud, or even a plain directory). We just read/write snapshots there; the
// cloud client does the syncing. Chosen path persists in QSettings.

#include <ViewModels/CloudSyncService.h>

#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

namespace {
constexpr auto kSettingsKey = "cloudSync/folder";
}

class CloudSyncServiceDesktop final : public CloudSyncService
{
public:
    using CloudSyncService::CloudSyncService;

    bool available() const override
    {
        const QString f = folder();
        return !f.isEmpty() && QDir(f).exists();
    }

    QString locationLabel() const override
    {
        const QString f = folder();
        return f.isEmpty() ? tr("No folder selected") : QDir::toNativeSeparators(f);
    }

    QString syncFolder() const override
    {
        return folder();
    }

    // The desktop folder picker lives in QML (the project links no QtWidgets, so
    // QFileDialog isn't available). QML opens its FolderDialog and calls
    // setFolder() with the chosen URL; this just validates and persists it.
    void chooseLocation() override
    {
        // Nothing to do natively — QML drives the picker and calls setFolder().
        emit locationChosen(available());
    }

    void setFolder(const QString& urlOrPath) override
    {
        QString path = urlOrPath;
        // Accept both a file:// URL (from QML FolderDialog) and a plain path.
        const QUrl u(urlOrPath);
        if (u.isLocalFile())
            path = u.toLocalFile();
        if (path.isEmpty() || !QDir(path).exists()) {
            emit error(tr("That folder doesn't exist."));
            emit locationChosen(false);
            return;
        }
        QSettings().setValue(QString::fromLatin1(kSettingsKey), path);
        emit availableChanged();
        emit locationChosen(true);
    }

    QVariantList listSnapshots() const override
    {
        QVariantList  out;
        const QString f = folder();
        if (f.isEmpty())
            return out;
        QDir dir(f);
        // Tenjin snapshots are JSON exports; sort newest first.
        const auto entries =
            dir.entryInfoList({QStringLiteral("tenjin-*.json")}, QDir::Files, QDir::Time);
        for (const QFileInfo& fi : entries) {
            out.append(
                QVariantMap{{QStringLiteral("name"), fi.fileName()},
                            {QStringLiteral("path"), fi.absoluteFilePath()},
                            {QStringLiteral("sizeBytes"), fi.size()},
                            {QStringLiteral("modified"), fi.lastModified().toString(Qt::ISODate)}});
        }
        return out;
    }

private:
    static QString folder()
    {
        return QSettings().value(QString::fromLatin1(kSettingsKey)).toString();
    }
};

std::unique_ptr<CloudSyncService> CloudSyncService::create(QObject* parent)
{
    return std::make_unique<CloudSyncServiceDesktop>(parent);
}
