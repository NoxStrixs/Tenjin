#pragma once

#include <cstdint>
#include <expected>
#include <string>
#include <string_view>
#include <vector>

namespace Service {

// ── Core aliases ─────────────────────────────────────────────────────────────
// Row identifier. SQLite INTEGER PRIMARY KEY is a signed 64-bit value, read
// back through QVariant::toLongLong().
using ID_t = std::int64_t;

// Every fallible service/database call returns one of these: the value on
// success, or a human-readable message on failure.
template <typename T>
using Result_t = std::expected<T, std::string>;

// ── Enums ────────────────────────────────────────────────────────────────────
// Kind of a content block on an entry page. Stored as the INTEGER `type`
// column in entry_content, and (since schema v3) also as the stable string
// `kind` column. New code should prefer the string kind: adding a kind needs
// only a new enumerator + entry in the kind<->string maps below, and a View
// delegate — no schema change.
enum class ContentType_t : int {
    Definition = 0,
    Media      = 1,
    Note       = 2,
    Divider    = 3,
    Formula    = 4, // LaTeX payload, rendered read-only (schema v3+)
};

// Stable string identifier for a block kind (matches entry_content.kind and the
// View-side delegate registry). Unknown values map to "note".
inline std::string ToKindString(ContentType_t t)
{
    switch (t) {
    case ContentType_t::Definition: return "definition";
    case ContentType_t::Media:      return "media";
    case ContentType_t::Note:       return "note";
    case ContentType_t::Divider:    return "divider";
    case ContentType_t::Formula:    return "formula";
    }
    return "note";
}

inline ContentType_t FromKindString(std::string_view s)
{
    if (s == "definition") return ContentType_t::Definition;
    if (s == "media")      return ContentType_t::Media;
    if (s == "divider")    return ContentType_t::Divider;
    if (s == "formula")    return ContentType_t::Formula;
    return ContentType_t::Note;
}

// How a smart deck combines its tag filters.
enum class FilterMode_t {
    And,
    Or,
};

// ── Value types ──────────────────────────────────────────────────────────────
struct Word_t {
    ID_t        id = 0;
    std::string word;
    std::string createdAt;
};

struct Tag_t {
    ID_t        id = 0;
    std::string name;
};

// One block on a word's page. `content` is the block's payload (definition
// text, note text, or a media path/URL); `pos` is the part of speech and is
// only meaningful for definition blocks. row/col/span describe its placement
// in the page grid.
struct ContentBlock_t {
    ID_t          id      = 0;
    ID_t          wordId  = 0;
    ContentType_t type    = ContentType_t::Note;
    std::string   content;
    int           row     = 0;
    int           col     = 0;
    int           rowSpan = 1;
    int           colSpan = 1;
    std::string   pos;
};

// A directed relation from one word to another (synonym, antonym, …).
struct WordRelation_t {
    ID_t        id             = 0;
    ID_t        wordId         = 0;
    ID_t        wordRelationId = 0; // the related word's id
    std::string relationType;
};

struct Deck_t {
    ID_t         id         = 0;
    std::string  name;
    bool         bIsSmart   = false;
    FilterMode_t filterMode = FilterMode_t::And;
    std::string  createdAt;
};

// SM-2 scheduling state for one (deck, word) pair.
struct Review_t {
    ID_t        id           = 0;
    ID_t        deckId       = 0;
    ID_t        wordId       = 0;
    float       easeFactor   = 2.5f;
    std::uint16_t intervalDays = 1;
    std::uint16_t repetitions  = 0;
    std::string nextReviewDate;
    std::string lastReviewDate;
};

// At-a-glance deck progress.
struct DeckStats_t {
    int         total = 0;
    int         due   = 0;
    std::string nextDue; // earliest upcoming review date, "" if none
};

// One day's review aggregate (for charts). Built positionally:
// { date, count, avgQuality }.
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

// One historical review event for a word (for per-word history charts). Built
// positionally: { reviewedAt, quality, easeFactor, intervalDays }.
struct WordReviewEvent_t {
    std::int64_t reviewedAt   = 0; // epoch milliseconds
    int          quality      = 0;
    double       easeFactor   = 0.0;
    int          intervalDays = 0;
};

} // namespace Service
