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

Result_t<ContentBlock_t> DatabaseManager::AddContentBlock(const ContentBlock_t& block)
{
    QSqlQuery q(m_db);
    q.prepare(
        "INSERT INTO entry_content (entry_id, type, kind, content, row, col, row_span, col_span, pos) "
        "VALUES (:wordId, :type, :kind, :content, :row, :col, :rowSpan, :colSpan, :pos);");
    q.bindValue(":wordId", QVariant::fromValue(block.wordId));
    q.bindValue(":type", static_cast<int>(block.type));
    q.bindValue(":kind", QString::fromStdString(ToKindString(block.type)));
    q.bindValue(":content", QString::fromStdString(block.content));
    q.bindValue(":row", block.row);
    q.bindValue(":col", block.col);
    q.bindValue(":rowSpan", block.rowSpan);
    q.bindValue(":colSpan", block.colSpan);
    q.bindValue(":pos", QString::fromStdString(block.pos));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return ContentBlock_t{.id      = q.lastInsertId().toLongLong(),
                          .wordId  = block.wordId,
                          .type    = block.type,
                          .content = block.content,
                          .row     = block.row,
                          .col     = block.col,
                          .rowSpan = block.rowSpan,
                          .colSpan = block.colSpan,
                          .pos     = block.pos};
}


Result_t<ContentBlock_t> DatabaseManager::UpdateContentBlock(const ContentBlock_t& block)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE entry_content SET type = :type, kind = :kind, content = :content, row = :row, col = :col, "
              "row_span = :rowSpan, col_span = :colSpan, pos = :pos WHERE id = :id;");
    q.bindValue(":type", static_cast<int>(block.type));
    q.bindValue(":kind", QString::fromStdString(ToKindString(block.type)));
    q.bindValue(":content", QString::fromStdString(block.content));
    q.bindValue(":row", block.row);
    q.bindValue(":col", block.col);
    q.bindValue(":rowSpan", block.rowSpan);
    q.bindValue(":colSpan", block.colSpan);
    q.bindValue(":pos", QString::fromStdString(block.pos));
    q.bindValue(":id", QVariant::fromValue(block.id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No content block found with id: " + std::to_string(block.id));

    return block;
}


Result_t<bool> DatabaseManager::DeleteContentBlock(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM entry_content WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No content block found with id: " + std::to_string(id));

    return true;
}


Result_t<std::vector<ContentBlock_t>> DatabaseManager::GetContentForWord(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, entry_id, type, content, row, col, row_span, col_span, pos "
              "FROM entry_content WHERE entry_id = :wordId "
              "ORDER BY row ASC, col ASC;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

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
                                        .colSpan = q.value(7).toInt(),
                                        .pos     = q.value(8).toString().toStdString()});
    }
    return blocks;
}


Result_t<bool> DatabaseManager::SaveContentLayout(const std::vector<ContentBlock_t>& blocks)
{
    // Transaction — all blocks update atomically or none do
    if (!m_db.transaction())
        return std::unexpected("Failed to begin transaction.");

    QSqlQuery q(m_db);
    // Persist type and content as well as layout. Previously only the
    // row/col/span columns were written, so staged text edits made in edit
    // mode were never saved — blocks survived but their content did not.
    q.prepare("UPDATE entry_content SET type = :type, kind = :kind, content = :content, pos = :pos, "
              "row = :row, col = :col, row_span = :rowSpan, col_span = :colSpan "
              "WHERE id = :id;");

    for (const auto& block : blocks) {
        q.bindValue(":type", static_cast<int>(block.type));
        q.bindValue(":kind", QString::fromStdString(ToKindString(block.type)));
        q.bindValue(":content", QString::fromStdString(block.content));
        q.bindValue(":pos", QString::fromStdString(block.pos));
        q.bindValue(":row", block.row);
        q.bindValue(":col", block.col);
        q.bindValue(":rowSpan", block.rowSpan);
        q.bindValue(":colSpan", block.colSpan);
        q.bindValue(":id", QVariant::fromValue(block.id));

        if (!q.exec()) {
            m_db.rollback();
            return std::unexpected(q.lastError().text().toStdString());
        }
    }

    if (!m_db.commit()) {
        m_db.rollback();
        return std::unexpected("Failed to commit layout transaction.");
    }

    return true;
}

} // namespace Service
