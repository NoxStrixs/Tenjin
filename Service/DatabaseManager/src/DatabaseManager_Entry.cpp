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

Result_t<Entry_t> DatabaseManager::AddEntry(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO entry (title) VALUES (:title);");
    q.bindValue(":title", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Entry_t{
        .id = q.lastInsertId().toLongLong(), .word = word, .createdAt = {}, .language = {}};
}

Result_t<Entry_t> DatabaseManager::GetEntry(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at, language FROM entry WHERE title = :title;");
    q.bindValue(":title", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Word not found: " + std::string(word));

    return Entry_t{.id        = q.value(0).toLongLong(),
                   .word      = q.value(1).toString().toStdString(),
                   .createdAt = q.value(2).toString().toStdString(),
                   .language  = q.value(3).toString().toStdString()};
}

Result_t<Entry_t> DatabaseManager::GetEntryById(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at, language FROM entry WHERE id = :id;");
    q.bindValue(":id", static_cast<qlonglong>(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Word not found with id: " + std::to_string(id));

    return Entry_t{.id        = q.value(0).toLongLong(),
                   .word      = q.value(1).toString().toStdString(),
                   .createdAt = q.value(2).toString().toStdString(),
                   .language  = q.value(3).toString().toStdString()};
}

Result_t<std::vector<Entry_t>> DatabaseManager::GetAllEntries()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, title, created_at, language FROM entry ORDER BY title ASC;"))
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

Result_t<bool> DatabaseManager::DeleteEntry(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM entry WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word found with id: " + std::to_string(id));

    return true;
}

// ── Bulk deletes — back the Settings danger zone ────────────────────
// FK cascade rules in the schema (ON DELETE CASCADE on entry_tag,
// entry_relation, content, deck_entry, smart_deck_member) clean up
// dependent rows automatically once the parent row is gone.

Result_t<int> DatabaseManager::DeleteAllEntries()
{
    QSqlQuery q(m_db);
    if (!q.exec("DELETE FROM entry;"))
        return std::unexpected(q.lastError().text().toStdString());
    return q.numRowsAffected();
}

Result_t<bool> DatabaseManager::RenameEntry(ID_t id, const std::string& newName)
{
    if (newName.empty())
        return std::unexpected("Entry name cannot be empty.");
    QSqlQuery q(m_db);
    q.prepare("UPDATE entry SET title = :title WHERE id = :id;");
    q.bindValue(":title", QString::fromStdString(newName));
    q.bindValue(":id", QVariant::fromValue(id));
    if (!q.exec()) {
        // UNIQUE constraint failure surfaces here when the new name
        // collides with an existing entry. Forward the message verbatim
        // so the UI can show "An entry with that name already exists".
        return std::unexpected(q.lastError().text().toStdString());
    }
    if (q.numRowsAffected() == 0)
        return std::unexpected("No entry with id: " + std::to_string(id));
    return true;
}

Result_t<int> DatabaseManager::DeleteAllTags()
{
    QSqlQuery q(m_db);
    if (!q.exec("DELETE FROM tag;"))
        return std::unexpected(q.lastError().text().toStdString());
    return q.numRowsAffected();
}

Result_t<int> DatabaseManager::DeleteAllDecks()
{
    QSqlQuery q(m_db);
    if (!q.exec("DELETE FROM deck;"))
        return std::unexpected(q.lastError().text().toStdString());
    return q.numRowsAffected();
}

// ── kV2 multi-language ─────────────────────────────────────────────

Result_t<bool> DatabaseManager::SetEntryLanguage(ID_t id, const std::string& code)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE entry SET language = :lang WHERE id = :id;");
    q.bindValue(":lang", QString::fromStdString(code));
    q.bindValue(":id", QVariant::fromValue(id));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    if (q.numRowsAffected() == 0)
        return std::unexpected("No entry with id: " + std::to_string(id));
    return true;
}

Result_t<std::vector<std::string>> DatabaseManager::GetAllLanguages()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT DISTINCT language FROM entry WHERE language != '' ORDER BY language;"))
        return std::unexpected(q.lastError().text().toStdString());
    std::vector<std::string> out;
    while (q.next())
        out.push_back(q.value(0).toString().toStdString());
    return out;
}

} // namespace Service
