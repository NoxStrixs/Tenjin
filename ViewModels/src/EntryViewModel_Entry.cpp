#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

qint64 EntryViewModel::addWord(const QString& word)
{
    auto result = m_entryService->CreateWord(word.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return -1;
    }
    const qint64 newId = static_cast<qint64>(result.value().id);
    // If a language filter is active, the user is conceptually working
    // "in" that language right now — auto-tag the new entry so it stays
    // visible after creation and doesn't immediately get filtered out.
    if (!m_languageFilter.isEmpty()) {
        m_entryService->SetEntryLanguage(static_cast<Service::ID_t>(newId),
                                         m_languageFilter.toStdString());
    }
    emit entryListChanged();
    return newId;
}

bool EntryViewModel::deleteEntry(qint64 wordId)
{
    auto result = m_entryService->DeleteEntry(wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedWordId == wordId)
        clearSelection();
    // Refresh ALL caches that could reference this entry. Without these
    // the sidebar's wordListView (which re-queries via getAllEntries on
    // entryListChanged) updates, but the universal search-result list
    // and per-entry tag/relation caches keep stale rows.
    rebuildSearchResults();
    reloadTags();
    emit entryListChanged();
    emit wordTagsChanged();
    emit selectedEntryRelationsChanged();
    return true;
}

QVariantList EntryViewModel::getAllEntries()
{
    Service::EntryService::SearchParams_t params;
    params.query = m_searchQuery.trimmed().toStdString();
    for (const auto& v : m_tagFilters)
        params.tagIds.push_back(v.toLongLong());
    params.tagMode = (m_tagMatchMode == 0) ? Service::FilterMode_t::Or : Service::FilterMode_t::And;

    std::vector<Service::Entry_t> words;
    if (params.query.empty() && params.tagIds.empty()) {
        auto result = m_entryService->GetAllEntries();
        if (!result)
            return {};
        words = *result;
    } else if (!params.tagIds.empty() && params.query.empty()) {
        auto result = m_entryService->Search(params);
        if (!result)
            return {};
        words = *result;
    } else {
        auto result = m_entryService->SearchEntriesByName(params.query, m_searchInContent);
        if (!result)
            return {};
        words = *result;
        if (!params.tagIds.empty()) {
            params.query.clear();
            auto tagged = m_entryService->Search(params);
            if (tagged) {
                std::vector<Service::Entry_t> filtered;
                for (const auto& w : words)
                    for (const auto& tw : *tagged)
                        if (tw.id == w.id) {
                            filtered.push_back(w);
                            break;
                        }
                words = filtered;
            }
        }
    }

    QVariantList out;
    for (const auto& w : words) {
        // kV2 multi-language: skip entries that explicitly belong to a
        // different language. Entries with NO language assigned (e.g.
        // every entry right after the kV1 -> kV2 migration) always show
        // regardless of the filter -- otherwise a stale filter persisted
        // from QSettings would silently hide every existing entry until
        // the user dug into Settings to clear it. Empty filter shows
        // everything.
        if (!m_languageFilter.isEmpty() && !w.language.empty() &&
            QString::fromStdString(w.language) != m_languageFilter)
            continue;
        QVariantMap m;
        m["wordId"] = QVariant::fromValue(w.id);
        m["word"]   = QString::fromStdString(w.word);
        out.append(m);
    }
    return out;
}

// ── Typed relations ─────────────────────────────────────────────────
//
// Relations live in the entry_relation table with (entry_id, related_entry_id,
// relation_type) — schema kV1. The DB layer returns IDs only, so we look up
// the related entry's title here to give QML something to render.

QVariantList EntryViewModel::selectedEntryRelations() const
{
    QVariantList out;
    if (m_selectedWordId <= 0)
        return out;
    auto rels = m_entryService->GetRelationsForEntry(m_selectedWordId);
    if (!rels)
        return out;
    for (const auto& r : rels.value()) {
        QVariantMap m;
        m["id"]        = QVariant::fromValue(r.id);
        m["relatedId"] = QVariant::fromValue(r.wordRelationId);
        m["kind"]      = QString::fromStdString(r.relationType);
        // Resolve the related entry's title via GetEntryById. If the lookup
        // fails (e.g. the related entry was deleted), leave word blank;
        // QML treats blank as "(deleted)" and offers a delete-relation
        // action so the user can clean up.
        auto entry = m_entryService->GetEntryById(r.wordRelationId);
        m["word"]  = entry ? QString::fromStdString(entry.value().word) : QString{};
        out.append(m);
    }
    return out;
}

bool EntryViewModel::addRelation(qint64 entryId, qint64 relatedId, const QString& kind)
{
    if (entryId <= 0 || relatedId <= 0 || entryId == relatedId)
        return false;
    auto r = m_entryService->AddRelation(static_cast<Service::ID_t>(entryId),
                                         static_cast<Service::ID_t>(relatedId),
                                         kind.toStdString());
    if (!r) {
        emit errorOccurred(QString::fromStdString(r.error()));
        return false;
    }
    if (entryId == m_selectedWordId)
        emit selectedEntryRelationsChanged();
    return true;
}

bool EntryViewModel::removeRelation(qint64 relationId)
{
    if (relationId <= 0)
        return false;
    auto r = m_entryService->RemoveRelation(static_cast<Service::ID_t>(relationId));
    if (!r) {
        emit errorOccurred(QString::fromStdString(r.error()));
        return false;
    }
    emit selectedEntryRelationsChanged();
    return true;
}
