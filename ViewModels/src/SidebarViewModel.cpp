#include <EntryService/EntryService.h>
#include <ViewModels/SidebarViewModel.h>

SidebarViewModel::SidebarViewModel(std::shared_ptr<Service::EntryService> wordService,
                                   QObject*                               parent)
    : QObject(parent), m_entryService(std::move(wordService)),
      m_model(std::make_unique<SidebarModel>(this))
{
    reload();
}

void SidebarViewModel::setFilterText(const QString& text)
{
    if (m_filterText == text)
        return;
    m_filterText = text;
    emit filterTextChanged();
    reload();
}

void SidebarViewModel::setCollapsed(bool v)
{
    if (m_collapsed == v)
        return;
    m_collapsed = v;
    emit collapsedChanged();
}

void SidebarViewModel::reload()
{
    auto tagsResult = m_entryService->GetAllTags();
    if (!tagsResult)
        return;

    // Filter tags by filterText if set
    std::vector<Service::Tag_t> filtered;
    for (const auto& t : *tagsResult) {
        if (m_filterText.isEmpty() ||
            QString::fromStdString(t.name).contains(m_filterText, Qt::CaseInsensitive))
            filtered.push_back(t);
    }

    m_model->setData(filtered, [this](Service::ID_t tagId) -> std::vector<Service::Entry_t> {
        auto result = m_entryService->GetEntriesForTag(tagId);
        return result ? *result : std::vector<Service::Entry_t>{};
    });
}

void SidebarViewModel::onEntrySelected(qint64 wordId)
{
    emit entrySelected(wordId);
}

void SidebarViewModel::onTagSelected(qint64 tagId)
{
    emit tagFilterChanged(tagId, true);
}
