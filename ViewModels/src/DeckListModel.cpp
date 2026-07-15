#include <ViewModels/DeckViewModel.h>

DeckListModel::DeckListModel(QObject* parent) : QAbstractListModel(parent) {}

void DeckListModel::setDecks(const std::vector<Service::Deck_t>& decks)
{
    beginResetModel();
    m_decks = decks;
    endResetModel();
}

int DeckListModel::rowCount(const QModelIndex&) const
{
    return static_cast<int>(m_decks.size());
}

QVariant DeckListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() >= rowCount())
        return {};
    const auto& d = m_decks[index.row()];
    switch (role) {
    case IdRole:
        return QVariant::fromValue(d.id);
    case NameRole:
        return QString::fromStdString(d.name);
    case IsSmartRole:
        return d.bIsSmart;
    case FilterModeRole:
        return static_cast<int>(d.filterMode);
    case CreatedAtRole:
        return QString::fromStdString(d.createdAt);
    case LanguageRole:
        return QString::fromStdString(d.language);
    }
    return {};
}

QHash<int, QByteArray> DeckListModel::roleNames() const
{
    return {
        {IdRole, "deckId"},
        {NameRole, "deckName"},
        {IsSmartRole, "isSmart"},
        {FilterModeRole, "filterMode"},
        {CreatedAtRole, "createdAt"},
        {LanguageRole, "deckLanguage"},
    };
}
