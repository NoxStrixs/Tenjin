#include <EntryService/EntryService.h>

namespace Service {

EntryService::EntryService(std::shared_ptr<DatabaseManager> db) : m_db(std::move(db)) {}

Result_t<Entry_t> EntryService::CreateWord(const std::string& word)
{
    if (word.empty())
        return std::unexpected("Word cannot be empty.");
    return m_db->AddEntry(word);
}

Result_t<Entry_t> EntryService::GetEntry(const std::string& word) const
{
    return m_db->GetEntry(word);
}

Result_t<Entry_t> EntryService::GetEntryById(ID_t id) const
{
    return m_db->GetEntryById(id);
}

Result_t<std::vector<Entry_t>> EntryService::GetAllEntries() const
{
    return m_db->GetAllEntries();
}

Result_t<bool> EntryService::DeleteEntry(ID_t wordId)
{
    return m_db->DeleteEntry(wordId);
}

Result_t<ContentBlock_t> EntryService::AddContentBlock(const ContentBlock_t& block)
{
    return m_db->AddContentBlock(block);
}

Result_t<ContentBlock_t> EntryService::UpdateContentBlock(const ContentBlock_t& block)
{
    return m_db->UpdateContentBlock(block);
}

Result_t<bool> EntryService::DeleteContentBlock(ID_t id)
{
    return m_db->DeleteContentBlock(id);
}

Result_t<std::vector<ContentBlock_t>> EntryService::GetContentForEntry(ID_t wordId) const
{
    return m_db->GetContentForEntry(wordId);
}

Result_t<bool> EntryService::SaveContentLayout(const std::vector<ContentBlock_t>& blocks)
{
    return m_db->SaveContentLayout(blocks);
}

Result_t<bool> EntryService::ExportToJson(const QString& path)
{
    return m_db->ExportToJson(path);
}

Result_t<bool> EntryService::ImportFromJson(const QString& path)
{
    return m_db->ImportFromJson(path);
}

Result_t<Tag_t> EntryService::CreateTag(const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    return m_db->AddTag(name);
}

Result_t<Tag_t> EntryService::GetTag(const std::string& name) const
{
    return m_db->GetTag(name);
}

Result_t<Tag_t> EntryService::GetOrCreateTag(const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    if (auto existing = m_db->GetTag(name))
        return existing;
    return m_db->AddTag(name);
}

Result_t<std::vector<Tag_t>> EntryService::GetAllTags() const
{
    return m_db->GetAllTags();
}

Result_t<bool> EntryService::DeleteTag(ID_t tagId)
{
    return m_db->DeleteTag(tagId);
}

Result_t<bool> EntryService::RenameTag(ID_t tagId, const std::string& name)
{
    if (name.empty())
        return std::unexpected("Tag name cannot be empty.");
    return m_db->RenameTag(tagId, name);
}

Result_t<bool> EntryService::AddTagToEntry(ID_t wordId, ID_t tagId)
{
    return m_db->AddTagToEntry(wordId, tagId);
}

Result_t<bool> EntryService::RemoveTagFromEntry(ID_t wordId, ID_t tagId)
{
    return m_db->RemoveTagFromEntry(wordId, tagId);
}

Result_t<std::vector<Tag_t>> EntryService::GetTagsForEntry(ID_t wordId) const
{
    return m_db->GetTagsForEntry(wordId);
}

Result_t<std::vector<Entry_t>> EntryService::GetEntriesForTag(ID_t tagId) const
{
    return m_db->GetEntriesForTag(tagId);
}

Result_t<EntryRelation_t>
EntryService::AddRelation(ID_t wordId, ID_t relatedId, const std::string& type)
{
    return m_db->AddEntryRelation(wordId, relatedId, type);
}

Result_t<bool> EntryService::RemoveRelation(ID_t relationId)
{
    return m_db->RemoveEntryRelation(relationId);
}

Result_t<std::vector<EntryRelation_t>> EntryService::GetRelationsForEntry(ID_t wordId) const
{
    return m_db->GetRelationsForEntry(wordId);
}

Result_t<std::vector<Entry_t>> EntryService::Search(const SearchParams_t& params) const
{
    if (params.query.empty() && params.tagIds.empty())
        return m_db->GetAllEntries();

    if (params.query.empty())
        return m_db->GetEntriesByTags(params.tagIds, params.tagMode);

    auto ftsResult = m_db->SearchEntries(params.query);
    if (!ftsResult)
        return std::unexpected(ftsResult.error());

    if (params.tagIds.empty())
        return ftsResult;

    auto tagResult = m_db->GetEntriesByTags(params.tagIds, params.tagMode);
    if (!tagResult)
        return std::unexpected(tagResult.error());

    std::vector<Entry_t> intersection;
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

Result_t<std::vector<Entry_t>> EntryService::SearchEntriesByName(const std::string& substring,
                                                                 bool includeContent) const
{
    if (substring.empty())
        return m_db->GetAllEntries();

    auto byName = m_db->SearchEntriesByName(substring);
    if (!byName)
        return byName;

    if (!includeContent)
        return byName;

    auto byContent = m_db->SearchEntriesByContent(substring);
    if (!byContent)
        return byContent;

    // Merge unique by id (name matches first, then any new content matches).
    std::vector<Entry_t> merged = *byName;
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

Result_t<std::vector<Tag_t>> EntryService::SearchTagsByName(const std::string& substring) const
{
    if (substring.empty())
        return m_db->GetAllTags();
    return m_db->SearchTagsByName(substring);
}

} // namespace Service
