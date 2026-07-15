// CloudSyncService_apple.mm — Apple backend using the app's iCloud Drive
// ubiquity container. Snapshots written into <container>/Documents appear in the
// user's iCloud Drive (visible in Files.app under Tenjin) and sync to their
// other Apple devices automatically — no login UI, no OAuth: it uses whatever
// iCloud account the device is signed into.
//
// REQUIRES entitlements to actually resolve a container:
//   com.apple.developer.icloud-container-identifiers = iCloud.app.tenjin.Tenjin
//   com.apple.developer.ubiquity-container-identifiers = iCloud.app.tenjin.Tenjin
//   com.apple.developer.icloud-services = CloudDocuments
// plus the matching container enabled on the provisioning profile. Without them
// URLForUbiquityContainerIdentifier returns nil and available() is false, so the
// UI degrades to "iCloud unavailable" rather than misbehaving.

#include <ViewModels/CloudSyncService.h>

#include <QDateTime>
#include <QDir>
#include <QFileInfo>

#import <Foundation/Foundation.h>

namespace {

// Resolve <ubiquity container>/Documents, creating it if needed. Empty on
// failure (not signed in, entitlement missing, iCloud Drive disabled).
QString ubiquityDocuments()
{
    NSFileManager* fm = [NSFileManager defaultManager];
    // nil identifier = the first container listed in the entitlements.
    NSURL* container = [fm URLForUbiquityContainerIdentifier:nil];
    if (container == nil)
        return {};
    NSURL* docs = [container URLByAppendingPathComponent:@"Documents"];
    NSError* err = nil;
    [fm createDirectoryAtURL:docs
 withIntermediateDirectories:YES
                  attributes:nil
                       error:&err];
    if (err != nil)
        return {};
    return QString::fromNSString([docs path]);
}

} // namespace

class CloudSyncServiceApple final : public CloudSyncService
{
public:
    using CloudSyncService::CloudSyncService;

    bool available() const override { return !ubiquityDocuments().isEmpty(); }

    QString locationLabel() const override
    {
        return available() ? tr("iCloud Drive (Tenjin)")
                           : tr("iCloud unavailable — sign in to iCloud Drive");
    }

    QString syncFolder() const override { return ubiquityDocuments(); }

    // iCloud needs no picker: the container is implicit once entitled.
    void chooseLocation() override { emit locationChosen(available()); }

    QVariantList listSnapshots() const override
    {
        QVariantList out;
        const QString f = ubiquityDocuments();
        if (f.isEmpty())
            return out;
        QDir dir(f);
        const auto entries = dir.entryInfoList({QStringLiteral("tenjin-*.json")},
                                               QDir::Files, QDir::Time);
        for (const QFileInfo& fi : entries) {
            out.append(QVariantMap{
                {QStringLiteral("name"), fi.fileName()},
                {QStringLiteral("path"), fi.absoluteFilePath()},
                {QStringLiteral("sizeBytes"), fi.size()},
                {QStringLiteral("modified"),
                 fi.lastModified().toString(Qt::ISODate)}});
        }
        return out;
    }

    // Nudge iCloud to upload immediately rather than on its own schedule.
    void publish(const QString& localPath) override
    {
        if (localPath.isEmpty())
            return;
        NSURL* url = [NSURL fileURLWithPath:localPath.toNSString()];
        NSError* err = nil;
        [[NSFileManager defaultManager] startDownloadingUbiquitousItemAtURL:url
                                                                      error:&err];
    }
};

std::unique_ptr<CloudSyncService> CloudSyncService::create(QObject* parent)
{
    return std::make_unique<CloudSyncServiceApple>(parent);
}
