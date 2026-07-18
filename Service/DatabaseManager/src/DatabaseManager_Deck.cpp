#include <algorithm>
#include <utility>
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

Result_t<Deck_t> DatabaseManager::AddDeck(const std::string& name, bool isSmart, FilterMode_t mode,
                                         const std::string& language)
{
    const QString filterMode = (mode == FilterMode_t::And) ? "AND" : "OR";

    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck (name, is_smart, filter_mode, language) "
              "VALUES (:name, :isSmart, :filterMode, :language);");
    q.bindValue(":name", QString::fromStdString(name));
    q.bindValue(":isSmart", isSmart ? 1 : 0);
    q.bindValue(":filterMode", filterMode);
    q.bindValue(":language", QString::fromStdString(language));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    Deck_t d;
    d.id         = q.lastInsertId().toLongLong();
    d.name       = name;
    d.bIsSmart   = isSmart;
    d.filterMode = mode;
    d.language   = language;
    // createdAt and the scheduler/FSRS fields keep their Deck_t defaults; the DB
    // row was just inserted with the schema defaults, so this matches it.
    return d;
}

Result_t<Deck_t> DatabaseManager::GetDeck(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name, is_smart, filter_mode, created_at, new_cards_per_day, scheduler, fsrs_retention, fsrs_weights, language "
              "FROM deck WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("No deck found with id: " + std::to_string(id));

    const bool         isSmart = q.value(2).toInt() != 0;
    const std::string  fmStr   = q.value(3).toString().toStdString();
    const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

    return Deck_t{.id             = q.value(0).toLongLong(),
                  .name           = q.value(1).toString().toStdString(),
                  .bIsSmart       = isSmart,
                  .filterMode     = mode,
                  .createdAt      = q.value(4).toString().toStdString(),
                  .newCardsPerDay = q.value(5).toInt(),
                  .scheduler      = q.value(6).toString().toStdString(),
                  .fsrsRetention  = q.value(7).toDouble(),
                  .fsrsWeights    = q.value(8).toString().toStdString(),
                  .language       = q.value(9).toString().toStdString()};
}

Result_t<std::vector<Deck_t>> DatabaseManager::GetAllDecks()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name, is_smart, filter_mode, created_at, new_cards_per_day, scheduler, fsrs_retention, fsrs_weights, language "
                "FROM deck ORDER BY name ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Deck_t> decks;
    while (q.next()) {
        const bool         isSmart = q.value(2).toInt() != 0;
        const std::string  fmStr   = q.value(3).toString().toStdString();
        const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

        decks.push_back(Deck_t{.id             = q.value(0).toLongLong(),
                               .name           = q.value(1).toString().toStdString(),
                               .bIsSmart       = isSmart,
                               .filterMode     = mode,
                               .createdAt      = q.value(4).toString().toStdString(),
                               .newCardsPerDay = q.value(5).toInt(),
                               .scheduler      = q.value(6).toString().toStdString(),
                               .fsrsRetention  = q.value(7).toDouble(),
                               .fsrsWeights    = q.value(8).toString().toStdString(),
                               .language       = q.value(9).toString().toStdString()});
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

Result_t<bool> DatabaseManager::SetDeckNewCardsPerDay(ID_t id, int perDay)
{
    if (perDay < 0)
        perDay = 0;
    QSqlQuery q(m_db);
    q.prepare("UPDATE deck SET new_cards_per_day = :n WHERE id = :id;");
    q.bindValue(":n", perDay);
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));
    return true;
}

Result_t<bool> DatabaseManager::SetDeckScheduler(ID_t id, const std::string& scheduler,
                                                 double retention)
{
    const std::string sched = (scheduler == "fsrs") ? "fsrs" : "sm2";
    const double ret = std::clamp(retention, 0.70, 0.97);
    QSqlQuery q(m_db);
    q.prepare("UPDATE deck SET scheduler = :s, fsrs_retention = :r WHERE id = :id;");
    q.bindValue(":s", QString::fromStdString(sched));
    q.bindValue(":r", ret);
    q.bindValue(":id", QVariant::fromValue(id));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));
    return true;
}

Result_t<bool> DatabaseManager::SetDeckWeights(ID_t id, const std::string& weightsJson)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE deck SET fsrs_weights = :w WHERE id = :id;");
    q.bindValue(":w", QString::fromStdString(weightsJson));
    q.bindValue(":id", QVariant::fromValue(id));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));
    return true;
}

Result_t<bool> DatabaseManager::SetDeckLanguage(ID_t id, const std::string& language)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE deck SET language = :lang WHERE id = :id;");
    q.bindValue(":lang", QString::fromStdString(language));
    q.bindValue(":id", QVariant::fromValue(id));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));
    return true;
}

