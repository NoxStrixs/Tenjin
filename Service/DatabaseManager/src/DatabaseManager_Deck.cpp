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

Result_t<Deck_t> DatabaseManager::AddDeck(const std::string& name, bool isSmart, FilterMode_t mode)
{
    const QString filterMode = (mode == FilterMode_t::And) ? "AND" : "OR";

    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck (name, is_smart, filter_mode) "
              "VALUES (:name, :isSmart, :filterMode);");
    q.bindValue(":name", QString::fromStdString(name));
    q.bindValue(":isSmart", isSmart ? 1 : 0);
    q.bindValue(":filterMode", filterMode);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Deck_t{.id         = q.lastInsertId().toLongLong(),
                  .name       = name,
                  .bIsSmart   = isSmart,
                  .filterMode = mode,
                  .createdAt  = {}};
}

Result_t<Deck_t> DatabaseManager::GetDeck(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name, is_smart, filter_mode, created_at FROM deck WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("No deck found with id: " + std::to_string(id));

    const bool         isSmart = q.value(2).toInt() != 0;
    const std::string  fmStr   = q.value(3).toString().toStdString();
    const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

    return Deck_t{.id         = q.value(0).toLongLong(),
                  .name       = q.value(1).toString().toStdString(),
                  .bIsSmart   = isSmart,
                  .filterMode = mode,
                  .createdAt  = q.value(4).toString().toStdString()};
}

Result_t<std::vector<Deck_t>> DatabaseManager::GetAllDecks()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name, is_smart, filter_mode, created_at FROM deck ORDER BY name ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Deck_t> decks;
    while (q.next()) {
        const bool         isSmart = q.value(2).toInt() != 0;
        const std::string  fmStr   = q.value(3).toString().toStdString();
        const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

        decks.push_back(Deck_t{.id         = q.value(0).toLongLong(),
                               .name       = q.value(1).toString().toStdString(),
                               .bIsSmart   = isSmart,
                               .filterMode = mode,
                               .createdAt  = q.value(4).toString().toStdString()});
    }
    return decks;
}

Result_t<bool> DatabaseManager::DeleteDeck(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));

    return true;
}

Result_t<bool> DatabaseManager::AddWordToDeck(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck_entry (deck_id, entry_id) VALUES (:deckId, :wordId);");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveWordFromDeck(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck_entry WHERE deck_id = :deckId AND entry_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck-word association found.");

    return true;
}

Result_t<bool> DatabaseManager::AddTagFilterToDeck(ID_t deckId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck_tag_filter (deck_id, tag_id) VALUES (:deckId, :tagId);");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveTagFilterFromDeck(ID_t deckId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck_tag_filter WHERE deck_id = :deckId AND tag_id = :tagId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck-tag filter found.");

    return true;
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetTagFiltersForDeck(ID_t deckId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT t.id, t.name FROM tag t "
              "JOIN deck_tag_filter dtf ON dtf.tag_id = t.id "
              "WHERE dtf.deck_id = :deckId "
              "ORDER BY t.name ASC;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<std::vector<Word_t>> DatabaseManager::GetWordsForDeck(ID_t deckId)
{
    auto deck = GetDeck(deckId);
    if (!deck)
        return std::unexpected(deck.error());

    if (!deck->bIsSmart) {
        // Manual deck — read directly from deck_word junction
        QSqlQuery q(m_db);
        q.prepare("SELECT w.id, w.title, w.created_at FROM entry w "
                  "JOIN deck_entry dw ON dw.entry_id = w.id "
                  "WHERE dw.deck_id = :deckId "
                  "ORDER BY w.title ASC;");
        q.bindValue(":deckId", QVariant::fromValue(deckId));

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

    // Smart deck — collect tag filters then delegate to getWordsByTags
    auto tags = GetTagFiltersForDeck(deckId);
    if (!tags)
        return std::unexpected(tags.error());

    std::vector<ID_t> tagIds;
    tagIds.reserve(tags->size());
    for (const auto& tag : *tags)
        tagIds.push_back(tag.id);

    return GetWordsByTags(tagIds, deck->filterMode);
}

Result_t<std::vector<Word_t>> DatabaseManager::GetWordsByTags(const std::vector<ID_t>& tagIds,
                                                              FilterMode_t             mode)
{
    if (tagIds.empty())
        return std::vector<Word_t>{};

    // Build the IN clause placeholder list: (:t0, :t1, :t2 ...)
    QStringList placeholders;
    for (size_t i = 0; i < tagIds.size(); ++i)
        placeholders << QString(":t%1").arg(i);

    QString sql;
    if (mode == FilterMode_t::And) {
        // Relational division — word must have ALL specified tags
        sql = QString("SELECT w.id, w.title, w.created_at FROM entry w "
                      "JOIN entry_tag wt ON wt.entry_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "GROUP BY w.id "
                      "HAVING COUNT(DISTINCT wt.tag_id) = %2 "
                      "ORDER BY w.title ASC;")
                  .arg(placeholders.join(", "))
                  .arg(tagIds.size());
    } else {
        // OR — word must have at least one of the specified tags
        sql = QString("SELECT DISTINCT w.id, w.title, w.created_at FROM entry w "
                      "JOIN entry_tag wt ON wt.entry_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "ORDER BY w.title ASC;")
                  .arg(placeholders.join(", "));
    }

    QSqlQuery q(m_db);
    q.prepare(sql);
    for (size_t i = 0; i < tagIds.size(); ++i)
        q.bindValue(QString(":t%1").arg(i), QVariant::fromValue(tagIds[i]));

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

// ── Import / Export ─────────────────────────────────────────────────────────

} // namespace Service
