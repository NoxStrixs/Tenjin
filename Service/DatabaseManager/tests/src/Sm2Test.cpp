#include <DatabaseManager/DatabaseManager.h>

#include "TestHelpers.h"

#include <gtest/gtest.h>

using namespace Service;

namespace {

// Build a manager + a word + a deck the word belongs to, returning ids.
struct Fixture {
    std::shared_ptr<DatabaseManager> db;
    ID_t                             wordId = 0;
    ID_t                             deckId = 0;
};

Fixture makeFixture(TempDb& tmp)
{
    Fixture f;
    f.db        = std::make_shared<DatabaseManager>(tmp.path());
    auto w      = f.db->AddWord("kanji");
    EXPECT_TRUE(w.has_value());
    f.wordId    = w->id;
    auto d      = f.db->AddDeck("Deck", /*smart=*/false, FilterMode_t::And);
    EXPECT_TRUE(d.has_value());
    f.deckId    = d->id;
    EXPECT_TRUE(f.db->AddWordToDeck(f.deckId, f.wordId).has_value());
    EXPECT_TRUE(f.db->InitReview(f.deckId, f.wordId).has_value());
    return f;
}

} // namespace

// ── Basic CRUD round-trips ────────────────────────────────────────────────────
TEST(Db, AddAndGetWord)
{
    TempDb          tmp;
    DatabaseManager db(tmp.path());
    auto            w = db.AddWord("serendipity");
    ASSERT_TRUE(w.has_value()) << (w ? "" : w.error());
    EXPECT_EQ(w->word, "serendipity");

    auto got = db.GetWord("serendipity");
    ASSERT_TRUE(got.has_value());
    EXPECT_EQ(got->id, w->id);
}

TEST(Db, DuplicateWordFails)
{
    TempDb          tmp;
    DatabaseManager db(tmp.path());
    ASSERT_TRUE(db.AddWord("dup").has_value());
    EXPECT_FALSE(db.AddWord("dup").has_value()) << "UNIQUE(word) should reject duplicate";
}

// A formula content block must persist with kind "formula" (the v3 promise).
TEST(Db, FormulaBlockPersistsKind)
{
    TempDb          tmp;
    DatabaseManager db(tmp.path());
    auto            w = db.AddWord("integral");
    ASSERT_TRUE(w.has_value());

    ContentBlock_t blk{.wordId = w->id,
                       .type    = ContentType_t::Formula,
                       .content = "\\int_0^1 x^2\\,dx",
                       .row     = 0,
                       .col     = 0,
                       .rowSpan = 1,
                       .colSpan = 1};
    auto cb = db.AddContentBlock(blk);
    ASSERT_TRUE(cb.has_value()) << (cb ? "" : cb.error());

    auto blocks = db.GetContentForWord(w->id);
    ASSERT_TRUE(blocks.has_value());
    ASSERT_EQ(blocks->size(), 1u);
    EXPECT_EQ(blocks->front().type, ContentType_t::Formula);
    EXPECT_EQ(ToKindString(blocks->front().type), "formula");
}

// ── SM-2 scheduling ───────────────────────────────────────────────────────────
// First successful review (reps 0 → 1) sets interval to 1 day.
TEST(Sm2, FirstSuccessIntervalIsOne)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    auto   r = f.db->SubmitReview(f.deckId, f.wordId, 5);
    ASSERT_TRUE(r.has_value()) << (r ? "" : r.error());
    EXPECT_EQ(r->repetitions, 1);
    EXPECT_EQ(r->intervalDays, 1);
}

// Second success (reps 1 → 2) jumps to the fixed 6-day interval.
TEST(Sm2, SecondSuccessIntervalIsSix)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    ASSERT_TRUE(f.db->SubmitReview(f.deckId, f.wordId, 5).has_value());
    auto r = f.db->SubmitReview(f.deckId, f.wordId, 5);
    ASSERT_TRUE(r.has_value());
    EXPECT_EQ(r->repetitions, 2);
    EXPECT_EQ(r->intervalDays, 6);
}

// Third+ success multiplies the interval by the ease factor (6 * ~2.6 ≈ 16).
TEST(Sm2, ThirdSuccessMultipliesByEase)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    f.db->SubmitReview(f.deckId, f.wordId, 5); // -> 1
    f.db->SubmitReview(f.deckId, f.wordId, 5); // -> 6
    auto r = f.db->SubmitReview(f.deckId, f.wordId, 5); // -> round(6 * EF)
    ASSERT_TRUE(r.has_value());
    EXPECT_EQ(r->repetitions, 3);
    EXPECT_GT(r->intervalDays, 6) << "interval should grow by ease factor";
    EXPECT_GT(r->easeFactor, 2.5f) << "quality 5 should raise ease above default";
}

// A failing grade (<3) resets repetitions and interval, regardless of history.
TEST(Sm2, FailureResetsStreak)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    f.db->SubmitReview(f.deckId, f.wordId, 5);
    f.db->SubmitReview(f.deckId, f.wordId, 5);
    auto r = f.db->SubmitReview(f.deckId, f.wordId, 1); // fail
    ASSERT_TRUE(r.has_value());
    EXPECT_EQ(r->repetitions, 0);
    EXPECT_EQ(r->intervalDays, 1);
}

// The ease factor must never drop below the SM-2 floor of 1.3, even after
// repeated low (but passing) grades.
TEST(Sm2, EaseFactorFloorIsRespected)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    Review_t last{};
    for (int i = 0; i < 20; ++i) {
        auto r = f.db->SubmitReview(f.deckId, f.wordId, 3); // minimum passing
        ASSERT_TRUE(r.has_value());
        last = *r;
    }
    EXPECT_GE(last.easeFactor, 1.3f);
}

// A freshly initialized review is due today (uses local date), so it shows up
// in GetDueReviews immediately — the local/UTC fix guarantees this near
// midnight in any timezone.
TEST(Sm2, NewReviewIsDueToday)
{
    TempDb tmp;
    auto   f   = makeFixture(tmp);
    auto   due = f.db->GetDueReviews(f.deckId);
    ASSERT_TRUE(due.has_value()) << (due ? "" : due.error());
    EXPECT_EQ(due->size(), 1u) << "newly initialized card should be due now";
}

// After a successful review the card's next date moves into the future, so it
// is no longer due today.
TEST(Sm2, ReviewedCardLeavesDueQueue)
{
    TempDb tmp;
    auto   f = makeFixture(tmp);
    ASSERT_TRUE(f.db->SubmitReview(f.deckId, f.wordId, 5).has_value());
    auto due = f.db->GetDueReviews(f.deckId);
    ASSERT_TRUE(due.has_value());
    EXPECT_EQ(due->size(), 0u) << "card scheduled +1 day should not be due today";
}
