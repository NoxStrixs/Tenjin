#include <DatabaseManager/DatabaseManager.h>
#include <DatabaseManager/Schema.h>
#include <QRegularExpression>
#include <set>

#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>

#include <algorithm>
#include <cmath>

namespace Service {

namespace {
// Extract distinct cloze numbers ({{cN::...}}) from an entry's cloze blocks,
// sorted ascending. Empty => the entry has no cloze deletions.
std::vector<int> clozeOrdinalsFromBlocks(const std::vector<ContentBlock_t>& blocks)
{
    static const QRegularExpression re(QStringLiteral("\\{\\{c(\\d+)::"));
    std::set<int>                   found;
    for (const auto& b : blocks) {
        if (b.type != ContentType_t::Cloze)
            continue;
        const QString text = QString::fromStdString(b.content);
        auto          it   = re.globalMatch(text);
        while (it.hasNext()) {
            const int n = it.next().captured(1).toInt();
            if (n > 0)
                found.insert(n);
        }
    }
    return {found.begin(), found.end()};
}
} // namespace

Result_t<Review_t> DatabaseManager::InitReview(ID_t deckId, ID_t wordId)
{
    // Determine the ordinals this entry needs: 0 for a normal card, or one per
    // distinct cloze deletion (c1,c2,…) for a cloze entry. Pure-cloze entries
    // don't get an ordinal-0 card (it would redundantly show every blank).
    std::vector<int> ordinals;
    if (auto blocks = GetContentForEntry(wordId)) {
        ordinals = clozeOrdinalsFromBlocks(*blocks);
    }
    if (ordinals.empty())
        ordinals.push_back(0);

    for (const int ord : ordinals) {
        QSqlQuery ins(m_db);
        ins.prepare("INSERT OR IGNORE INTO review "
                    "(deck_id, entry_id, cloze_ordinal, next_review_date) "
                    "VALUES (:deckId, :wordId, :ord, date('now', 'localtime'));");
        ins.bindValue(":deckId", QVariant::fromValue(deckId));
        ins.bindValue(":wordId", QVariant::fromValue(wordId));
        ins.bindValue(":ord", ord);
        if (!ins.exec())
            return std::unexpected(ins.lastError().text().toStdString());
    }

    // Return the first ordinal's row (representative).
    QSqlQuery q(m_db);
    q.prepare("SELECT id, deck_id, entry_id, ease_factor, interval_days, repetitions, "
              "lapses, is_leech, cloze_ordinal, next_review_date, last_review_date "
              "FROM review WHERE deck_id = :deckId AND entry_id = :wordId "
              "ORDER BY cloze_ordinal LIMIT 1;");
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
                    .lapses         = static_cast<uint16_t>(q.value(6).toInt()),
                    .isLeech        = q.value(7).toInt() != 0,
                    .clozeOrdinal   = q.value(8).toInt(),
                    .nextReviewDate = q.value(9).toString().toStdString(),
                    .lastReviewDate = q.value(10).toString().toStdString()};
}

Result_t<Review_t>
DatabaseManager::SubmitReview(ID_t deckId, ID_t wordId, int quality, int clozeOrdinal)
{
    // Determine the deck's scheduler. Default 'sm2' keeps existing behaviour.
    QString scheduler = QStringLiteral("sm2");
    double  retention = 0.9;
    QString weights;
    {
        QSqlQuery dq(m_db);
        dq.prepare("SELECT scheduler, fsrs_retention, fsrs_weights FROM deck WHERE id = :d;");
        dq.bindValue(":d", QVariant::fromValue(deckId));
        if (dq.exec() && dq.next()) {
            scheduler = dq.value(0).toString();
            retention = dq.value(1).toDouble();
            weights   = dq.value(2).toString();
        }
    }
    if (scheduler == QStringLiteral("fsrs"))
        return submitReviewFsrs(deckId, wordId, quality, retention, weights, clozeOrdinal);
    return submitReviewSm2(deckId, wordId, quality, clozeOrdinal);
}

