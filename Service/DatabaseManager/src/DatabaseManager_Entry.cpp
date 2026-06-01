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

Result_t<Word_t> DatabaseManager::AddWord(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO entry (title) VALUES (:title);");
    q.bindValue(":title", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Word_t{.id = q.lastInsertId().toLongLong(), .word = word, .createdAt = {}};
}


Result_t<Word_t> DatabaseManager::GetWord(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at FROM entry WHERE title = :title;");
    q.bindValue(":title", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Word not found: " + std::string(word));

    return Word_t{.id        = q.value(0).toLongLong(),
                  .word      = q.value(1).toString().toStdString(),
                  .createdAt = q.value(2).toString().toStdString()};
}


Result_t<std::vector<Word_t>> DatabaseManager::GetAllWords()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, title, created_at FROM entry ORDER BY title ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}


Result_t<bool> DatabaseManager::DeleteWord(ID_t id)
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

} // namespace Service
