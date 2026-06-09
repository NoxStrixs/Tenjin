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

Result_t<Tag_t> DatabaseManager::AddTag(const std::string& name)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO tag (name) VALUES (:name);");
    q.bindValue(":name", QString::fromStdString(name));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Tag_t{.id = q.lastInsertId().toLongLong(), .name = name};
}

Result_t<Tag_t> DatabaseManager::GetTag(std::string_view name)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name FROM tag WHERE name = :name;");
    q.bindValue(":name", QString::fromStdString(std::string(name)));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Tag not found: " + std::string(name));

    return Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()};
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetAllTags()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name FROM tag ORDER BY name ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<bool> DatabaseManager::DeleteTag(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tag WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No tag found with id: " + std::to_string(id));

    return true;
}

Result_t<bool> DatabaseManager::RenameTag(ID_t id, const std::string& name)
{
    // Bumps updated_at so the rename wins during timestamp-based merge import.
    QSqlQuery q(m_db);
    q.prepare("UPDATE tag SET name = :name, updated_at = :u WHERE id = :id;");
    q.bindValue(":name", QString::fromStdString(name));
    q.bindValue(":u", QDateTime::currentMSecsSinceEpoch());
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No tag found with id: " + std::to_string(id));

    return true;
}

Result_t<bool> DatabaseManager::AddTagToEntry(ID_t wordId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO entry_tag (entry_id, tag_id) VALUES (:wordId, :tagId);");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveTagFromEntry(ID_t wordId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM entry_tag WHERE entry_id = :wordId AND tag_id = :tagId;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word-tag association found.");

    return true;
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetTagsForEntry(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT t.id, t.name FROM tag t "
              "JOIN entry_tag wt ON wt.tag_id = t.id "
              "WHERE wt.entry_id = :wordId "
              "ORDER BY t.name ASC;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<std::vector<Entry_t>> DatabaseManager::GetEntriesForTag(ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT w.id, w.title, w.created_at, w.language FROM entry w "
              "JOIN entry_tag wt ON wt.entry_id = w.id "
              "WHERE wt.tag_id = :tagId "
              "ORDER BY w.title ASC;");
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Entry_t> words;
    while (q.next()) {
        words.push_back(Entry_t{.id        = q.value(0).toLongLong(),
                                .word      = q.value(1).toString().toStdString(),
                                .createdAt = q.value(2).toString().toStdString(),
                                .language  = q.value(3).toString().toStdString()});
    }
    return words;
}

} // namespace Service
