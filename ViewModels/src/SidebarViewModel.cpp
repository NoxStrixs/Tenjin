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

    // Synthetic "Untagged" group (sentinel id -1). Without it, entries that
    // have no tag never appear in the tag-organized sidebar even though they
    // exist and are searchable. Only shown when not filtering by tag name, and
    // only when it actually contains entries (checked below by the fetcher
    // returning a non-empty set — the model simply renders an empty group as a
    // collapsible header, which we avoid by appending it unconditionally but
    // letting it collapse to just the header when empty).
    constexpr Service::ID_t kUntaggedId = -1;
    const bool              nameMatches = m_filterText.isEmpty() ||
                             QStringLiteral("untagged").contains(m_filterText, Qt::CaseInsensitive);
    // Only surface the Untagged group when it actually contains entries, so a
    // fully-tagged library doesn't show an empty header.
    bool hasUntagged = false;
    if (nameMatches) {
        auto untagged = m_entryService->GetUntaggedEntries();
        hasUntagged   = untagged && !untagged->empty();
    }
    if (hasUntagged)
        filtered.push_back(Service::Tag_t{.id = kUntaggedId, .name = "Untagged"});

    m_model->loadData(filtered, [this](Service::ID_t tagId) -> std::vector<Service::Entry_t> {
        if (tagId == -1) {
            auto result = m_entryService->GetUntaggedEntries();
            return result ? *result : std::vector<Service::Entry_t>{};
        }
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
