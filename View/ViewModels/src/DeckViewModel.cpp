#include <DeckService/DeckService.h>
#include <ViewModels/DeckViewModel.h>
#include <WordService/WordService.h>

// ---- DeckListModel --------------------------------------------------

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
    };
}

// ---- DeckViewModel --------------------------------------------------

DeckViewModel::DeckViewModel(std::shared_ptr<Service::DeckService> deckService,
                             std::shared_ptr<Service::WordService> wordService,
                             QObject*                              parent)
    : QObject(parent), m_deckService(std::move(deckService)), m_wordService(std::move(wordService)),
      m_deckModel(std::make_unique<DeckListModel>(this))
{
    reloadDecks();
}

void DeckViewModel::reloadDecks()
{
    auto result = m_deckService->GetAllDecks();
    if (result)
        m_deckModel->setDecks(*result);
    else
        emit errorOccurred(QString::fromStdString(result.error()));
}

void DeckViewModel::selectDeck(qint64 deckId)
{
    auto result = m_deckService->GetDeck(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_selectedDeckId      = deckId;
    m_selectedDeckName    = QString::fromStdString(result->name);
    m_selectedDeckIsSmart = result->bIsSmart;
    emit selectedDeckChanged();
    reloadDeckWords();
    reloadTagFilters();
}

void DeckViewModel::clearSelection()
{
    m_selectedDeckId = -1;
    m_selectedDeckName.clear();
    m_selectedDeckIsSmart = false;
    m_deckWords.clear();
    m_tagFilters.clear();
    emit selectedDeckChanged();
    emit deckWordsChanged();
    emit tagFiltersChanged();
}

bool DeckViewModel::createDeck(const QString& name, bool isSmart, int filterMode)
{
    auto mode   = (filterMode == 1) ? Service::FilterMode_t::Or : Service::FilterMode_t::And;
    auto result = m_deckService->CreateDeck(name.toStdString(), isSmart, mode);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadDecks();
    return true;
}

bool DeckViewModel::createSmartDeck(const QString& name, int filterMode, const QVariantList& tagIds)
{
    auto mode   = (filterMode == 1) ? Service::FilterMode_t::Or : Service::FilterMode_t::And;
    auto result = m_deckService->CreateDeck(name.toStdString(), /*isSmart=*/true, mode);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    const Service::ID_t deckId = result->id;
    for (const QVariant& v : tagIds) {
        const qint64 tagId = v.toLongLong();
        auto         link  = m_deckService->AddTagFilter(deckId, tagId);
        if (!link)
            emit errorOccurred(QString::fromStdString(link.error()));
    }
    reloadDecks();
    return true;
}

QVariantMap DeckViewModel::deckStats(qint64 deckId)
{
    QVariantMap out;
    auto        result = m_deckService->GetDeckStats(deckId);
    if (!result) {
        out["total"]   = 0;
        out["due"]     = 0;
        out["nextDue"] = QString();
        return out;
    }
    out["total"]   = result->total;
    out["due"]     = result->due;
    out["nextDue"] = QString::fromStdString(result->nextDue);
    return out;
}

QVariantMap DeckViewModel::deckAnalytics(qint64 deckId)
{
    QVariantMap out;
    auto        result = m_deckService->GetDeckAnalytics(deckId);
    if (!result) {
        out["totalReviews"] = 0;
        out["retention"]    = 0.0;
        out["daily"]        = QVariantList{};
        return out;
    }
    out["totalReviews"] = result->totalReviews;
    out["retention"]    = result->retention;
    QVariantList daily;
    for (const auto& d : result->daily) {
        QVariantMap m;
        m["date"]       = QString::fromStdString(d.date);
        m["count"]      = d.count;
        m["avgQuality"] = d.avgQuality;
        daily.append(m);
    }
    out["daily"] = daily;
    return out;
}

QVariantList DeckViewModel::wordHistory(qint64 deckId, qint64 wordId)
{
    QVariantList out;
    auto         result = m_deckService->GetWordHistory(deckId, wordId);
    if (!result)
        return out;
    for (const auto& e : *result) {
        QVariantMap m;
        m["reviewedAt"]   = QVariant::fromValue(e.reviewedAt);
        m["quality"]      = e.quality;
        m["easeFactor"]   = e.easeFactor;
        m["intervalDays"] = e.intervalDays;
        out.append(m);
    }
    return out;
}

bool DeckViewModel::deleteDeck(qint64 deckId)
{
    auto result = m_deckService->DeleteDeck(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        clearSelection();
    reloadDecks();
    return true;
}

bool DeckViewModel::addWordToDeck(qint64 deckId, qint64 wordId)
{
    auto result = m_deckService->AddWordToDeck(deckId, wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        reloadDeckWords();
    return true;
}

bool DeckViewModel::removeWordFromDeck(qint64 deckId, qint64 wordId)
{
    auto result = m_deckService->RemoveWordFromDeck(deckId, wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        reloadDeckWords();
    return true;
}

bool DeckViewModel::addTagFilter(qint64 deckId, qint64 tagId)
{
    auto result = m_deckService->AddTagFilter(deckId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId) {
        reloadTagFilters();
        reloadDeckWords();
    }
    return true;
}

bool DeckViewModel::removeTagFilter(qint64 deckId, qint64 tagId)
{
    auto result = m_deckService->RemoveTagFilter(deckId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId) {
        reloadTagFilters();
        reloadDeckWords();
    }
    return true;
}

void DeckViewModel::reloadTagFilters()
{
    if (m_selectedDeckId < 0)
        return;
    auto result = m_deckService->GetTagFilters(m_selectedDeckId);
    if (!result)
        return;
    m_tagFilters.clear();
    for (const auto& t : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(t.id);
        m["name"] = QString::fromStdString(t.name);
        m_tagFilters.append(m);
    }
    emit tagFiltersChanged();
}

QVariantList DeckViewModel::allWords()
{
    auto result = m_wordService->GetAllWords();
    if (!result)
        return {};
    QVariantList out;
    for (const auto& w : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(w.id);
        m["word"] = QString::fromStdString(w.word);
        out.append(m);
    }
    return out;
}

QVariantList DeckViewModel::allTags()
{
    auto result = m_wordService->GetAllTags();
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

void DeckViewModel::reloadDeckWords()
{
    if (m_selectedDeckId < 0)
        return;
    auto result = m_deckService->GetWordsForDeck(m_selectedDeckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_deckWords.clear();
    for (const auto& w : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(w.id);
        m["word"] = QString::fromStdString(w.word);
        m_deckWords.append(m);
    }
    emit deckWordsChanged();
}
