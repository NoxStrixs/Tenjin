#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QSettings>

void EntryViewModel::addTagFilter(qint64 tagId)
{
    if (!isTagFiltered(tagId)) {
        m_tagFilters.append(QVariant::fromValue(tagId));
        rebuildActiveTagIds();
        emit tagFiltersChanged();
        applySearch();
    }
}

void EntryViewModel::removeTagFilter(qint64 tagId)
{
    for (int i = m_tagFilters.size() - 1; i >= 0; i--)
        if (m_tagFilters.at(i).toLongLong() == tagId)
            m_tagFilters.removeAt(i);
    rebuildActiveTagIds();
    emit tagFiltersChanged();
    applySearch();
}

void EntryViewModel::clearTagFilters()
{
    m_tagFilters.clear();
    rebuildActiveTagIds();
    emit tagFiltersChanged();
    applySearch();
}

void EntryViewModel::setTagMatchMode(int mode)
{
    const int normalized = (mode == 0) ? 0 : 1;
    if (normalized == m_tagMatchMode)
        return;
    m_tagMatchMode = normalized;
    QSettings settings;
    settings.setValue("filters/tagMatchMode", m_tagMatchMode);
    emit tagMatchModeChanged();
    if (!m_tagFilters.isEmpty())
        applySearch();
}

bool EntryViewModel::isTagFiltered(qint64 tagId) const
{
    for (const auto& v : m_tagFilters)
        if (v.toLongLong() == tagId)
            return true;
    return false;
}

bool EntryViewModel::attachTag(qint64 wordId, qint64 tagId)
{
    auto result = m_entryService->AddTagToEntry(wordId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (wordId == m_selectedWordId)
        reloadTags();
    return true;
}

bool EntryViewModel::detachTag(qint64 wordId, qint64 tagId)
{
    auto result = m_entryService->RemoveTagFromEntry(wordId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (wordId == m_selectedWordId)
        reloadTags();
    return true;
}

QVariantList EntryViewModel::getTagsForEntry(qint64 wordId)
{
    if (wordId < 0)
        return {};
    auto result = m_entryService->GetTagsForEntry(wordId);
    if (!result)
        return {};
    QVariantList out;
    for (const auto& t : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(t.id);
        m["name"] = QString::fromStdString(t.name);
        out.append(m);
    }
    return out;
}

bool EntryViewModel::createAndAttachTag(const QString& name)
{
    if (m_selectedWordId < 0)
        return false;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return false;

    auto tag = m_entryService->GetOrCreateTag(trimmed.toStdString());
    if (!tag) {
        emit errorOccurred(QString::fromStdString(tag.error()));
        return false;
    }

    auto attached = m_entryService->AddTagToEntry(m_selectedWordId, tag->id);
    if (!attached) {
        emit errorOccurred(QString::fromStdString(attached.error()));
        return false;
    }
    reloadTags();
    emit entryListChanged(); // tag list in sidebar may have grown
    return true;
}

QVariantList EntryViewModel::getAllTags()
{
    auto result = m_entryService->GetAllTags();
    if (!result)
        return {};
    QVariantList out;
    for (const auto& t : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(t.id);
        m["name"] = QString::fromStdString(t.name);
        out.append(m);
    }
    return out;
}

bool EntryViewModel::createTag(const QString& name)
{
    auto result = m_entryService->CreateTag(name.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    emit entryListChanged();
    return true;
}

bool EntryViewModel::deleteTag(qint64 tagId)
{
    auto result = m_entryService->DeleteTag(tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    // The DB cascade removed entry_tag + deck_tag_filter rows for this
    // tag, but the in-memory filter set and per-entry tag caches don't
    // know that. Without the cleanup below the views keep applying a
    // now-dangling tag filter — words "disappear" because the search
    // tries to match a deleted tag id, even though the words themselves
    // are still on disk.
    bool filterChanged = false;
    if (m_activeTagIds.removeAll(tagId) > 0)
        filterChanged = true;
    if (filterChanged)
        emit tagFiltersChanged();
    reloadTags();
    rebuildSearchResults();
    emit entryListChanged();
    emit wordTagsChanged();
    return true;
}

void EntryViewModel::reloadAfterDataChange()
{
    // Called after a bulk wipe (Settings danger zone) or after tag +
    // smart-deck deletes. Clears any cached filter set that might
    // reference deleted ids, re-pulls per-entry tag data, and refreshes
    // the search-result cache so views don't keep showing stale rows.
    m_activeTagIds.clear();
    emit tagFiltersChanged();
    reloadTags();
    rebuildSearchResults();
    emit entryListChanged();
    emit wordTagsChanged();
    emit selectedEntryChanged();
    emit selectedEntryRelationsChanged();
}

// kV2 multi-language
void EntryViewModel::setCurrentLanguageFilter(const QString& code)
{
    if (m_languageFilter == code)
        return;
    m_languageFilter = code;
    QSettings settings;
    settings.setValue("multilang/currentFilter", code);
    emit currentLanguageFilterChanged();
    rebuildSearchResults();
    emit entryListChanged();
}

bool EntryViewModel::setEntryLanguage(qint64 entryId, const QString& code)
{
    auto r =
        m_entryService->SetEntryLanguage(static_cast<Service::ID_t>(entryId), code.toStdString());
    if (!r) {
        emit errorOccurred(QString::fromStdString(r.error()));
        return false;
    }
    // If we just relabelled the currently-selected entry, the QML
    // bindings calling entryLanguage(selectedEntryId) won't refresh on
    // their own -- entryLanguage is a Q_INVOKABLE function, not a
    // property, so it doesn't NOTIFY. Re-emit selectedEntryChanged to
    // force every dependent binding (the picker chip, the read-mode
    // label) to re-read the entry. Without this the user sees the
    // dropdown snap back to its previous selection.
    if (entryId == m_selectedWordId)
        emit selectedEntryChanged();
    rebuildSearchResults();
    emit entryListChanged();
    return true;
}

QString EntryViewModel::entryLanguage(qint64 entryId) const
{
    if (entryId <= 0)
        return {};
    auto e = m_entryService->GetEntryById(static_cast<Service::ID_t>(entryId));
    return e ? QString::fromStdString(e.value().language) : QString{};
}

void EntryViewModel::setLastAddedBlockId(qint64 v)
{
    if (m_lastAddedBlockId == v)
        return;
    m_lastAddedBlockId = v;
    emit lastAddedBlockIdChanged();
}

bool EntryViewModel::renameEntry(qint64 entryId, const QString& newName)
{
    if (entryId <= 0)
        return false;
    const QString trimmed = newName.trimmed();
    if (trimmed.isEmpty()) {
        emit errorOccurred(QStringLiteral("Entry name cannot be empty."));
        return false;
    }
    auto r =
        m_entryService->RenameEntry(static_cast<Service::ID_t>(entryId), trimmed.toStdString());
    if (!r) {
        emit errorOccurred(QString::fromStdString(r.error()));
        return false;
    }
    // If we just renamed the currently-selected entry, refresh its
    // cached title so the header binding updates without a re-select.
    if (entryId == m_selectedWordId) {
        m_selectedWord = trimmed;
        emit selectedEntryChanged();
    }
    rebuildSearchResults();
    emit entryListChanged();
    return true;
}

bool EntryViewModel::renameTag(qint64 tagId, const QString& name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        emit errorOccurred(QStringLiteral("Tag name cannot be empty."));
        return false;
    }
    auto result = m_entryService->RenameTag(tagId, trimmed.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadTags();
    emit entryListChanged();
    return true;
}