Result_t<Review_t>
DatabaseManager::submitReviewSm2(ID_t deckId, ID_t wordId, int quality, int clozeOrdinal)
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT id, ease_factor, interval_days, repetitions, lapses, is_leech "
        "FROM review WHERE deck_id = :deckId AND entry_id = :wordId AND cloze_ordinal = :ord;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":ord", clozeOrdinal);

    if (!q.exec() || !q.next())
        return std::unexpected("Review not found. Call initReview first.");

    const ID_t reviewId     = q.value(0).toLongLong();
    float      easeFactor   = q.value(1).toFloat();
    int        intervalDays = q.value(2).toInt();
    int        repetitions  = q.value(3).toInt();
    int        lapses       = q.value(4).toInt();
    bool       isLeech      = q.value(5).toInt() != 0;

    // The UI grades on a 0..3 scale (0 Forgot, 1 Hard, 2 Good, 3 Easy), but the
    // SM-2 algorithm is defined on a 0..5 quality scale and treats q >= 3 as a
    // pass. Map the UI buttons onto SM-2's scale so "Good" counts as a pass
    // (the previous code compared the raw 0..3 value against >= 3, which made
    // "Good" a failure and reset the card — a real scheduling bug).
    //
    //   UI 0 Forgot -> SM-2 0 (fail)
    //   UI 1 Hard   -> SM-2 3 (minimal pass)
    //   UI 2 Good   -> SM-2 4
    //   UI 3 Easy   -> SM-2 5
    static constexpr int kSm2[4]    = {0, 3, 4, 5};
    const int            uiQuality  = std::clamp(quality, 0, 3);
    const int            sm2Quality = kSm2[uiQuality];

    // SM-2 algorithm (operating on the mapped 0..5 quality).
    constexpr int kLeechThreshold = 8; // lapses before a card is flagged a leech
    if (sm2Quality >= 3) {
        if (repetitions == 0)
            intervalDays = 1;
        else if (repetitions == 1)
            intervalDays = 6;
        else
            intervalDays = static_cast<int>(std::round(intervalDays * easeFactor));

        easeFactor += 0.1f - (5 - sm2Quality) * (0.08f + (5 - sm2Quality) * 0.02f);
        easeFactor = (std::max)(1.3f, easeFactor);
        repetitions++;
    } else {
        // Failed. Reset the streak, keep ease factor, and count a lapse. A card
        // that lapses repeatedly is flagged as a leech so the user can review or
        // suspend it rather than seeing it churn forever at interval 1.
        repetitions  = 0;
        intervalDays = 1;
        lapses++;
        if (!isLeech && lapses >= kLeechThreshold)
            isLeech = true;
    }

    const QString today    = QDate::currentDate().toString("yyyy-MM-dd");
    const QString nextDate = QDate::currentDate().addDays(intervalDays).toString("yyyy-MM-dd");

    q.prepare(
        "UPDATE review SET ease_factor = :ef, interval_days = :interval, repetitions = :reps, "
        "lapses = :lapses, is_leech = :leech, "
        "next_review_date = :nextDate, last_review_date = :lastDate "
        "WHERE deck_id = :deckId AND entry_id = :wordId AND cloze_ordinal = :ord;");
    q.bindValue(":ef", easeFactor);
    q.bindValue(":interval", intervalDays);
    q.bindValue(":reps", repetitions);
    q.bindValue(":lapses", lapses);
    q.bindValue(":leech", isLeech ? 1 : 0);
    q.bindValue(":nextDate", nextDate);
    q.bindValue(":lastDate", today);
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":ord", clozeOrdinal);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    // Append to the review history log. Non-fatal if it fails.
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
                    .lapses         = static_cast<uint16_t>(lapses),
                    .isLeech        = isLeech,
                    .nextReviewDate = nextDate.toStdString(),
                    .lastReviewDate = today.toStdString()};
}

