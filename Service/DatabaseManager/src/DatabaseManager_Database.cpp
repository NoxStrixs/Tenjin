#include <DatabaseManager/DatabaseManager.h>
#include <DatabaseManager/Schema.h>

#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>

#include <cmath>

namespace Service {

DatabaseManager::DatabaseManager(const std::string& filepath)
{
    constexpr std::string_view fileExt = ".db";

    if (filepath.length() <= fileExt.length() ||
        filepath.substr(filepath.length() - fileExt.length()) != fileExt) {
        throw std::runtime_error("Invalid database filepath: " + filepath);
    }

    // Unique connection name prevents "duplicate connection" warnings when
    // multiple DatabaseManager instances exist (e.g. tests, iOS app lifecycle).
    const QString connName = QUuid::createUuid().toString();
    QSqlDatabase  db       = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(QString::fromStdString(filepath));

    if (!db.open()) {
        throw std::runtime_error("Failed to open DB: " + db.lastError().text().toStdString());
    }

    m_db = db;

    // Schema creation + forward migrations (PRAGMA user_version driven).
    // Replaces the former inline CREATE/ALTER block; see Schema.{h,cpp}.
    Schema::Migrate(m_db);

    // Assign guids to any rows created before guid columns existed.
    backfillGuids();
}


DatabaseManager::~DatabaseManager()
{
    const QString connName = m_db.connectionName();
    m_db.close();
    m_db = QSqlDatabase(); // release handle before removeDatabase
    QSqlDatabase::removeDatabase(connName);
}


void DatabaseManager::backfillGuids()
{
    const char* tables[] = {"entry", "tag", "deck", "entry_content"};
    for (const char* t : tables) {
        QSqlQuery sel(m_db);
        sel.exec(QStringLiteral("SELECT id FROM %1 WHERE guid IS NULL OR guid = '';").arg(t));
        std::vector<qint64> ids;
        while (sel.next())
            ids.push_back(sel.value(0).toLongLong());
        for (qint64 id : ids) {
            QSqlQuery upd(m_db);
            upd.prepare(
                QStringLiteral("UPDATE %1 SET guid = :g, updated_at = :u WHERE id = :id;").arg(t));
            upd.bindValue(":g", QUuid::createUuid().toString(QUuid::WithoutBraces));
            upd.bindValue(":u", QDateTime::currentMSecsSinceEpoch());
            upd.bindValue(":id", id);
            upd.exec();
        }
    }
}

} // namespace Service
