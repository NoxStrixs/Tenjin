// CloudSyncService.cpp — base implementation. Platform backends override the
// virtuals; these defaults make an unsupported platform behave as "no sync
// configured" rather than misbehaving.

#include <ViewModels/CloudSyncService.h>

CloudSyncService::CloudSyncService(QObject* parent) : QObject(parent) {}
CloudSyncService::~CloudSyncService() = default;

bool CloudSyncService::available() const
{
    return false;
}

QString CloudSyncService::locationLabel() const
{
    return tr("Cloud sync isn't available on this platform");
}

QString CloudSyncService::syncFolder() const
{
    return {};
}

void CloudSyncService::chooseLocation()
{
    emit locationChosen(false);
}

void CloudSyncService::setFolder(const QString&)
{
    // Platforms with an implicit location (iCloud) or a system picker (SAF)
    // don't take a folder path from QML.
}

QVariantList CloudSyncService::listSnapshots() const
{
    return {};
}

void CloudSyncService::publish(const QString&) {}

QString CloudSyncService::materialize(const QString& name)
{
    // Backends with a real filesystem folder can use the path directly.
    const QString f = syncFolder();
    return f.isEmpty() ? QString() : f + QLatin1Char('/') + name;
}

void CloudSyncService::setBusy(bool v)
{
    if (m_busy == v)
        return;
    m_busy = v;
    emit busyChanged();
}
