#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

void EntryViewModel::setSearchQuery(const QString& q)
{
    if (m_searchQuery == q)
        return;
    m_searchQuery = q;
    emit searchQueryChanged();
    rebuildSearchResults();
    applySearch();
}

void EntryViewModel::setSearchInContent(bool on)
{
    if (m_searchInContent == on)
        return;
    m_searchInContent = on;
    emit searchInContentChanged();
    rebuildSearchResults();
    applySearch();
}

void EntryViewModel::rebuildSearchResults()
{
    m_searchResults.clear();

    const std::string q = m_searchQuery.trimmed().toStdString();
    if (!q.empty()) {
        // Tag suggestions first
        if (auto tags = m_entryService->SearchTagsByName(q)) {
            for (const auto& t : *tags) {
                QVariantMap m;
                m["kind"]  = QStringLiteral("tag");
                m["id"]    = QVariant::fromValue(t.id);
                m["label"] = QString::fromStdString(t.name);
                m_searchResults.append(m);
            }
        }
        // Entry suggestions
        if (auto words = m_entryService->SearchEntriesByName(q, m_searchInContent)) {
            const QString ql = m_searchQuery.trimmed().toLower();
            for (const auto& w : *words) {
                // kV2 multi-language filter. Entries with no language
                // (e.g. post-migration kV1 -> kV2 entries) always show.
                // Filter only hides explicitly-other-language entries.
                if (!m_languageFilter.isEmpty() && !w.language.empty() &&
                    QString::fromStdString(w.language) != m_languageFilter)
                    continue;
                QVariantMap m;
                m["kind"]  = QStringLiteral("word");
                m["id"]    = QVariant::fromValue(w.id);
                m["label"] = QString::fromStdString(w.word);

                // If content search is on and the entry name doesn't itself
                // contain the query, surface the matching content line.
                QString snippet;
                if (m_searchInContent && !QString::fromStdString(w.word).toLower().contains(ql)) {
                    if (auto blocks = m_entryService->GetContentForEntry(w.id)) {
                        for (const auto& b : *blocks) {
                            const QString   c   = QString::fromStdString(b.content);
                            const qsizetype idx = c.toLower().indexOf(ql);
                            if (idx >= 0) {
                                const qsizetype start = std::max<qsizetype>(0, idx - 20);
                                snippet = (start > 0 ? QStringLiteral("…") : QString()) +
                                          c.mid(start, 60).simplified() +
                                          (c.size() > start + 60 ? QStringLiteral("…") : QString());
                                break;
                            }
                        }
                    }
                }
                m["snippet"] = snippet;
                m_searchResults.append(m);
            }
        }
    }
    emit searchResultsChanged();
}

void EntryViewModel::filterByTag(qint64 tagId, const QString& /*tagName*/)
{
    m_searchQuery.clear();
    emit searchQueryChanged();
    m_searchResults.clear();
    emit searchResultsChanged();

    m_tagFilters.clear();
    m_tagFilters.append(QVariant::fromValue(tagId));
    rebuildActiveTagIds();
    emit tagFiltersChanged();
    applySearch();
}
