#include <QtTest>
#include <QTemporaryDir>

#include <DatabaseManager/DatabaseManager.h>
#include <DatabaseManager/Types.h>

using namespace Service;

// Tests for scheduling/robustness logic added during the polish/feature work:
//   * SM-2 quality-scale mapping (UI 0..3 -> internal 0..5; "Good" must pass)
//   * leech detection after repeated lapses
//   * untagged-entry query
//   * content-type validation of untrusted integers
//   * per-deck daily new-card limit
class SchedulingTest : public QObject
{
    Q_OBJECT

private slots:
    void goodGradePassesAndGrowsInterval();
    void forgotGradeResetsAndCountsLapse();
    void repeatedFailuresFlagLeech();
    void untaggedEntriesSurfaced();
    void contentTypeValidationClamps();
    void dailyNewCardLimitCapsNewCards();

private:
    // Build a deck with one entry and an initialised review row; returns ids.
    static void seedOne(DatabaseManager& db, ID_t& deckId, ID_t& wordId)
    {
        auto deck = db.AddDeck("Deck", false, FilterMode_t::And);
        QVERIFY(deck.has_value());
        auto word = db.AddEntry("word");
        QVERIFY(word.has_value());
        QVERIFY(db.AddEntryToDeck(deck->id, word->id).has_value());
        QVERIFY(db.InitReview(deck->id, word->id).has_value());
        deckId = deck->id;
        wordId = word->id;
    }
};

void SchedulingTest::goodGradePassesAndGrowsInterval()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/sched.db").toStdString());

    ID_t deckId = 0, wordId = 0;
    seedOne(db, deckId, wordId);

    // UI quality 2 == "Good". Under the old raw-0..3 comparison this was treated
    // as a failure; it must now be a pass that advances the card.
    auto r1 = db.SubmitReview(deckId, wordId, 2);
    QVERIFY(r1.has_value());
    QCOMPARE(r1->repetitions, static_cast<uint16_t>(1));
    QCOMPARE(r1->lapses, static_cast<uint16_t>(0));

    auto r2 = db.SubmitReview(deckId, wordId, 2);
    QVERIFY(r2.has_value());
    QCOMPARE(r2->repetitions, static_cast<uint16_t>(2));
    // Second successful rep sets the canonical 6-day interval.
    QCOMPARE(r2->intervalDays, static_cast<uint16_t>(6));
}

void SchedulingTest::forgotGradeResetsAndCountsLapse()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/sched.db").toStdString());

    ID_t deckId = 0, wordId = 0;
    seedOne(db, deckId, wordId);

    QVERIFY(db.SubmitReview(deckId, wordId, 3).has_value()); // Easy -> pass
    auto fail = db.SubmitReview(deckId, wordId, 0);          // Forgot -> fail
    QVERIFY(fail.has_value());
    QCOMPARE(fail->repetitions, static_cast<uint16_t>(0));
    QCOMPARE(fail->intervalDays, static_cast<uint16_t>(1));
    QCOMPARE(fail->lapses, static_cast<uint16_t>(1));
    QVERIFY(!fail->isLeech);
}

void SchedulingTest::repeatedFailuresFlagLeech()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/sched.db").toStdString());

    ID_t deckId = 0, wordId = 0;
    seedOne(db, deckId, wordId);

    // Threshold is 8 lapses. Fail repeatedly and confirm the flag flips.
    Result_t<Review_t> last = std::unexpected(std::string("none"));
    for (int i = 0; i < 8; ++i)
        last = db.SubmitReview(deckId, wordId, 0);

    QVERIFY(last.has_value());
    QVERIFY(last->lapses >= 8);
    QVERIFY(last->isLeech);
}

void SchedulingTest::untaggedEntriesSurfaced()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/tags.db").toStdString());

    auto tagged   = db.AddEntry("tagged");
    auto untagged = db.AddEntry("untagged");
    QVERIFY(tagged.has_value() && untagged.has_value());

    auto tag = db.AddTag("noun");
    QVERIFY(tag.has_value());
    QVERIFY(db.AddTagToEntry(tagged->id, tag->id).has_value());

    auto result = db.GetUntaggedEntries();
    QVERIFY(result.has_value());
    QCOMPARE(result->size(), size_t(1));
    QCOMPARE(QString::fromStdString(result->front().word), QString("untagged"));
}

void SchedulingTest::contentTypeValidationClamps()
{
    // Valid values pass through; out-of-range untrusted ints clamp to Note.
    QCOMPARE(ValidContentType(0), ContentType_t::Definition);
    QCOMPARE(ValidContentType(6), ContentType_t::Tense);
    QCOMPARE(ValidContentType(999), ContentType_t::Note);
    QCOMPARE(ValidContentType(-1), ContentType_t::Note);
}

void SchedulingTest::dailyNewCardLimitCapsNewCards()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/limit.db").toStdString());

    auto deck = db.AddDeck("Big", false, FilterMode_t::And);
    QVERIFY(deck.has_value());
    QVERIFY(db.SetDeckNewCardsPerDay(deck->id, 3).has_value());

    // Add 10 brand-new cards.
    for (int i = 0; i < 10; ++i) {
        auto w = db.AddEntry(("w" + std::to_string(i)));
        QVERIFY(w.has_value());
        QVERIFY(db.AddEntryToDeck(deck->id, w->id).has_value());
        QVERIFY(db.InitReview(deck->id, w->id).has_value());
    }

    // Only the daily allowance of new cards should be returned.
    auto due = db.GetDueReviews(deck->id);
    QVERIFY(due.has_value());
    QCOMPARE(due->size(), size_t(3));
}

int runSchedulingTests(int argc, char** argv)
{
    SchedulingTest t;
    return QTest::qExec(&t, argc, argv);
}

#include "test_scheduling.moc"
