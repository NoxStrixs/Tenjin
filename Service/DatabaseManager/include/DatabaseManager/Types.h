#pragma once

#include <cstdint>
#include <expected>
#include <string>
#include <string_view>
#include <vector>

namespace Service {

using ID_t = std::int64_t;

template <typename T>
using Result_t = std::expected<T, std::string>;

enum class ContentType_t : int {
    Definition = 0,
    Media      = 1,
    Note       = 2,
    Divider    = 3,
    Formula    = 4, // LaTeX payload, rendered read-only
    Header     = 5, // Section heading — large bold text
    Tense      = 6, // Verb conjugation table; body is JSON object of
                    // tense → form pairs ({"present":"go","past":"went",
                    // "future":"will go","conditional":"would go"})
    Cloze      = 7, // Fill-in-the-blank text with Anki-style {{cN::answer::hint}}
                    // markers. Masked on the review front, revealed on answer.
};

inline std::string ToKindString(ContentType_t t)
{
    switch (t) {
    case ContentType_t::Definition:
        return "definition";
    case ContentType_t::Media:
        return "media";
    case ContentType_t::Note:
        return "note";
    case ContentType_t::Divider:
        return "divider";
    case ContentType_t::Formula:
        return "formula";
    case ContentType_t::Header:
        return "header";
    case ContentType_t::Tense:
        return "tense";
    case ContentType_t::Cloze:
        return "cloze";
    }
    return "note";
}

inline ContentType_t FromKindString(std::string_view s)
{
    if (s == "definition")
        return ContentType_t::Definition;
    if (s == "media")
        return ContentType_t::Media;
    if (s == "divider")
        return ContentType_t::Divider;
    if (s == "formula")
        return ContentType_t::Formula;
    if (s == "header")
        return ContentType_t::Header;
    if (s == "tense")
        return ContentType_t::Tense;
    if (s == "cloze")
        return ContentType_t::Cloze;
    return ContentType_t::Note;
}

// Convert an untrusted integer (e.g. from an imported file) into a valid
// ContentType_t, clamping anything out of the known 0..7 range to Note. Using
// static_cast<ContentType_t> directly on external data would store an invalid
// enum value that later switch statements don't handle.
inline ContentType_t ValidContentType(int raw)
{
    switch (static_cast<ContentType_t>(raw)) {
    case ContentType_t::Definition:
    case ContentType_t::Media:
    case ContentType_t::Note:
    case ContentType_t::Divider:
    case ContentType_t::Formula:
    case ContentType_t::Header:
    case ContentType_t::Tense:
    case ContentType_t::Cloze:
        return static_cast<ContentType_t>(raw);
    }
    return ContentType_t::Note;
}

enum class FilterMode_t {
    And,
    Or,
};

struct Entry_t {
    ID_t        id = 0;
    std::string word;
    std::string createdAt;
    std::string language; // kV2: ISO 639-1 code, "" = unspecified
};

struct Tag_t {
    ID_t        id = 0;
    std::string name;
};

// One block on a word's page.
// `content` is the block's payload.
// `pos` is the part of speech and is only meaningful for definition blocks.
// row/col/span describe its placement in the page grid.
struct ContentBlock_t {
    ID_t          id     = 0;
    ID_t          wordId = 0;
    ContentType_t type   = ContentType_t::Note;
    std::string   content;
    int           row     = 0;
    int           col     = 0;
    int           rowSpan = 1;
    int           colSpan = 1;
    std::string   pos;
};

// A directed relation from one word to another.
struct EntryRelation_t {
    ID_t        id             = 0;
    ID_t        wordId         = 0;
    ID_t        wordRelationId = 0; // the related word's id
    std::string relationType;
};

struct Deck_t {
    ID_t         id = 0;
    std::string  name;
    bool         bIsSmart   = false;
    FilterMode_t filterMode = FilterMode_t::And;
    std::string  createdAt;
    int          newCardsPerDay = 20;
    std::string  scheduler = "sm2";   // "sm2" or "fsrs"
    double       fsrsRetention = 0.9; // FSRS desired retention (0.7..0.97)
    std::string  fsrsWeights;         // JSON array of 19 weights, empty = defaults
};

// SM-2 scheduling state for one (deck, word) pair.
struct Review_t {
    ID_t          id           = 0;
    ID_t          deckId       = 0;
    ID_t          wordId       = 0;
    float         easeFactor   = 2.5f;
    std::uint16_t intervalDays = 1;
    std::uint16_t repetitions  = 0;
    std::uint16_t lapses       = 0;
    bool          isLeech      = false;
    int           clozeOrdinal = 0; // 0 = normal card; N = cloze deletion cN
    std::string   nextReviewDate;
    std::string   lastReviewDate;
};

// At-a-glance deck progress.
struct DeckStats_t {
    int         total = 0;
    int         due   = 0;
    std::string nextDue; // earliest upcoming review date, "" if none
};

// One day's review aggregate.
struct DailyStat_t {
    std::string date;
    int         count      = 0;
    double      avgQuality = 0.0;
};

struct DeckAnalytics_t {
    std::vector<DailyStat_t> daily;
    int                      totalReviews = 0;
    double                   retention    = 0.0; // fraction graded "remembered"
};

// Collection-wide study statistics, aggregated across every deck.
struct GlobalStats_t {
    std::vector<DailyStat_t> daily;              // per-day review counts (all decks)
    int                      totalReviews = 0;   // lifetime graded reviews
    int                      totalWords   = 0;   // entries in the collection
    int                      dueToday     = 0;   // cards due now or earlier
    int                      dueNext7Days = 0;   // cards becoming due within a week
    double                   retention    = 0.0; // fraction graded "remembered" (q>=2)
    int         currentStreakDays = 0; // consecutive days with >=1 review, ending today/yesterday
    int         longestStreakDays = 0; // best consecutive-day run ever
    int         reviewsToday      = 0; // reviews logged today
    int         leechCount        = 0; // cards currently flagged as leeches
    std::string firstReviewDate;       // ISO date of earliest review, "" if none
};

// One historical review event for a word (for per-word history charts).
struct EntryReviewEvent_t {
    std::int64_t reviewedAt   = 0; // epoch milliseconds
    int          quality      = 0;
    double       easeFactor   = 0.0;
    int          intervalDays = 0;
};

} // namespace Service
