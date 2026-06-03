#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

bool EntryViewModel::addWord(const QString& word)
{
    auto result = m_entryService->CreateWord(word.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    emit entryListChanged();
    return true;
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
    emit entryListChanged();
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
        QVariantMap m;
        m["wordId"] = QVariant::fromValue(w.id);
        m["word"]   = QString::fromStdString(w.word);
        out.append(m);
    }
    return out;
}
