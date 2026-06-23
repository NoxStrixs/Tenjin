#include <ViewModels/CloudService.h>

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTextStream>

#include <TenjinConfig.h>

CloudService::CloudService(QObject* parent)
    : QObject(parent)
    , m_baseUrl(QString::fromUtf8(Tenjin::Config::kCloudUrl))
{
    m_nam.setTransferTimeout(20000);
}

void CloudService::setSyncBusy(bool v)
{
    if (m_syncBusy == v) return;
    m_syncBusy = v;
    emit syncBusyChanged();
}

void CloudService::fetchNews()
{
    if (!available()) return;

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/api/v1/news")));
    req.setRawHeader("X-App-Version", Tenjin::Config::kAppVersion);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);

    auto* reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit networkError(reply->errorString());
            return;
        }
        const auto doc = QJsonDocument::fromJson(reply->readAll());
        if (!doc.isArray()) {
            emit networkError(QStringLiteral("News response is not a JSON array."));
            return;
        }
        QVariantList items;
        for (const QJsonValue& v : doc.array())
            items.append(v.toObject().toVariantMap());
        emit newsReceived(items);
    });
}

void CloudService::postReport(const QVariantMap& details, const QStringList& logSnapshot)
{
    if (!available()) return;

    QNetworkRequest req(QUrl(m_baseUrl + QStringLiteral("/api/v1/report")));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("X-App-Version", Tenjin::Config::kAppVersion);

    auto* reply = m_nam.post(req, buildReportPayload(details, logSnapshot));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit networkError(reply->errorString());
            return;
        }
        emit reportSubmitted();
    });
}

void CloudService::syncDecks(const QString& /*authToken*/)
{
    emit syncResult(QStringLiteral("coming_soon"),
                    QStringLiteral("Deck sync is not yet available. Stay tuned for updates."));
}

QString CloudService::readFatalLog() const
{
    const QString path =
        QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
        + QStringLiteral("/fatal.log");
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    // Read the last 8 KB — enough to capture recent crashes without bloating the payload.
    constexpr qint64 kMaxBytes = 8192;
    const qint64 size = f.size();
    if (size > kMaxBytes)
        f.seek(size - kMaxBytes);
    return QString::fromUtf8(f.readAll());
}

QByteArray CloudService::buildReportPayload(const QVariantMap& details,
                                            const QStringList& logSnapshot) const
{
    QJsonObject obj;

    // Caller-supplied fields (type, description, etc.)
    for (auto it = details.cbegin(); it != details.cend(); ++it)
        obj.insert(it.key(), QJsonValue::fromVariant(it.value()));

    // Device context
    if (!obj.contains(QStringLiteral("appVersion")))
        obj[QStringLiteral("appVersion")] = QString::fromUtf8(Tenjin::Config::kAppVersion);
    if (!obj.contains(QStringLiteral("platform")))
        obj[QStringLiteral("platform")]   = QSysInfo::prettyProductName();
    if (!obj.contains(QStringLiteral("arch")))
        obj[QStringLiteral("arch")]       = QSysInfo::currentCpuArchitecture();
    if (!obj.contains(QStringLiteral("kernelVersion")))
        obj[QStringLiteral("kernelVersion")] = QSysInfo::kernelVersion();

    // In-process log lines captured from the QML log model (most recent first in the UI,
    // but we reverse so the payload reads chronologically top-to-bottom).
    if (!logSnapshot.isEmpty()) {
        QJsonArray logArr;
        for (const QString& line : logSnapshot)
            logArr.append(line);
        obj[QStringLiteral("appLog")] = logArr;
    }

    // Fatal log from disk — captures crashes from the previous session.
    const QString fatalLog = readFatalLog();
    if (!fatalLog.isEmpty())
        obj[QStringLiteral("fatalLog")] = fatalLog;

    return QJsonDocument(obj).toJson(QJsonDocument::Compact);
}
