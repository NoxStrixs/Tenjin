#include <WordService/WordService.h>

namespace Service {

WordService::WordService(std::shared_ptr<DatabaseManager> db) : m_db(std::move(db)) {}

Result_t<Word_t> WordService::CreateWord(const std::string& word)
{
    if (word.empty())
        return std::unexpected("Word cannot be empty.");
    return m_db->AddWord(word);
}

Result_t<Word_t> WordService::GetWord(const std::string& word) const
{
    return m_db->GetWord(word);
}

Result_t<std::vector<Word_t>> WordService::GetAllWords() const
{
    return m_db->GetAllWords();
}

Result_t<bool> WordService::DeleteWord(ID_t wordId)
{
    return m_db->DeleteWord(wordId);
}

Result_t<ContentBlock_t> WordService::AddContentBlock(const ContentBlock_t& block)
{
    return m_db->AddContentBlock(block);
}

Result_t<ContentBlock_t> WordService::UpdateContentBlock(const ContentBlock_t& block)
{
    return m_db->UpdateContentBlock(block);
}

Result_t<bool> WordService::DeleteContentBlock(ID_t id)
{
    return m_db->DeleteContentBlock(id);
}

Result_t<std::vector<ContentBlock_t>> WordService::GetContentForWord(ID_t wordId) const
{
    return m_db->GetContentForWord(wordId);
}

Result_t<bool> WordService::SaveContentLayout(const std::vector<ContentBlock_t>& blocks)
{
    return m_db->SaveContentLayout(blocks);
}

Result_t<bool> WordService::ExportToJson(const QString& path)
{
    return m_db->ExportToJson(path);
}

Result_t<bool> WordService::ImportFromJson(const QString& path)
{
    return m_db->ImportFromJson(path);
}

Result_t<Tag_t> WordService::CreateTag(const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    return m_db->AddTag(name);
}

Result_t<Tag_t> WordService::GetTag(const std::string& name) const
{
    return m_db->GetTag(name);
}

Result_t<Tag_t> WordService::GetOrCreateTag(const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    if (auto existing = m_db->GetTag(name))
        return existing;
    return m_db->AddTag(name);
}

Result_t<std::vector<Tag_t>> WordService::GetAllTags() const
{
    return m_db->GetAllTags();
}

Result_t<bool> WordService::DeleteTag(ID_t tagId)
{
    return m_db->DeleteTag(tagId);
}

Result_t<bool> WordService::RenameTag(ID_t tagId, const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    return m_db->RenameTag(tagId, name);
}

Result_t<bool> WordService::AddTagToWord(ID_t wordId, ID_t tagId)
{
    return m_db->AddTagToWord(wordId, tagId);
}

Result_t<bool> WordService::RemoveTagFromWord(ID_t wordId, ID_t tagId)
{
    return m_db->RemoveTagFromWord(wordId, tagId);
}

Result_t<std::vector<Tag_t>> WordService::GetTagsForWord(ID_t wordId) const
{
    return m_db->GetTagsForWord(wordId);
}

Result_t<std::vector<Word_t>> WordService::GetWordsForTag(ID_t tagId) const
{
    return m_db->GetWordsForTag(tagId);
}

Result_t<WordRelation_t>
WordService::AddRelation(ID_t wordId, ID_t relatedId, const std::string& type)
{
    return m_db->AddWordRelation(wordId, relatedId, type);
}

Result_t<bool> WordService::RemoveRelation(ID_t relationId)
{
    return m_db->RemoveWordRelation(relationId);
}

Result_t<std::vector<WordRelation_t>> WordService::GetRelationsForWord(ID_t wordId) const
{
    return m_db->GetRelationsForWord(wordId);
}

Result_t<std::vector<Word_t>> WordService::Search(const SearchParams_t& params) const
{
    if (params.query.empty() && params.tagIds.empty())
        return m_db->GetAllWords();

    if (params.query.empty())
        return m_db->GetWordsByTags(params.tagIds, params.tagMode);

    auto ftsResult = m_db->SearchWords(params.query);
    if (!ftsResult)
        return std::unexpected(ftsResult.error());

    if (params.tagIds.empty())
        return ftsResult;

    // Intersect FTS results with tag-filtered words
    auto tagResult = m_db->GetWordsByTags(params.tagIds, params.tagMode);
    if (!tagResult)
        return std::unexpected(tagResult.error());

    std::vector<Word_t> intersection;
    for (const auto& w : *ftsResult) {
        for (const auto& tw : *tagResult) {
            if (tw.id == w.id) {
                intersection.push_back(w);
                break;
            }
        }
    }
    return intersection;
}

Result_t<std::vector<Word_t>> WordService::SearchWordsByName(const std::string& substring,
                                                             bool includeContent) const
{
    if (substring.empty())
        return m_db->GetAllWords();

    auto byName = m_db->SearchWordsByName(substring);
    if (!byName)
        return byName;

    if (!includeContent)
        return byName;

    auto byContent = m_db->SearchWordsByContent(substring);
    if (!byContent)
        return byContent;

    // Merge unique by id (name matches first, then any new content matches).
    std::vector<Word_t> merged = *byName;
    for (const auto& cw : *byContent) {
        bool seen = false;
        for (const auto& w : merged)
            if (w.id == cw.id) {
                seen = true;
                break;
            }
        if (!seen)
            merged.push_back(cw);
    }
    return merged;
}

Result_t<std::vector<Tag_t>> WordService::SearchTagsByName(const std::string& substring) const
{
    if (substring.empty())
        return m_db->GetAllTags();
    return m_db->SearchTagsByName(substring);
}

} // namespace Service
