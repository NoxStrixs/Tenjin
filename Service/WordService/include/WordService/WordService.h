#pragma once

#include <DatabaseManager/DatabaseManager.h>

#include <QString>

#include <memory>
#include <string>
#include <vector>

namespace Service {

class WordService
{
public:
    // Bundles arguments to Search() so callers don't have to remember positional
    // order. tagIds empty + query empty returns all words.
    struct SearchParams_t {
        std::string       query;
        std::vector<ID_t> tagIds;
        FilterMode_t      tagMode = FilterMode_t::And;
    };

    explicit WordService(std::shared_ptr<DatabaseManager> db);

    // ── Word ─────────────────────────────────────────────────────────────────
    Result_t<Word_t>              CreateWord(const std::string& word);
    Result_t<Word_t>              GetWord(const std::string& word) const;
    Result_t<std::vector<Word_t>> GetAllWords() const;
    Result_t<bool>                DeleteWord(ID_t wordId);

    // ── Content Blocks ────────────────────────────────────────────────────────
    Result_t<ContentBlock_t>              AddContentBlock(const ContentBlock_t& block);
    Result_t<ContentBlock_t>              UpdateContentBlock(const ContentBlock_t& block);
    Result_t<bool>                        DeleteContentBlock(ID_t id);
    Result_t<std::vector<ContentBlock_t>> GetContentForWord(ID_t wordId) const;
    Result_t<bool> SaveContentLayout(const std::vector<ContentBlock_t>& blocks);

    // ── Import / Export (whole collection) ────────────────────────────────────
    Result_t<bool> ExportToJson(const QString& path);
    Result_t<bool> ImportFromJson(const QString& path);

    // ── Tags ─────────────────────────────────────────────────────────────────
    Result_t<Tag_t> CreateTag(const std::string& name);
    Result_t<Tag_t> GetTag(const std::string& name) const;
    // Returns the existing tag with this name, or creates it if absent.
    Result_t<Tag_t>              GetOrCreateTag(const std::string& name);
    Result_t<std::vector<Tag_t>> GetAllTags() const;
    Result_t<bool>               DeleteTag(ID_t tagId);
    // Rename a tag. Fails on empty or duplicate name (UNIQUE constraint).
    Result_t<bool>               RenameTag(ID_t tagId, const std::string& name);

    Result_t<bool>                AddTagToWord(ID_t wordId, ID_t tagId);
    Result_t<bool>                RemoveTagFromWord(ID_t wordId, ID_t tagId);
    Result_t<std::vector<Tag_t>>  GetTagsForWord(ID_t wordId) const;
    Result_t<std::vector<Word_t>> GetWordsForTag(ID_t tagId) const;

    // ── Relations ────────────────────────────────────────────────────────────
    Result_t<WordRelation_t> AddRelation(ID_t wordId, ID_t relatedId, const std::string& type);
    Result_t<bool>           RemoveRelation(ID_t relationId);
    Result_t<std::vector<WordRelation_t>> GetRelationsForWord(ID_t wordId) const;

    // ── Search ───────────────────────────────────────────────────────────────
    Result_t<std::vector<Word_t>> Search(const SearchParams_t& params) const;

    // Dropdown search: substring match on word names; optionally also match
    // words by content-block text.
    Result_t<std::vector<Word_t>> SearchWordsByName(const std::string& substring,
                                                    bool               includeContent) const;
    // Substring match on tag names (for the dropdown's tag suggestions).
    Result_t<std::vector<Tag_t>> SearchTagsByName(const std::string& substring) const;

private:
    std::shared_ptr<DatabaseManager> m_db;
};

} // namespace Service
