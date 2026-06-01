#pragma once

#include <DatabaseManager/DatabaseManager.h>

#include <memory>
#include <string>
#include <vector>

namespace Service {

// In-memory state for an active review session. Held by the caller (typically
// a ViewModel) and threaded through SubmitCard()/IsComplete()/CurrentCard().
struct ReviewSession_t {
    ID_t                  deckId = -1;
    std::vector<Review_t> queue;
    int                   currentIndex = 0;
};

class DeckService
{
public:
    explicit DeckService(std::shared_ptr<DatabaseManager> db);

    // ── Deck CRUD ────────────────────────────────────────────────────────────
    Result_t<Deck_t> CreateDeck(const std::string& name, bool isSmart, FilterMode_t mode);
    Result_t<Deck_t> GetDeck(ID_t deckId) const;
    Result_t<std::vector<Deck_t>> GetAllDecks() const;
    Result_t<bool>                DeleteDeck(ID_t deckId);

    // ── Manual decks ─────────────────────────────────────────────────────────
    Result_t<bool> AddWordToDeck(ID_t deckId, ID_t wordId);
    Result_t<bool> RemoveWordFromDeck(ID_t deckId, ID_t wordId);

    // ── Smart deck filters ───────────────────────────────────────────────────
    Result_t<bool>               AddTagFilter(ID_t deckId, ID_t tagId);
    Result_t<bool>               RemoveTagFilter(ID_t deckId, ID_t tagId);
    Result_t<std::vector<Tag_t>> GetTagFilters(ID_t deckId) const;

    // Resolves manual or smart deck membership to a concrete word list.
    Result_t<std::vector<Word_t>>            GetWordsForDeck(ID_t deckId) const;
    Result_t<DeckStats_t>                    GetDeckStats(ID_t deckId) const;
    Result_t<DeckAnalytics_t>                GetDeckAnalytics(ID_t deckId) const;
    Result_t<std::vector<WordReviewEvent_t>> GetWordHistory(ID_t deckId, ID_t wordId) const;

    // ── Review session ───────────────────────────────────────────────────────
    Result_t<ReviewSession_t> StartSession(ID_t deckId);
    Result_t<Review_t>        SubmitCard(ReviewSession_t& session, int quality);
    bool                      IsComplete(const ReviewSession_t& session) const;
    const Review_t*           CurrentCard(const ReviewSession_t& session) const;

private:
    std::shared_ptr<DatabaseManager> m_db;
};

} // namespace Service
