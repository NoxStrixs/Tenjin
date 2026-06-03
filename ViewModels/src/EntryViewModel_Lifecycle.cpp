#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QSettings>

EntryViewModel::EntryViewModel(std::shared_ptr<Service::EntryService> wordService, QObject* parent)
    : QObject(parent), m_entryService(std::move(wordService)),
      m_contentModel(std::make_unique<ContentBlockModel>(this))
{
    QSettings settings;
    m_tagMatchMode = settings.value("filters/tagMatchMode", 1).toInt();
}

void EntryViewModel::selectEntry(qint64 wordId)
{
    m_selectedWordId = wordId;
    auto words       = m_entryService->GetAllEntries();
    if (words) {
        for (const auto& w : *words) {
            if (w.id == wordId) {
                m_selectedWord = QString::fromStdString(w.word);
                break;
            }
        }
    }
    reloadContent();
    reloadTags();
    emit selectedEntryChanged();
}

void EntryViewModel::clearSelection()
{
    m_selectedWordId = -1;
    m_selectedWord.clear();
    m_contentModel->setBlocks({});
    m_wordTags.clear();
    emit wordTagsChanged();
    emit selectedEntryChanged();
}

void EntryViewModel::beginEdit()
{
    m_editSnapshot = m_contentModel->blocks();
    m_editMode     = true;
    emit editModeChanged();
}

void EntryViewModel::saveEdit()
{
    if (!m_editMode)
        return;
    auto result = m_entryService->SaveContentLayout(m_contentModel->blocks());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_editMode = false;
    emit editModeChanged();
    reloadContent();
}

void EntryViewModel::cancelEdit()
{
    if (!m_editMode)
        return;
    m_contentModel->setBlocks(m_editSnapshot);
    m_editSnapshot.clear();
    m_editMode = false;
    emit editModeChanged();
}

void EntryViewModel::reloadContent()
{
    if (m_selectedWordId < 0) {
        m_contentModel->setBlocks({});
        return;
    }
    auto result = m_entryService->GetContentForEntry(m_selectedWordId);
    if (result)
        m_contentModel->setBlocks(*result);
    else
        emit errorOccurred(QString::fromStdString(result.error()));
}

void EntryViewModel::reloadTags()
{
    m_wordTags.clear();
    if (m_selectedWordId >= 0) {
        auto result = m_entryService->GetTagsForEntry(m_selectedWordId);
        if (result) {
            for (const auto& t : *result) {
                QVariantMap m;
                m["id"]   = QVariant::fromValue(t.id);
                m["name"] = QString::fromStdString(t.name);
                m_wordTags.append(m);
            }
        }
    }
    emit wordTagsChanged();
}

void EntryViewModel::applySearch()
{
    emit entryListChanged();
}

void EntryViewModel::rebuildActiveTagIds()
{
    m_activeTagIds.clear();
    m_activeTagIds.reserve(m_tagFilters.size());
    for (const auto& v : m_tagFilters)
        m_activeTagIds.append(v.toLongLong());
}