Result_t<Review_t> DatabaseManager::submitReviewFsrs(ID_t           deckId,
                                                     ID_t           wordId,
                                                     int            quality,
                                                     double         retention,
                                                     const QString& weightsJson,
                                                     int            clozeOrdinal)
{
    QSqlQuery q(m_db);
    q.prepare(
        "SELECT id, stability, difficulty, lapses, is_leech, last_review_date "
        "FROM review WHERE deck_id = :deckId AND entry_id = :wordId AND cloze_ordinal = :ord;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":ord", clozeOrdinal);
    if (!q.exec() || !q.next())
        return std::unexpected("Review not found. Call initReview first.");

    const ID_t    reviewId = q.value(0).toLongLong();
    Fsrs::State   st{.stability = q.value(1).toDouble(), .difficulty = q.value(2).toDouble()};
    int           lapses   = q.value(3).toInt();
    bool          isLeech  = q.value(4).toInt() != 0;
    const QString lastDate = q.value(5).toString();

    // UI grade 0..3 (Forgot/Hard/Good/Easy) -> FSRS 1..4 (Again/Hard/Good/Easy).
    const int fsrsGrade = std::clamp(quality, 0, 3) + 1;

    // Elapsed days since last review (0 for a new card).
    double elapsed = 0.0;
    if (!lastDate.isEmpty()) {
        const QDate prev = QDate::fromString(lastDate, "yyyy-MM-dd");
        if (prev.isValid())
            elapsed = (std::max)(0, static_cast<int>(prev.daysTo(QDate::currentDate())));
    }

    Fsrs::Params p;
    p.requestRetention = std::clamp(retention, 0.70, 0.97);
    // Apply the deck's optimized weights if present (JSON array of 19 numbers);
    // otherwise the default weights stand.
    if (!weightsJson.isEmpty()) {
        const QJsonDocument doc = QJsonDocument::fromJson(weightsJson.toUtf8());
        if (doc.isArray()) {
            const QJsonArray arr = doc.array();
            if (arr.size() == 19) {
                for (int i = 0; i < 19; ++i)
                    p.w[static_cast<size_t>(i)] = arr[i].toDouble(p.w[static_cast<size_t>(i)]);
            }
        }
    }
    const Fsrs::Schedule sched = Fsrs::schedule(p, st, elapsed, fsrsGrade);

    constexpr int kLeechThreshold = 8;
    if (sched.lapsed) {
        lapses++;
        if (!isLeech && lapses >= kLeechThreshold)
            isLeech = true;
    }

    const QString today = QDate::currentDate().toString("yyyy-MM-dd");
    const QString nextDate =
        QDate::currentDate().addDays(sched.intervalDays).toString("yyyy-MM-dd");

    QSqlQuery up(m_db);
    up.prepare("UPDATE review SET stability = :s, difficulty = :d, "
               "interval_days = :iv, lapses = :lapses, is_leech = :leech, "
               "next_review_date = :nextDate, last_review_date = :lastDate "
               "WHERE deck_id = :deckId AND entry_id = :wordId AND cloze_ordinal = :ord;");
    up.bindValue(":s", sched.state.stability);
    up.bindValue(":d", sched.state.difficulty);
    up.bindValue(":iv", sched.intervalDays);
    up.bindValue(":lapses", lapses);
    up.bindValue(":leech", isLeech ? 1 : 0);
    up.bindValue(":nextDate", nextDate);
    up.bindValue(":lastDate", today);
    up.bindValue(":deckId", QVariant::fromValue(deckId));
    up.bindValue(":wordId", QVariant::fromValue(wordId));
    up.bindValue(":ord", clozeOrdinal);
    if (!up.exec())
        return std::unexpected(up.lastError().text().toStdString());

    // Log for stats/analytics (quality on the UI scale; store interval + a
    // pseudo ease derived from difficulty for the existing log schema).
    {
        QSqlQuery log(m_db);
        log.prepare("INSERT INTO review_log "
                    "(deck_id, entry_id, quality, ease_factor, interval_days, reviewed_at) "
                    "VALUES (:d, :w, :q, :ef, :iv, :ts);");
        log.bindValue(":d", QVariant::fromValue(deckId));
        log.bindValue(":w", QVariant::fromValue(wordId));
        log.bindValue(":q", quality);
        log.bindValue(":ef", sched.state.difficulty);
        log.bindValue(":iv", sched.intervalDays);
        log.bindValue(":ts", QDateTime::currentMSecsSinceEpoch());
        log.exec();
    }

    return Review_t{.id             = reviewId,
                    .deckId         = deckId,
                    .wordId         = wordId,
                    .easeFactor     = static_cast<float>(sched.state.difficulty),
                    .intervalDays   = static_cast<uint16_t>(sched.intervalDays),
                    .repetitions    = 0,
                    .lapses         = static_cast<uint16_t>(lapses),
                    .isLeech        = isLeech,
                    .nextReviewDate = nextDate.toStdString(),
                    .lastReviewDate = today.toStdString()};
}

Result_t<Review_t>
DatabaseManager::LogReviewOnly(ID_t deckId, ID_t wordId, int quality, int clozeOrdinal)
{
    // Read the current review row (for the ease/interval snapshot in the log)
    // without modifying it.
    float ef = 2.5f;
    int   iv = 0;
    {
        QSqlQuery r(m_db);
        r.prepare("SELECT ease_factor, interval_days FROM review "
                  "WHERE deck_id = :d AND entry_id = :w AND cloze_ordinal = :ord;");
        r.bindValue(":d", QVariant::fromValue(deckId));
        r.bindValue(":w", QVariant::fromValue(wordId));
        r.bindValue(":ord", clozeOrdinal);
        if (r.exec() && r.next()) {
            ef = r.value(0).toFloat();
            iv = r.value(1).toInt();
        }
    }

    QSqlQuery log(m_db);
    log.prepare("INSERT INTO review_log "
                "(deck_id, entry_id, quality, ease_factor, interval_days, reviewed_at) "
                "VALUES (:d, :w, :q, :ef, :iv, :ts);");
    log.bindValue(":d", QVariant::fromValue(deckId));
    log.bindValue(":w", QVariant::fromValue(wordId));
    log.bindValue(":q", quality);
    log.bindValue(":ef", ef);
    log.bindValue(":iv", iv);
    log.bindValue(":ts", QDateTime::currentMSecsSinceEpoch());
    if (!log.exec())
        return std::unexpected(log.lastError().text().toStdString());

    // Return a minimal row; the schedule is unchanged so callers shouldn't rely
    // on updated fields here.
    return Review_t{.id             = -1,
                    .deckId         = deckId,
                    .wordId         = wordId,
                    .easeFactor     = ef,
                    .intervalDays   = static_cast<uint16_t>(iv),
                    .repetitions    = 0,
                    .lapses         = 0,
                    .isLeech        = false,
                    .nextReviewDate = {},
                    .lastReviewDate = {}};
}

Result_t<std::vector<Review_t>> DatabaseManager::GetDueReviews(ID_t deckId)
{
    // Per-deck daily new-card limit. New cards (repetitions = 0, never reviewed)
    // would otherwise all become due at once — importing 2,000 cards would dump
    // 2,000 into one session. We cap how many *new* cards enter the queue per
    // day while letting every genuinely-due *review* card through.
    int newPerDay = 20;
    {
        QSqlQuery dq(m_db);
        dq.prepare("SELECT new_cards_per_day FROM deck WHERE id = :d;");
        dq.bindValue(":d", QVariant::fromValue(deckId));
        if (dq.exec() && dq.next())
            newPerDay = dq.value(0).toInt();
    }

    // How many new cards were already introduced today (graduated from
    // repetitions 0 to >=1 with last_review_date == today). This makes the limit
    // hold across multiple sessions in the same day.
    int introducedToday = 0;
    {
        QSqlQuery cq(m_db);
        cq.prepare("SELECT COUNT(*) FROM review WHERE deck_id = :d "
                   "AND repetitions >= 1 AND last_review_date = date('now', 'localtime');");
        cq.bindValue(":d", QVariant::fromValue(deckId));
        if (cq.exec() && cq.next())
            introducedToday = cq.value(0).toInt();
    }
    const int newAllowance = (std::max)(0, newPerDay - introducedToday);

    auto readRows = [](QSqlQuery& q, std::vector<Review_t>& out) {
        while (q.next()) {
            out.push_back(Review_t{.id             = q.value(0).toLongLong(),
                                   .deckId         = q.value(1).toLongLong(),
                                   .wordId         = q.value(2).toLongLong(),
                                   .easeFactor     = q.value(3).toFloat(),
                                   .intervalDays   = static_cast<uint16_t>(q.value(4).toInt()),
                                   .repetitions    = static_cast<uint16_t>(q.value(5).toInt()),
                                   .lapses         = static_cast<uint16_t>(q.value(6).toInt()),
                                   .isLeech        = q.value(7).toInt() != 0,
                                   .clozeOrdinal   = q.value(8).toInt(),
                                   .nextReviewDate = q.value(9).toString().toStdString(),
                                   .lastReviewDate = q.value(10).toString().toStdString()});
        }
    };

    std::vector<Review_t> reviews;

    // 1. Review cards: already learned (repetitions >= 1) and due. No cap.
    {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, deck_id, entry_id, ease_factor, interval_days, repetitions, "
                  "lapses, is_leech, cloze_ordinal, next_review_date, last_review_date "
                  "FROM review WHERE deck_id = :deckId AND repetitions >= 1 "
                  "AND next_review_date <= date('now', 'localtime') "
                  "ORDER BY next_review_date ASC;");
        q.bindValue(":deckId", QVariant::fromValue(deckId));
        if (!q.exec())
            return std::unexpected(q.lastError().text().toStdString());
        readRows(q, reviews);
    }

    // 2. New cards: repetitions == 0, limited to today's remaining allowance.
    if (newAllowance > 0) {
        QSqlQuery q(m_db);
        q.prepare("SELECT id, deck_id, entry_id, ease_factor, interval_days, repetitions, "
                  "lapses, is_leech, cloze_ordinal, next_review_date, last_review_date "
                  "FROM review WHERE deck_id = :deckId AND repetitions = 0 "
                  "AND next_review_date <= date('now', 'localtime') "
                  "ORDER BY entry_id ASC LIMIT :lim;");
        q.bindValue(":deckId", QVariant::fromValue(deckId));
        q.bindValue(":lim", newAllowance);
        if (!q.exec())
            return std::unexpected(q.lastError().text().toStdString());
        readRows(q, reviews);
    }

    return reviews;
}

