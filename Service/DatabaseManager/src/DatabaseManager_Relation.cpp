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

Result_t<WordRelation_t>
DatabaseManager::AddWordRelation(ID_t wordId, ID_t relatedId, const std::string& type)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO entry_relation (entry_id, related_entry_id, relation_type) "
              "VALUES (:wordId, :relatedId, :type);");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":relatedId", QVariant::fromValue(relatedId));
    q.bindValue(":type", QString::fromStdString(type));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return WordRelation_t{.id             = q.lastInsertId().toLongLong(),
                          .wordId         = wordId,
                          .wordRelationId = relatedId,
                          .relationType   = type};
}


Result_t<bool> DatabaseManager::RemoveWordRelation(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM entry_relation WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word relation found with id: " + std::to_string(id));

    return true;
}


Result_t<std::vector<WordRelation_t>> DatabaseManager::GetRelationsForWord(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, entry_id, related_entry_id, relation_type "
              "FROM entry_relation WHERE entry_id = :wordId;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<WordRelation_t> relations;
    while (q.next()) {
        relations.push_back(WordRelation_t{.id             = q.value(0).toLongLong(),
                                           .wordId         = q.value(1).toLongLong(),
                                           .wordRelationId = q.value(2).toLongLong(),
                                           .relationType   = q.value(3).toString().toStdString()});
    }
    return relations;
}

} // namespace Service
