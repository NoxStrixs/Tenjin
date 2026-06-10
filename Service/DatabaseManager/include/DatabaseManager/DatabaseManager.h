#pragma once

#include <DatabaseManager/Types.h>

#include <QSqlDatabase>
#include <QString>

#include <string>
#include <string_view>
#include <vector>

namespace Service {
class DatabaseManager
{
public:
    // `filepath` must end in ".db". Throws std::runtime_error on a bad path or
    // if the database can't be opened / migrated.
    explicit DatabaseManager(const std::string& filepath);
    ~DatabaseManager();

    DatabaseManager(const DatabaseManager&)            = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;

    // Word
    Result_t<Entry_t> AddEntry(const std::string& word);
    Result_t<Entry_t> GetEntry(const std::string& word);
    // By-id getter — used to surface the title of a related entry returned
    // from GetRelationsForEntry (which only carries IDs).
    Result_t<Entry_t>              GetEntryById(ID_t id);
    Result_t<std::vector<Entry_t>> GetAllEntries();
    Result_t<bool>                 DeleteEntry(ID_t id);

    // UPDATE entry SET title = :title WHERE id = :id; — surfaces the
    // unique-constraint violation when another entry already has that
    // title so the UI can show a friendly error.
    Result_t<bool> RenameEntry(ID_t id, const std::string& newName);

    // Bulk wipes — power the Settings "Danger zone". FK cascades clean up
    // dependent rows (entry_tag / entry_relation / content / deck_entry).
    // Returns count of rows deleted from the primary table.
    Result_t<int> DeleteAllEntries();
    Result_t<int> DeleteAllTags();
    Result_t<int> DeleteAllDecks();

    // Lists smart decks that filter on the given tag — used when deleting
    // a tag so the UI can warn the user that the affected decks will lose
    // a filter and may end up empty.
    Result_t<std::vector<Deck_t>> GetSmartDecksUsingTag(ID_t tagId);

    // kV2 multi-language. Per-entry language codes (ISO 639-1) drive a
    // simple "show only this language" filter at the EntryViewModel layer.
    Result_t<bool>                     SetEntryLanguage(ID_t id, const std::string& code);
    Result_t<std::vector<std::string>> GetAllLanguages();

    // Tag
    Result_t<Tag_t>              AddTag(const std::string& name);
    Result_t<Tag_t>              GetTag(std::string_view name);
    Result_t<std::vector<Tag_t>> GetAllTags();
    Result_t<bool>               DeleteTag(ID_t id);
    Result_t<bool>               RenameTag(ID_t id, const std::string& name);

    Result_t<bool>                 AddTagToEntry(ID_t wordId, ID_t tagId);
    Result_t<bool>                 RemoveTagFromEntry(ID_t wordId, ID_t tagId);
    Result_t<std::vector<Tag_t>>   GetTagsForEntry(ID_t wordId);
    Result_t<std::vector<Entry_t>> GetEntriesForTag(ID_t tagId);

    // Content blocks
    Result_t<ContentBlock_t>              AddContentBlock(const ContentBlock_t& block);
    Result_t<ContentBlock_t>              UpdateContentBlock(const ContentBlock_t& block);
    Result_t<bool>                        DeleteContentBlock(ID_t id);
    Result_t<std::vector<ContentBlock_t>> GetContentForEntry(ID_t wordId);
    Result_t<bool> SaveContentLayout(const std::vector<ContentBlock_t>& blocks);

    // Count how many content blocks (across all entries, all types)
    // store the given string in their content column. Used by the
    // media cleanup path to decide whether removing a block leaves
    // the underlying media file orphaned.
    Result_t<int> CountMediaReferences(const std::string& storedPath) const;

    // Search (FTS5 + substring)
    Result_t<std::vector<Entry_t>>        SearchEntries(const std::string& query);
    Result_t<std::vector<ContentBlock_t>> SearchContent(const std::string& query);
    Result_t<std::vector<Entry_t>>        SearchEntriesByName(const std::string& substring);
    Result_t<std::vector<Tag_t>>          SearchTagsByName(const std::string& substring);
    Result_t<std::vector<Entry_t>>        SearchEntriesByContent(const std::string& substring);

    // Relations
    Result_t<EntryRelation_t>
                   AddEntryRelation(ID_t wordId, ID_t relatedId, const std::string& type);
    Result_t<bool> RemoveEntryRelation(ID_t id);
    Result_t<std::vector<EntryRelation_t>> GetRelationsForEntry(ID_t wordId);

    // Decks
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

    // Reviews + analytics
    Result_t<Review_t>                        InitReview(ID_t deckId, ID_t wordId);
    Result_t<Review_t>                        SubmitReview(ID_t deckId, ID_t wordId, int quality);
    Result_t<std::vector<Review_t>>           GetDueReviews(ID_t deckId);
    Result_t<DeckStats_t>                     GetDeckStats(ID_t deckId);
    Result_t<DeckAnalytics_t>                 GetDeckAnalytics(ID_t deckId);
    Result_t<std::vector<EntryReviewEvent_t>> GetEntryHistory(ID_t deckId, ID_t wordId);

    // Import / export
    Result_t<bool> ExportToJson(const QString& path);
    Result_t<bool> ImportFromJson(const QString& path);

private:
    // Assigns a fresh guid to any pre-existing row that lacks one.
    void backfillGuids();

    QSqlDatabase m_db;
};

} // namespace Service
