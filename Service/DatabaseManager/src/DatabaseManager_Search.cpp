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

Result_t<std::vector<Word_t>> DatabaseManager::SearchWords(const std::string& query)
{
    // Append * for prefix matching so partial input works (e.g. "ephe" matches "ephemeral")
    const QString ftsQuery = QString::fromStdString(query) + "*";

    QSqlQuery q(m_db);
    q.prepare("SELECT DISTINCT w.id, w.title, w.created_at FROM entry w "
              "JOIN entry_content_fts fts ON fts.rowid = (SELECT id FROM entry_content WHERE entry_id "
              "= w.id LIMIT 1) "
              "WHERE entry_content_fts MATCH :query "
              "ORDER BY w.title ASC;");
    q.bindValue(":query", ftsQuery);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}


Result_t<std::vector<ContentBlock_t>> DatabaseManager::SearchContent(const std::string& query)
{
    const QString ftsQuery = QString::fromStdString(query) + "*";

    QSqlQuery q(m_db);
    q.prepare(
        "SELECT wc.id, wc.entry_id, wc.type, wc.content, wc.row, wc.col, wc.row_span, wc.col_span "
        "FROM entry_content wc "
        "JOIN entry_content_fts fts ON fts.rowid = wc.id "
        "WHERE entry_content_fts MATCH :query;");
    q.bindValue(":query", ftsQuery);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<ContentBlock_t> blocks;
    while (q.next()) {
        blocks.push_back(ContentBlock_t{.id      = q.value(0).toLongLong(),
                                        .wordId  = q.value(1).toLongLong(),
                                        .type    = static_cast<ContentType_t>(q.value(2).toInt()),
                                        .content = q.value(3).toString().toStdString(),
                                        .row     = q.value(4).toInt(),
                                        .col     = q.value(5).toInt(),
                                        .rowSpan = q.value(6).toInt(),
                                        .colSpan = q.value(7).toInt()});
    }
    return blocks;
}

// ── Substring search (LIKE) ───────────────────────────────────────────────────


Result_t<std::vector<Word_t>> DatabaseManager::SearchWordsByName(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, title, created_at FROM entry "
              "WHERE title LIKE :pat ESCAPE '\\' "
              "ORDER BY title ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}


Result_t<std::vector<Tag_t>> DatabaseManager::SearchTagsByName(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name FROM tag "
              "WHERE name LIKE :pat ESCAPE '\\' "
              "ORDER BY name ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}


Result_t<std::vector<Word_t>> DatabaseManager::SearchWordsByContent(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT DISTINCT w.id, w.title, w.created_at FROM entry w "
              "JOIN entry_content wc ON wc.entry_id = w.id "
              "WHERE wc.content LIKE :pat ESCAPE '\\' "
              "ORDER BY w.title ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

} // namespace Service