Result_t<std::vector<Review_t>> DatabaseManager::GetFilteredReviews(int                      mode,
                                                                    const std::vector<ID_t>& tagIds,
                                                                    const std::string& language,
                                                                    ID_t               deckId,
                                                                    int                aheadDays,
                                                                    int                limit)
{
    // Build a query over review r joined to entry e, applying the filters. Mode
    // controls the schedule predicate: Due = due today; Ahead = due within
    // aheadDays; Cram = no schedule predicate (any matching card).
    QString sql = "SELECT DISTINCT r.id, r.deck_id, r.entry_id, r.ease_factor, r.interval_days, "
                  "r.repetitions, r.lapses, r.is_leech, r.cloze_ordinal, r.next_review_date, "
                  "r.last_review_date "
                  "FROM review r JOIN entry e ON e.id = r.entry_id ";

    if (!tagIds.empty())
        sql += "JOIN entry_tag et ON et.entry_id = e.id ";

    sql += "WHERE 1=1 ";

    if (deckId >= 0)
        sql += "AND r.deck_id = :deckId ";
    if (!language.empty())
        sql += "AND e.language = :lang ";

    // Schedule predicate by mode.
    if (mode == 0) // Due
        sql += "AND r.next_review_date <= date('now', 'localtime') ";
    else if (mode == 1) // Ahead
        sql += "AND r.next_review_date <= date('now', 'localtime', :ahead) ";
    // mode == 2 (Cram): no schedule predicate.

    if (!tagIds.empty()) {
        sql += "AND et.tag_id IN (";
        for (size_t i = 0; i < tagIds.size(); ++i)
            sql += (i ? QStringLiteral(",:tag%1").arg(i) : QStringLiteral(":tag%1").arg(i));
        sql += ") ";
    }

    sql += "ORDER BY r.next_review_date ASC LIMIT :lim;";

    QSqlQuery q(m_db);
    q.prepare(sql);
    if (deckId >= 0)
        q.bindValue(":deckId", QVariant::fromValue(deckId));
    if (!language.empty())
        q.bindValue(":lang", QString::fromStdString(language));
    if (mode == 1)
        q.bindValue(":ahead", QStringLiteral("+%1 days").arg(aheadDays));
    for (size_t i = 0; i < tagIds.size(); ++i)
        q.bindValue(QStringLiteral(":tag%1").arg(i), QVariant::fromValue(tagIds[i]));
    q.bindValue(":lim", limit > 0 ? limit : 100);

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
                                   .lapses         = static_cast<uint16_t>(q.value(6).toInt()),
                                   .isLeech        = q.value(7).toInt() != 0,
                                   .clozeOrdinal   = q.value(8).toInt(),
                                   .nextReviewDate = q.value(9).toString().toStdString(),
                                   .lastReviewDate = q.value(10).toString().toStdString()});
    }
    return reviews;
}

