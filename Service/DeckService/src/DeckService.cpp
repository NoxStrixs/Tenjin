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

Result_t<bool> DeckService::SetNewCardsPerDay(ID_t deckId, int perDay)
{
    return m_db->SetDeckNewCardsPerDay(deckId, perDay);
}

Result_t<bool> DeckService::SetScheduler(ID_t deckId, const std::string& scheduler,
                                         double retention)
{
    return m_db->SetDeckScheduler(deckId, scheduler, retention);
}

Result_t<std::vector<Fsrs::CardHistory>> DeckService::GetReviewSequencesFor(ID_t deckId)
{
    return m_db->GetReviewSequences(deckId);
}

Result_t<bool> DeckService::SaveDeckWeights(ID_t deckId,
                                            const std::array<double, 19>& weights)
{
    std::string json = "[";
    for (size_t i = 0; i < weights.size(); ++i) {
        if (i) json += ",";
        json += std::to_string(weights[i]);
    }
    json += "]";
    return m_db->SetDeckWeights(deckId, json);
}

Result_t<bool> DeckService::AddEntryToDeck(ID_t deckId, ID_t wordId)
{
    return m_db->AddEntryToDeck(deckId, wordId);
}

Result_t<bool> DeckService::RemoveEntryFromDeck(ID_t deckId, ID_t wordId)
{
    return m_db->RemoveEntryFromDeck(deckId, wordId);
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

Result_t<std::vector<Entry_t>> DeckService::GetEntriesForDeck(ID_t deckId) const
{
    return m_db->GetEntriesForDeck(deckId);
}

Result_t<DeckStats_t> DeckService::GetDeckStats(ID_t deckId) const
{
    return m_db->GetDeckStats(deckId);
}

Result_t<DeckAnalytics_t> DeckService::GetDeckAnalytics(ID_t deckId) const
{
    return m_db->GetDeckAnalytics(deckId);
}

Result_t<GlobalStats_t> DeckService::GetGlobalStats() const
{
    return m_db->GetGlobalStats();
}

Result_t<std::vector<EntryReviewEvent_t>> DeckService::GetEntryHistory(ID_t deckId,
                                                                       ID_t wordId) const
{
    return m_db->GetEntryHistory(deckId, wordId);
}

Result_t<ReviewSession_t> DeckService::StartSession(ID_t deckId)
{
    auto wordsResult = m_db->GetEntriesForDeck(deckId);
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

Result_t<ReviewSession_t> DeckService::StartFilteredSession(const StudyFilter_t& filter)
{
    // Ensure review rows exist for candidate entries so filtered study can
    // include never-reviewed cards. For a specific deck we can init its entries;
    // for all-decks we rely on rows already created by prior deck sessions.
    if (filter.deckId >= 0) {
        auto wordsResult = m_db->GetEntriesForDeck(filter.deckId);
        if (wordsResult) {
            for (const auto& word : *wordsResult)
                m_db->InitReview(filter.deckId, word.id);
        }
    }

    auto rows = m_db->GetFilteredReviews(
        static_cast<int>(filter.mode), filter.tagIds, filter.language,
        filter.deckId, filter.aheadDays, filter.limit);
    if (!rows)
        return std::unexpected(rows.error());

    // Cram and Ahead are pure practice — do not advance the SRS schedule. Only
    // a normal Due session reschedules.
    const bool reschedule = (filter.mode == StudyMode_t::Due);

    return ReviewSession_t{.deckId       = filter.deckId,
                           .queue        = std::move(*rows),
                           .currentIndex = 0,
                           .reschedule   = reschedule};
}

Result_t<Review_t> DeckService::SubmitCard(ReviewSession_t& session, int quality)
{
    if (IsComplete(session))
        return std::unexpected("Session complete.");

    const auto& current = session.queue[session.currentIndex];

    if (session.reschedule) {
        auto result = m_db->SubmitReview(session.deckId >= 0 ? session.deckId
                                                             : current.deckId,
                                         current.wordId, quality, current.clozeOrdinal);
        if (result)
            session.currentIndex++;
        return result;
    }

    // Practice mode: log the review for stats but do NOT change the schedule.
    auto logged = m_db->LogReviewOnly(current.deckId, current.wordId, quality,
                                      current.clozeOrdinal);
    if (logged)
        session.currentIndex++;
    return logged;
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

Result_t<int> DeckService::DeleteAllDecks()
{
    return m_db->DeleteAllDecks();
}
Result_t<std::vector<Deck_t>> DeckService::GetSmartDecksUsingTag(ID_t tagId)
{
    return m_db->GetSmartDecksUsingTag(tagId);
}

} // namespace Service
