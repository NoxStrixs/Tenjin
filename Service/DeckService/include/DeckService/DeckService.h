#pragma once

#include <DatabaseManager/DatabaseManager.h>

#include <memory>
#include <string>
#include <vector>

namespace Service {

struct ReviewSession_t {
    ID_t                  deckId = -1;
    std::vector<Review_t> queue;
    int                   currentIndex = 0;
    // When false, SubmitCard logs the review for stats but does NOT advance the
    // SRS schedule — used by cram / study-ahead filtered sessions so practice
    // doesn't disturb real scheduling. Normal due sessions leave this true.
    bool                  reschedule = true;
};

// Custom-study filter. Mode selects which cards; tag/language narrow them.
enum class StudyMode_t {
    Due = 0,      // normally-due cards (default review)
    Ahead = 1,    // cards due within the next few days, pulled early
    Cram = 2      // any matching cards regardless of schedule (pure practice)
};

struct StudyFilter_t {
    StudyMode_t          mode = StudyMode_t::Due;
    std::vector<ID_t>    tagIds;          // empty = any tag
    std::string          language;        // empty = any language
    ID_t                 deckId = -1;     // -1 = all decks
    int                  aheadDays = 3;   // for Ahead mode
    int                  limit = 100;     // cap the queue
};

class DeckService
{
public:
    explicit DeckService(std::shared_ptr<DatabaseManager> db);

    // Deck
    Result_t<Deck_t> CreateDeck(const std::string& name, bool isSmart, FilterMode_t mode);
    Result_t<Deck_t> GetDeck(ID_t deckId) const;
    Result_t<std::vector<Deck_t>> GetAllDecks() const;
    Result_t<bool>                DeleteDeck(ID_t deckId);
    Result_t<bool>                SetNewCardsPerDay(ID_t deckId, int perDay);
    Result_t<bool>                SetScheduler(ID_t deckId, const std::string& scheduler, double retention);

    // Bulk wipe + tag-impact query. Used by the Settings danger zone and
    // by the tag-delete confirmation popup (which warns the user when
    // deleting a tag would invalidate one or more smart-deck filters).
    Result_t<int>                 DeleteAllDecks();
    Result_t<std::vector<Deck_t>> GetSmartDecksUsingTag(ID_t tagId);

    // Manual
    Result_t<bool> AddEntryToDeck(ID_t deckId, ID_t wordId);
    Result_t<bool> RemoveEntryFromDeck(ID_t deckId, ID_t wordId);

    // Smart deck filters
    Result_t<bool>               AddTagFilter(ID_t deckId, ID_t tagId);
    Result_t<bool>               RemoveTagFilter(ID_t deckId, ID_t tagId);
    Result_t<std::vector<Tag_t>> GetTagFilters(ID_t deckId) const;

    // Resolves manual or smart deck membership to a concrete word list.
    Result_t<std::vector<Entry_t>>            GetEntriesForDeck(ID_t deckId) const;
    Result_t<DeckStats_t>                     GetDeckStats(ID_t deckId) const;
    Result_t<DeckAnalytics_t>                 GetDeckAnalytics(ID_t deckId) const;
    Result_t<std::vector<EntryReviewEvent_t>> GetEntryHistory(ID_t deckId, ID_t wordId) const;
    Result_t<GlobalStats_t>                   GetGlobalStats() const;

    // Review session
    Result_t<ReviewSession_t> StartSession(ID_t deckId);
    Result_t<ReviewSession_t> StartFilteredSession(const StudyFilter_t& filter);
    Result_t<Review_t>        SubmitCard(ReviewSession_t& session, int quality);
    bool                      IsComplete(const ReviewSession_t& session) const;
    const Review_t*           CurrentCard(const ReviewSession_t& session) const;

private:
    std::shared_ptr<DatabaseManager> m_db;
};

} // namespace Service
