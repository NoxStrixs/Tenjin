#include <ViewModels/EntryViewModel.h>

ContentBlockModel::ContentBlockModel(QObject* parent) : QAbstractListModel(parent) {}

void ContentBlockModel::setBlocks(const std::vector<Service::ContentBlock_t>& blocks)
{
    beginResetModel();
    m_blocks = blocks;
    endResetModel();
}

int ContentBlockModel::rowCount(const QModelIndex&) const
{
    return static_cast<int>(m_blocks.size());
}

QVariant ContentBlockModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const auto& b = m_blocks[index.row()];
    switch (role) {
    case IdRole:
        return QVariant::fromValue(b.id);
    case EntryIdRole:
        return QVariant::fromValue(b.wordId);
    case TypeRole:
        return static_cast<int>(b.type);
    case ContentRole:
        return QString::fromStdString(b.content);
    case RowRole:
        return b.row;
    case ColRole:
        return b.col;
    case RowSpanRole:
        return b.rowSpan;
    case ColSpanRole:
        return b.colSpan;
    case PosRole:
        return QString::fromStdString(b.pos);
    }
    return {};
}

QHash<int, QByteArray> ContentBlockModel::roleNames() const
{
    return {
        {IdRole, "blockId"},
        {EntryIdRole, "wordId"},
        {TypeRole, "blockType"},
        {ContentRole, "content"},
        {RowRole, "row"},
        {ColRole, "col"},
        {RowSpanRole, "rowSpan"},
        {ColSpanRole, "colSpan"},
        {PosRole, "pos"},
    };
}

void ContentBlockModel::moveBlock(int from, int to)
{
    if (from == to || from < 0 || to < 0 || from >= rowCount() || to >= rowCount())
        return;

    if (!beginMoveRows({}, from, from, {}, to > from ? to + 1 : to))
        return;

    auto first = m_blocks.begin() + from;
    if (to > from) {
        std::rotate(first, first + 1, m_blocks.begin() + to + 1);
    } else {
        std::rotate(m_blocks.begin() + to, first, first + 1);
    }

    // Renumber row indices so they stay contiguous and match visual order.
    for (int i = 0; i < static_cast<int>(m_blocks.size()); i++)
        m_blocks[i].row = i;

    endMoveRows();
}

Service::ID_t ContentBlockModel::appendBlock(Service::ContentBlock_t block)
{
    const int row = static_cast<int>(m_blocks.size());
    block.id      = m_nextTempId--; // temporary negative id until persisted
    block.row     = row;            // append at the end as a single cell
    block.col     = 0;
    block.rowSpan = 1;
    block.colSpan = 1;

    beginInsertRows({}, row, row);
    m_blocks.push_back(std::move(block));
    endInsertRows();
    return m_blocks.back().id;
}

void ContentBlockModel::removeBlockById(Service::ID_t id)
{
    auto it =
        std::find_if(m_blocks.begin(), m_blocks.end(), [id](const auto& b) { return b.id == id; });
    if (it == m_blocks.end())
        return;

    const int row = static_cast<int>(std::distance(m_blocks.begin(), it));
    beginRemoveRows({}, row, row);
    m_blocks.erase(it);
    endRemoveRows();

    for (int i = 0; i < static_cast<int>(m_blocks.size()); i++)
        m_blocks[i].row = i;
}

const Service::ContentBlock_t* ContentBlockModel::findById(Service::ID_t id) const
{
    for (const auto& b : m_blocks)
        if (b.id == id)
            return &b;
    return nullptr;
}

void ContentBlockModel::setBlockContent(Service::ID_t id, const QString& content)
{
    for (int i = 0; i < static_cast<int>(m_blocks.size()); i++) {
        if (m_blocks[i].id == id) {
            m_blocks[i].content   = content.toStdString();
            const QModelIndex idx = index(i, 0);
            emit              dataChanged(idx, idx);
            return;
        }
    }
}

void ContentBlockModel::setBlockGrid(Service::ID_t id, int row, int col, int rowSpan, int colSpan)
{
    for (int i = 0; i < static_cast<int>(m_blocks.size()); i++) {
        if (m_blocks[i].id == id) {
            m_blocks[i].row       = row;
            m_blocks[i].col       = col;
            m_blocks[i].rowSpan   = rowSpan < 1 ? 1 : rowSpan;
            m_blocks[i].colSpan   = colSpan < 1 ? 1 : colSpan;
            const QModelIndex idx = index(i, 0);
            emit              dataChanged(idx, idx);
            return;
        }
    }
}

void ContentBlockModel::setBlockPos(Service::ID_t id, const QString& pos)
{
    for (int i = 0; i < static_cast<int>(m_blocks.size()); i++) {
        if (m_blocks[i].id == id) {
            m_blocks[i].pos       = pos.toStdString();
            const QModelIndex idx = index(i, 0);
            emit              dataChanged(idx, idx);
            return;
        }
    }
}