Result_t<DeckStats_t> DatabaseManager::GetDeckStats(ID_t deckId)
{
    DeckStats_t stats;

    auto words = GetEntriesForDeck(deckId);
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
            stats.due++; // never reviewed → new card, due
            continue;
        }
        const QString next = it.value();
        if (next.isEmpty() || next <= today) {
            stats.due++;
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
    // reviewed_at is epoch ms.
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

Result_t<std::vector<EntryReviewEvent_t>> DatabaseManager::GetEntryHistory(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT reviewed_at, quality, ease_factor, interval_days "
              "FROM review_log WHERE deck_id = :d AND entry_id = :w "
              "ORDER BY reviewed_at ASC;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    q.bindValue(":w", QVariant::fromValue(wordId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<EntryReviewEvent_t> events;
    while (q.next()) {
        events.push_back(EntryReviewEvent_t{q.value(0).toLongLong(),
                                            q.value(1).toInt(),
                                            q.value(2).toDouble(),
                                            q.value(3).toInt()});
    }
    return events;
}

Result_t<GlobalStats_t> DatabaseManager::GetGlobalStats()
{
    GlobalStats_t s;

    // Daily review counts across all decks, chronological.
    {
        QSqlQuery q(m_db);
        if (!q.exec("SELECT date(reviewed_at/1000, 'unixepoch', 'localtime') AS d, "
                    "COUNT(*) AS c, AVG(quality) AS aq "
                    "FROM review_log GROUP BY d ORDER BY d ASC;"))
            return std::unexpected(q.lastError().text().toStdString());
        while (q.next()) {
            const std::string day = q.value(0).toString().toStdString();
            const int         cnt = q.value(1).toInt();
            s.daily.push_back(DailyStat_t{day, cnt, q.value(2).toDouble()});
            s.totalReviews += cnt;
            if (s.firstReviewDate.empty())
                s.firstReviewDate = day;
        }
    }

    // Retention across all decks.
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT SUM(CASE WHEN quality >= 2 THEN 1 ELSE 0 END), COUNT(*) "
                   "FROM review_log;") &&
            q.next()) {
            const int total = q.value(1).toInt();
            s.retention = (total > 0) ? q.value(0).toDouble() / static_cast<double>(total) : 0.0;
        }
    }

    // Total words.
    {
        QSqlQuery q(m_db);
        if (q.exec("SELECT COUNT(*) FROM entry;") && q.next())
            s.totalWords = q.value(0).toInt();
    }

    // Due counts: today (<= today) and next 7 days.
    {
        const QString today = QDate::currentDate().toString("yyyy-MM-dd");
        const QString in7   = QDate::currentDate().addDays(7).toString("yyyy-MM-dd");
        QSqlQuery     q(m_db);
        q.prepare("SELECT "
                  "SUM(CASE WHEN next_review_date <= :today THEN 1 ELSE 0 END), "
                  "SUM(CASE WHEN next_review_date > :today AND next_review_date <= :in7 "
                  "         THEN 1 ELSE 0 END) "
                  "FROM review WHERE next_review_date IS NOT NULL AND next_review_date != '';");
        q.bindValue(":today", today);
        q.bindValue(":in7", in7);
        if (q.exec() && q.next()) {
            s.dueToday     = q.value(0).toInt();
            s.dueNext7Days = q.value(1).toInt();
        }
    }

    // Reviews today.
    {
        const QString today = QDate::currentDate().toString("yyyy-MM-dd");
        QSqlQuery     q(m_db);
        q.prepare("SELECT COUNT(*) FROM review_log "
                  "WHERE date(reviewed_at/1000, 'unixepoch', 'localtime') = :today;");
        q.bindValue(":today", today);
        if (q.exec() && q.next())
            s.reviewsToday = q.value(0).toInt();
    }

    // Streaks from the distinct set of review days.
    {
        QSet<QDate> days;
        QSqlQuery   q(m_db);
        if (q.exec("SELECT DISTINCT date(reviewed_at/1000, 'unixepoch', 'localtime') "
                   "FROM review_log;")) {
            while (q.next()) {
                const QDate d = QDate::fromString(q.value(0).toString(), "yyyy-MM-dd");
                if (d.isValid())
                    days.insert(d);
            }
        }
        // Longest run.
        int longest = 0;
        for (const QDate& d : days) {
            if (days.contains(d.addDays(-1)))
                continue; // not a run start
            int   run = 1;
            QDate cur = d;
            while (days.contains(cur.addDays(1))) {
                cur = cur.addDays(1);
                ++run;
            }
            longest = (std::max)(longest, run);
        }
        s.longestStreakDays = longest;
        // Current run ending today or yesterday.
        const QDate today   = QDate::currentDate();
        QDate       anchor  = days.contains(today)               ? today
                              : days.contains(today.addDays(-1)) ? today.addDays(-1)
                                                                 : QDate();
        int         current = 0;
        if (anchor.isValid()) {
            QDate cur = anchor;
            while (days.contains(cur)) {
                ++current;
                cur = cur.addDays(-1);
            }
        }
        s.currentStreakDays = current;
    }

    // Count cards currently flagged as leeches across all decks.
    {
        QSqlQuery lq(m_db);
        if (lq.exec("SELECT COUNT(*) FROM review WHERE is_leech = 1;") && lq.next())
            s.leechCount = lq.value(0).toInt();
    }

    return s;
}

} // namespace Service