Result_t<std::vector<Fsrs::CardHistory>> DatabaseManager::GetReviewSequences(ID_t deckId)
{
    // Pull every logged review for the deck, ordered by card then time, and
    // fold each card's rows into a chronological sequence with elapsed-day gaps.
    QSqlQuery q(m_db);
    q.prepare("SELECT entry_id, quality, reviewed_at FROM review_log "
              "WHERE deck_id = :d ORDER BY entry_id, reviewed_at;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Fsrs::CardHistory> sequences;
    Fsrs::CardHistory              current;
    ID_t                           currentEntry = -1;
    qint64                         prevMs       = 0;

    auto flush = [&]() {
        if (!current.empty())
            sequences.push_back(std::move(current));
        current.clear();
    };

    while (q.next()) {
        const ID_t   entry = q.value(0).toLongLong();
        const int    ui    = q.value(1).toInt();          // 0..3
        const qint64 ms    = q.value(2).toLongLong();

        if (entry != currentEntry) {
            flush();
            currentEntry = entry;
            prevMs       = ms;
        }

        // Elapsed days since this card's previous review (0 for the first).
        double elapsedDays = 0.0;
        if (!current.empty())
            elapsedDays = static_cast<double>(ms - prevMs) / 86400000.0;
        prevMs = ms;

        // UI grade 0..3 (Forgot/Hard/Good/Easy) -> FSRS 1..4.
        const int grade = std::clamp(ui, 0, 3) + 1;
        current.push_back(Fsrs::ReviewEvent{
            .elapsedDays = elapsedDays < 0.0 ? 0.0 : elapsedDays,
            .grade       = grade,
            .passed      = grade >= 2});
    }
    flush();

    return sequences;
}

Result_t<bool> DatabaseManager::AddEntryToDeck(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck_entry (deck_id, entry_id) VALUES (:deckId, :wordId);");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveEntryFromDeck(ID_t deckId, ID_t wordId)
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

Result_t<std::vector<Entry_t>> DatabaseManager::GetEntriesForDeck(ID_t deckId)
{
    auto deck = GetDeck(deckId);
    if (!deck)
        return std::unexpected(deck.error());

    if (!deck->bIsSmart) {
        // Manual deck: read directly from deck_entry junction
        QSqlQuery q(m_db);
        q.prepare("SELECT w.id, w.title, w.created_at, w.language FROM entry w "
                  "JOIN deck_entry dw ON dw.entry_id = w.id "
                  "WHERE dw.deck_id = :deckId "
                  "ORDER BY w.title ASC;");
        q.bindValue(":deckId", QVariant::fromValue(deckId));

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

    // Smart deck: collect tag filters then delegate to getWordsByTags
    auto tags = GetTagFiltersForDeck(deckId);
    if (!tags)
        return std::unexpected(tags.error());

    std::vector<ID_t> tagIds;
    tagIds.reserve(tags->size());
    for (const auto& tag : *tags)
        tagIds.push_back(tag.id);

    return GetEntriesByTags(tagIds, deck->filterMode);
}

Result_t<std::vector<Entry_t>> DatabaseManager::GetEntriesByTags(const std::vector<ID_t>& tagIds,
                                                                 FilterMode_t             mode)
{
    if (tagIds.empty())
        return std::vector<Entry_t>{};

    // Build the IN clause placeholder list
    QStringList placeholders;
    for (size_t i = 0; i < tagIds.size(); i++)
        placeholders << QString(":t%1").arg(i);

    QString sql;
    if (mode == FilterMode_t::And) {
        // Word must have ALL specified tags
        sql = QString("SELECT w.id, w.title, w.created_at, w.language FROM entry w "
                      "JOIN entry_tag wt ON wt.entry_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "GROUP BY w.id "
                      "HAVING COUNT(DISTINCT wt.tag_id) = %2 "
                      "ORDER BY w.title ASC;")
                  .arg(placeholders.join(", "))
                  .arg(tagIds.size());
    } else {
        // Word must have at least one of the specified tags
        sql = QString("SELECT DISTINCT w.id, w.title, w.created_at, w.language FROM entry w "
                      "JOIN entry_tag wt ON wt.entry_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "ORDER BY w.title ASC;")
                  .arg(placeholders.join(", "));
    }

    QSqlQuery q(m_db);
    q.prepare(sql);
    for (size_t i = 0; i < tagIds.size(); i++)
        q.bindValue(QString(":t%1").arg(i), QVariant::fromValue(tagIds[i]));

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

// Lists smart decks that filter on the given tag. Drives the "deleting
// this tag will affect these decks" confirmation popup. Only smart
// decks are returned — manual decks aren't filtered by tags so they're
// unaffected by tag deletes.
Result_t<std::vector<Deck_t>> DatabaseManager::GetSmartDecksUsingTag(ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT DISTINCT d.id, d.name, d.is_smart, d.filter_mode, d.created_at, d.language "
              "FROM deck d "
              "JOIN deck_tag_filter f ON f.deck_id = d.id "
              "WHERE f.tag_id = :tag AND d.is_smart = 1 "
              "ORDER BY d.name;");
    q.bindValue(":tag", QVariant::fromValue(tagId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Deck_t> out;
    while (q.next()) {
        Deck_t d;
        // Only these columns are SELECTed; the rest keep their Deck_t defaults
        // (assigning by name avoids both the missing-initializer warning and
        // duplicating the struct's default values here).
        d.id         = q.value(0).toLongLong();
        d.name       = q.value(1).toString().toStdString();
        d.bIsSmart   = q.value(2).toBool();
        d.filterMode = q.value(3).toString() == "OR" ? FilterMode_t::Or : FilterMode_t::And;
        d.createdAt  = q.value(4).toString().toStdString();
        d.language   = q.value(5).toString().toStdString();
        out.push_back(std::move(d));
    }
    return out;
}

} // namespace Service
