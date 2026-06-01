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

Result_t<Review_t> DatabaseManager::InitReview(ID_t deckId, ID_t wordId)
{
    // INSERT OR IGNORE — safe to call multiple times, won't overwrite existing progress
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO review (deck_id, entry_id, next_review_date) "
              "VALUES (:deckId, :wordId, date('now', 'localtime'));");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    // Fetch the row whether it was just inserted or already existed
    q.prepare("SELECT id, deck_id, entry_id, ease_factor, interval_days, repetitions, "
              "next_review_date, last_review_date "
              "FROM review WHERE deck_id = :deckId AND entry_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec() || !q.next())
        return std::unexpected(q.lastError().text().toStdString());

    return Review_t{.id             = q.value(0).toLongLong(),
                    .deckId         = q.value(1).toLongLong(),
                    .wordId         = q.value(2).toLongLong(),
                    .easeFactor     = q.value(3).toFloat(),
                    .intervalDays   = static_cast<uint16_t>(q.value(4).toInt()),
                    .repetitions    = static_cast<uint16_t>(q.value(5).toInt()),
                    .nextReviewDate = q.value(6).toString().toStdString(),
                    .lastReviewDate = q.value(7).toString().toStdString()};
}


Result_t<Review_t> DatabaseManager::SubmitReview(ID_t deckId, ID_t wordId, int quality)
{
    // Fetch current state
    QSqlQuery q(m_db);
    q.prepare("SELECT id, ease_factor, interval_days, repetitions "
              "FROM review WHERE deck_id = :deckId AND entry_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec() || !q.next())
        return std::unexpected("Review not found. Call initReview first.");

    const ID_t reviewId     = q.value(0).toLongLong();
    float      easeFactor   = q.value(1).toFloat();
    int        intervalDays = q.value(2).toInt();
    int        repetitions  = q.value(3).toInt();

    // SM-2 algorithm
    if (quality >= 3) {
        if (repetitions == 0)
            intervalDays = 1;
        else if (repetitions == 1)
            intervalDays = 6;
        else
            intervalDays = static_cast<int>(std::round(intervalDays * easeFactor));

        easeFactor += 0.1f - (5 - quality) * (0.08f + (5 - quality) * 0.02f);
        easeFactor = std::max(1.3f, easeFactor);
        repetitions++;
    } else {
        // Failed — reset streak, keep ease factor
        repetitions  = 0;
        intervalDays = 1;
    }

    const QString today    = QDate::currentDate().toString("yyyy-MM-dd");
    const QString nextDate = QDate::currentDate().addDays(intervalDays).toString("yyyy-MM-dd");

    q.prepare(
        "UPDATE review SET ease_factor = :ef, interval_days = :interval, repetitions = :reps, "
        "next_review_date = :nextDate, last_review_date = :lastDate "
        "WHERE deck_id = :deckId AND entry_id = :wordId;");
    q.bindValue(":ef", easeFactor);
    q.bindValue(":interval", intervalDays);
    q.bindValue(":reps", repetitions);
    q.bindValue(":nextDate", nextDate);
    q.bindValue(":lastDate", today);
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    // Append to the review history log (analytics). Non-fatal if it fails.
    {
        QSqlQuery log(m_db);
        log.prepare("INSERT INTO review_log "
                    "(deck_id, entry_id, quality, ease_factor, interval_days, reviewed_at) "
                    "VALUES (:d, :w, :q, :ef, :iv, :ts);");
        log.bindValue(":d", QVariant::fromValue(deckId));
        log.bindValue(":w", QVariant::fromValue(wordId));
        log.bindValue(":q", quality);
        log.bindValue(":ef", easeFactor);
        log.bindValue(":iv", intervalDays);
        log.bindValue(":ts", QDateTime::currentMSecsSinceEpoch());
        log.exec();
    }

    return Review_t{.id             = reviewId,
                    .deckId         = deckId,
                    .wordId         = wordId,
                    .easeFactor     = easeFactor,
                    .intervalDays   = static_cast<uint16_t>(intervalDays),
                    .repetitions    = static_cast<uint16_t>(repetitions),
                    .nextReviewDate = nextDate.toStdString(),
                    .lastReviewDate = today.toStdString()};
}


Result_t<std::vector<Review_t>> DatabaseManager::GetDueReviews(ID_t deckId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, deck_id, entry_id, ease_factor, interval_days, repetitions, "
              "next_review_date, last_review_date "
              "FROM review WHERE deck_id = :deckId AND next_review_date <= date('now', 'localtime') "
              "ORDER BY next_review_date ASC;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Review_t> reviews;
    while (q.next()) {
        reviews.push_back(Review_t{.id             = q.value(0).toLongLong(),
                                   .deckId         = q.value(1).toLongLong(),
                                   .wordId         = q.value(2).toLongLong(),
                                   .easeFactor     = q.value(3).toFloat(),
                                   .intervalDays   = static_cast<uint16_t>(q.value(4).toInt()),
                                   .repetitions    = static_cast<uint16_t>(q.value(5).toInt()),
                                   .nextReviewDate = q.value(6).toString().toStdString(),
                                   .lastReviewDate = q.value(7).toString().toStdString()});
    }
    return reviews;
}


Result_t<DeckStats_t> DatabaseManager::GetDeckStats(ID_t deckId)
{
    DeckStats_t stats;

    auto words = GetWordsForDeck(deckId);
    if (!words)
        return std::unexpected(words.error());
    stats.total = static_cast<int>(words->size());
    if (stats.total == 0)
        return stats;

    QSqlQuery q(m_db);
    q.prepare("SELECT entry_id, next_review_date FROM review WHERE deck_id = :d;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    QHash<qint64, QString> nextByWord;
    while (q.next())
        nextByWord.insert(q.value(0).toLongLong(), q.value(1).toString());

    const QString today = QDate::currentDate().toString("yyyy-MM-dd");
    QString       earliestUpcoming;

    for (const auto& w : *words) {
        const auto it = nextByWord.find(static_cast<qint64>(w.id));
        if (it == nextByWord.end()) {
            ++stats.due; // never reviewed → new card, due
            continue;
        }
        const QString next = it.value();
        if (next.isEmpty() || next <= today) {
            ++stats.due;
        } else if (earliestUpcoming.isEmpty() || next < earliestUpcoming) {
            earliestUpcoming = next;
        }
    }
    stats.nextDue = earliestUpcoming.toStdString();
    return stats;
}


Result_t<DeckAnalytics_t> DatabaseManager::GetDeckAnalytics(ID_t deckId)
{
    DeckAnalytics_t a;

    // Daily aggregates: count + average grade per day, chronological.
    // reviewed_at is epoch ms; convert to a local date string in SQL via SQLite's
    // datetime on (ms/1000) seconds.
    QSqlQuery q(m_db);
    q.prepare("SELECT date(reviewed_at/1000, 'unixepoch', 'localtime') AS d, "
              "COUNT(*) AS c, AVG(quality) AS aq "
              "FROM review_log WHERE deck_id = :d "
              "GROUP BY d ORDER BY d ASC;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    while (q.next()) {
        a.daily.push_back(DailyStat_t{
            q.value(0).toString().toStdString(), q.value(1).toInt(), q.value(2).toDouble()});
        a.totalReviews += q.value(1).toInt();
    }

    // Retention: fraction of all grades that were "remembered" (quality >= 2).
    QSqlQuery rq(m_db);
    rq.prepare("SELECT "
               "SUM(CASE WHEN quality >= 2 THEN 1 ELSE 0 END) AS good, COUNT(*) AS total "
               "FROM review_log WHERE deck_id = :d;");
    rq.bindValue(":d", QVariant::fromValue(deckId));
    if (rq.exec() && rq.next()) {
        const int total = rq.value(1).toInt();
        a.retention     = (total > 0) ? rq.value(0).toDouble() / total : 0.0;
    }
    return a;
}


Result_t<std::vector<WordReviewEvent_t>> DatabaseManager::GetWordHistory(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT reviewed_at, quality, ease_factor, interval_days "
              "FROM review_log WHERE deck_id = :d AND entry_id = :w "
              "ORDER BY reviewed_at ASC;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    q.bindValue(":w", QVariant::fromValue(wordId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<WordReviewEvent_t> events;
    while (q.next()) {
        events.push_back(WordReviewEvent_t{q.value(0).toLongLong(),
                                           q.value(1).toInt(),
                                           q.value(2).toDouble(),
                                           q.value(3).toInt()});
    }
    return events;
}

} // namespace Service
