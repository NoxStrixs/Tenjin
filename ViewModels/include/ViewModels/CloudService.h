#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <memory>

// CloudService — unified endpoint client for all cloud features.
//
// Endpoint layout (base URL from TENJIN_CLOUD_URL in .env):
//   GET  /api/v1/news          news feed JSON array
//   POST /api/v1/report        bug/crash report + optional log attachment
//   POST /api/v1/sync          deck sync (subscription feature, stubbed)
//
// When baseUrl is empty all operations are silent no-ops. QML affordances
// check the `available` property to show/hide cloud-dependent UI.
class CloudService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    Q_PROPERTY(bool syncBusy READ syncBusy NOTIFY syncBusyChanged)

public:
    explicit CloudService(QObject* parent = nullptr);

    // Compile-time factory seat. No platform variance yet (single default
    // impl); a future native cloud backend slots in here without touching
    // callers. Returns the base by value-of-unique_ptr.
    static std::unique_ptr<CloudService> create(QObject* parent = nullptr);

    bool available() const
    {
        return !m_baseUrl.isEmpty();
    }
    bool syncBusy() const
    {
        return m_syncBusy;
    }

    // Children's-privacy gate. Driven by AppViewModel from the age/consent
    // state. When false, any call that would transmit data off-device is
    // suppressed (fail-closed). This is the COPPA control point: an under-13
    // user without verifiable parental consent performs no data collection.
    void setDataCollectionAllowed(bool allowed);
    bool dataCollectionAllowed() const
    {
        return m_dataCollectionAllowed;
    }

    // Fetch the news feed. Emits newsReceived or networkError.
    Q_INVOKABLE void fetchNews();

    // Post a report. `details` map fields:
    //   type        "bug" | "crash"
    //   description User-supplied text
    //
    // This method automatically collects and attaches:
    //   - In-process Qt log lines from LogViewModel (passed via logSnapshot)
    //   - Contents of fatal.log from the app data directory
    //   - App version, platform, CPU arch
    //
    // logSnapshot: pass logModel.snapshot() (QStringList of recent log lines)
    // so the C++ layer doesn't need a direct pointer to LogViewModel.
    Q_INVOKABLE void postReport(const QVariantMap& details, const QStringList& logSnapshot = {});

    // Stub — emits syncResult("coming_soon", ...) immediately.
    Q_INVOKABLE void syncDecks(const QString& authToken = QString());

signals:
    void availableChanged();
    void syncBusyChanged();
    void newsReceived(const QVariantList& items);
    void reportSubmitted();
    void syncResult(const QString& status, const QString& message);
    void networkError(const QString& message);

private:
    void       setSyncBusy(bool v);
    QString    readFatalLog() const;
    QByteArray buildReportPayload(const QVariantMap& details, const QStringList& logSnapshot) const;

    QString               m_baseUrl;
    QNetworkAccessManager m_nam;
    bool                  m_syncBusy = false;
    // Fail-closed: no data collection until consent state explicitly allows it.
    bool m_dataCollectionAllowed = false;
};
