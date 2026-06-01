#include <DeckService/DeckService.h>

namespace Service {

DeckService::DeckService(std::shared_ptr<DatabaseManager> db) : m_db(std::move(db)) {}

Result_t<Deck_t> DeckService::CreateDeck(const std::string& name, bool isSmart, FilterMode_t mode)
{
    if (name.empty())
        return std::unexpected("Deck name cannot be empty.");
    return m_db->AddDeck(name, isSmart, mode);
}

Result_t<Deck_t> DeckService::GetDeck(ID_t deckId) const
{
    return m_db->GetDeck(deckId);
}

Result_t<std::vector<Deck_t>> DeckService::GetAllDecks() const
{
    return m_db->GetAllDecks();
}

Result_t<bool> DeckService::DeleteDeck(ID_t deckId)
{
    return m_db->DeleteDeck(deckId);
}

Result_t<bool> DeckService::AddWordToDeck(ID_t deckId, ID_t wordId)
{
    return m_db->AddWordToDeck(deckId, wordId);
}

Result_t<bool> DeckService::RemoveWordFromDeck(ID_t deckId, ID_t wordId)
{
    return m_db->RemoveWordFromDeck(deckId, wordId);
}

Result_t<bool> DeckService::AddTagFilter(ID_t deckId, ID_t tagId)
{
    return m_db->AddTagFilterToDeck(deckId, tagId);
}

Result_t<bool> DeckService::RemoveTagFilter(ID_t deckId, ID_t tagId)
{
    return m_db->RemoveTagFilterFromDeck(deckId, tagId);
}

Result_t<std::vector<Tag_t>> DeckService::GetTagFilters(ID_t deckId) const
{
    return m_db->GetTagFiltersForDeck(deckId);
}

Result_t<std::vector<Word_t>> DeckService::GetWordsForDeck(ID_t deckId) const
{
    return m_db->GetWordsForDeck(deckId);
}

Result_t<DeckStats_t> DeckService::GetDeckStats(ID_t deckId) const
{
    return m_db->GetDeckStats(deckId);
}

Result_t<DeckAnalytics_t> DeckService::GetDeckAnalytics(ID_t deckId) const
{
    return m_db->GetDeckAnalytics(deckId);
}

Result_t<std::vector<WordReviewEvent_t>> DeckService::GetWordHistory(ID_t deckId, ID_t wordId) const
{
    return m_db->GetWordHistory(deckId, wordId);
}

Result_t<ReviewSession_t> DeckService::StartSession(ID_t deckId)
{
    auto wordsResult = m_db->GetWordsForDeck(deckId);
    if (!wordsResult)
        return std::unexpected(wordsResult.error());

    // Ensure review rows exist for all words in deck
    for (const auto& word : *wordsResult) {
        auto init = m_db->InitReview(deckId, word.id);
        if (!init)
            return std::unexpected(init.error());
    }

    auto dueResult = m_db->GetDueReviews(deckId);
    if (!dueResult)
        return std::unexpected(dueResult.error());

    return ReviewSession_t{.deckId = deckId, .queue = std::move(*dueResult), .currentIndex = 0};
}

Result_t<Review_t> DeckService::SubmitCard(ReviewSession_t& session, int quality)
{
    if (IsComplete(session))
        return std::unexpected("Session complete.");

    const auto& current = session.queue[session.currentIndex];
    auto        result  = m_db->SubmitReview(session.deckId, current.wordId, quality);
    if (result)
        session.currentIndex++;
    return result;
}

bool DeckService::IsComplete(const ReviewSession_t& session) const
{
    return session.currentIndex >= static_cast<int>(session.queue.size());
}

const Review_t* DeckService::CurrentCard(const ReviewSession_t& session) const
{
    if (IsComplete(session))
        return nullptr;
    return &session.queue[session.currentIndex];
}

} // namespace Service
