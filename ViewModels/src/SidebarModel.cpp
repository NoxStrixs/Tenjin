#include <ViewModels/SidebarViewModel.h>
#include <unordered_set>

SidebarModel::SidebarModel(QObject* parent) : QAbstractListModel(parent) {}

void SidebarModel::rebuildRows()
{
    m_rows.clear();
    for (int ti = 0; ti < static_cast<int>(m_tags.size()); ti++) {
        const auto& tag = m_tags[ti];
        m_rows.push_back(Row_t{true, tag.id, tag.name, tag.expanded, ti});
        if (tag.expanded)
            for (const auto& w : tag.words)
                m_rows.push_back(Row_t{false, w.id, w.name, false, ti});
    }
}

void SidebarModel::loadData(const std::vector<Service::Tag_t>&                          tags,
                           std::function<std::vector<Service::Entry_t>(Service::ID_t)> wordFetcher)
{
    beginResetModel();

    // Preserve which tags were expanded across the rebuild. Without this, every
    // reload (filter change, data change, an edit elsewhere) collapses all
    // groups, so a tag the user opened snaps shut on the next refresh.
    std::unordered_set<Service::ID_t> wasExpanded;
    for (const auto& t : m_tags)
        if (t.expanded)
            wasExpanded.insert(t.id);

    m_tags.clear();
    for (const auto& t : tags) {
        TagItem_t item;
        item.id       = t.id;
        item.name     = QString::fromStdString(t.name);
        item.expanded = wasExpanded.count(t.id) > 0;
        auto words    = wordFetcher(t.id);
        for (const auto& w : words)
            item.words.push_back({w.id, QString::fromStdString(w.word)});
        m_tags.push_back(std::move(item));
    }
    rebuildRows();
    endResetModel();
}

int SidebarModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return static_cast<int>(m_rows.size());
}

QVariant SidebarModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= static_cast<int>(m_rows.size()))
        return {};
    const auto& r = m_rows[index.row()];
    switch (role) {
    case IsTagRole:
        return r.isTag;
    case IdRole:
        return QVariant::fromValue(r.id);
    case NameRole:
        return r.name;
    case ExpandedRole:
        return r.isTag ? r.expanded : false;
    }
    return {};
}

QHash<int, QByteArray> SidebarModel::roleNames() const
{
    return {
        {IdRole, "itemId"},
        {NameRole, "itemName"},
        {IsTagRole, "isTag"},
        {ExpandedRole, "expanded"},
    };
}

void SidebarModel::toggleExpanded(int tagRow)
{
    if (tagRow < 0 || tagRow >= static_cast<int>(m_rows.size()))
        return;
    const auto& row = m_rows[tagRow];
    if (!row.isTag)
        return;
    const int ti = row.tagIndex;
    if (ti < 0 || ti >= static_cast<int>(m_tags.size()))
        return;

    auto&     tag       = m_tags[ti];
    const int wordCount = static_cast<int>(tag.words.size());

    if (!tag.expanded) {
        // Insert word rows right after the tag row.
        if (wordCount > 0) {
            beginInsertRows({}, tagRow + 1, tagRow + wordCount);
            tag.expanded = true;
            rebuildRows();
            endInsertRows();
        } else {
            tag.expanded = true;
            rebuildRows();
        }
    } else {
        if (wordCount > 0) {
            beginRemoveRows({}, tagRow + 1, tagRow + wordCount);
            tag.expanded = false;
            rebuildRows();
            endRemoveRows();
        } else {
            tag.expanded = false;
            rebuildRows();
        }
    }
    const QModelIndex idx = index(tagRow, 0);
    emit              dataChanged(idx, idx, {ExpandedRole});
}
