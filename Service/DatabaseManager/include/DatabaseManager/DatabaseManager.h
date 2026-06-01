#pragma once

#include <DatabaseManager/Types.h>

#include <QSqlDatabase>
#include <QString>

#include <string>
#include <string_view>
#include <vector>

namespace Service {

// Owns a single SQLite connection and every query against it. Created once and
// shared (std::shared_ptr) by the service layer. The schema is created/migrated
// in the constructor; the connection is torn down in the destructor.
//
// NOTE: this is the monolith targeted for the repository split — Word / Tag /
// Content / Search / Relation / Deck / Review-analytics / Import-export. The
// declaration below mirrors the current implementation 1:1 so the tree compiles
// today; the split happens on top of this baseline.
class DatabaseManager
{
public:
    // `filepath` must end in ".db". Throws std::runtime_error on a bad path or
    // if the database can't be opened / migrated.
    explicit DatabaseManager(const std::string& filepath);
    ~DatabaseManager();

    // Non-copyable: each instance owns a uniquely-named QSqlDatabase connection
    // that is removed in the destructor.
    DatabaseManager(const DatabaseManager&)            = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    // ── Word ─────────────────────────────────────────────────────────────────
    Result_t<Entry_t>              AddEntry(const std::string& word);
    Result_t<Entry_t>              GetEntry(const std::string& word);
    Result_t<std::vector<Entry_t>> GetAllEntries();
    Result_t<bool>                DeleteEntry(ID_t id);

    // ── Tag ──────────────────────────────────────────────────────────────────
    Result_t<Tag_t>              AddTag(const std::string& name);
    Result_t<Tag_t>              GetTag(std::string_view name);
    Result_t<std::vector<Tag_t>> GetAllTags();
    Result_t<bool>               DeleteTag(ID_t id);
    Result_t<bool>               RenameTag(ID_t id, const std::string& name);

    Result_t<bool>                AddTagToEntry(ID_t wordId, ID_t tagId);
    Result_t<bool>                RemoveTagFromEntry(ID_t wordId, ID_t tagId);
    Result_t<std::vector<Tag_t>>  GetTagsForEntry(ID_t wordId);
    Result_t<std::vector<Entry_t>> GetEntriesForTag(ID_t tagId);

    // ── Content blocks ───────────────────────────────────────────────────────
    Result_t<ContentBlock_t>              AddContentBlock(const ContentBlock_t& block);
    Result_t<ContentBlock_t>              UpdateContentBlock(const ContentBlock_t& block);
    Result_t<bool>                        DeleteContentBlock(ID_t id);
    Result_t<std::vector<ContentBlock_t>> GetContentForEntry(ID_t wordId);
    Result_t<bool> SaveContentLayout(const std::vector<ContentBlock_t>& blocks);

    // ── Search (FTS5 + substring) ──────────────────────────────────────────────
    Result_t<std::vector<Entry_t>>         SearchEntries(const std::string& query);
    Result_t<std::vector<ContentBlock_t>> SearchContent(const std::string& query);
    Result_t<std::vector<Entry_t>>         SearchEntriesByName(const std::string& substring);
    Result_t<std::vector<Tag_t>>          SearchTagsByName(const std::string& substring);
    Result_t<std::vector<Entry_t>>         SearchEntriesByContent(const std::string& substring);

    // ── Relations ──────────────────────────────────────────────────────────────
    Result_t<EntryRelation_t> AddEntryRelation(ID_t wordId, ID_t relatedId, const std::string& type);
    Result_t<bool>           RemoveEntryRelation(ID_t id);
    Result_t<std::vector<EntryRelation_t>> GetRelationsForEntry(ID_t wordId);

    // ── Decks ────────────────────────────────────────────────────────────────
    Result_t<Deck_t>              AddDeck(const std::string& name, bool isSmart, FilterMode_t mode);
    Result_t<Deck_t>              GetDeck(ID_t id);
    Result_t<std::vector<Deck_t>> GetAllDecks();
    Result_t<bool>                DeleteDeck(ID_t id);

    Result_t<bool> AddEntryToDeck(ID_t deckId, ID_t wordId);
    Result_t<bool> RemoveEntryFromDeck(ID_t deckId, ID_t wordId);

    Result_t<bool>               AddTagFilterToDeck(ID_t deckId, ID_t tagId);
    Result_t<bool>               RemoveTagFilterFromDeck(ID_t deckId, ID_t tagId);
    Result_t<std::vector<Tag_t>> GetTagFiltersForDeck(ID_t deckId);

    Result_t<std::vector<Entry_t>> GetEntriesForDeck(ID_t deckId);
    Result_t<std::vector<Entry_t>> GetEntriesByTags(const std::vector<ID_t>& tagIds,
                                                 FilterMode_t             mode);

    // ── Reviews + analytics ────────────────────────────────────────────────────
    Result_t<Review_t>                       InitReview(ID_t deckId, ID_t wordId);
    Result_t<Review_t>                       SubmitReview(ID_t deckId, ID_t wordId, int quality);
    Result_t<std::vector<Review_t>>          GetDueReviews(ID_t deckId);
    Result_t<DeckStats_t>                    GetDeckStats(ID_t deckId);
    Result_t<DeckAnalytics_t>                GetDeckAnalytics(ID_t deckId);
    Result_t<std::vector<EntryReviewEvent_t>> GetEntryHistory(ID_t deckId, ID_t wordId);

    // ── Import / export (whole collection, JSON) ───────────────────────────────
    Result_t<bool> ExportToJson(const QString& path);
    Result_t<bool> ImportFromJson(const QString& path);

private:
    // Assigns a fresh guid to any pre-existing row that lacks one (called once
    // at construction, after the column migrations).
    void backfillGuids();

    QSqlDatabase m_db;
};

} // namespace Service
