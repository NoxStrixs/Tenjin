#pragma once

#include <DatabaseManager/DatabaseManager.h>
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>

#include <QAbstractListModel>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <memory>
#include <vector>

class DeckListModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role_t {
        IdRole = Qt::UserRole + 1,
        NameRole,
        IsSmartRole,
        FilterModeRole,
        CreatedAtRole,
    };

    explicit DeckListModel(QObject* parent = nullptr);

    void setDecks(const std::vector<Service::Deck_t>& decks);

    int                    rowCount(const QModelIndex& parent = {}) const override;
    QVariant               data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

private:
    std::vector<Service::Deck_t> m_decks;
};

class DeckViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(DeckListModel* deckModel READ deckModel CONSTANT)
    Q_PROPERTY(qint64 selectedDeckId READ selectedDeckId NOTIFY selectedDeckChanged)
    Q_PROPERTY(QString selectedDeckName READ selectedDeckName NOTIFY selectedDeckChanged)
    Q_PROPERTY(bool selectedDeckIsSmart READ selectedDeckIsSmart NOTIFY selectedDeckChanged)
    Q_PROPERTY(QVariantList deckWords READ deckWords NOTIFY deckWordsChanged)
    Q_PROPERTY(QVariantList tagFilters READ tagFilters NOTIFY tagFiltersChanged)

public:
    DeckViewModel(std::shared_ptr<Service::DeckService>  deckService,
                  std::shared_ptr<Service::EntryService> wordService,
                  QObject*                               parent = nullptr);

    DeckListModel* deckModel() const
    {
        return m_deckModel.get();
    }
    qint64 selectedDeckId() const
    {
        return m_selectedDeckId;
    }
    QString selectedDeckName() const
    {
        return m_selectedDeckName;
    }
    bool selectedDeckIsSmart() const
    {
        return m_selectedDeckIsSmart;
    }
    QVariantList deckWords() const
    {
        return m_deckWords;
    }
    QVariantList tagFilters() const
    {
        return m_tagFilters;
    }

public slots:
    void reloadDecks();
    void selectDeck(qint64 deckId);
    void clearSelection();

    // FilterMode: 0 = And, 1 = Or
    bool createDeck(const QString& name, bool isSmart, int filterMode);
    Q_INVOKABLE bool
    createSmartDeck(const QString& name, int filterMode, const QVariantList& tagIds);
    Q_INVOKABLE QVariantMap  deckStats(qint64 deckId);
    Q_INVOKABLE QVariantMap  deckAnalytics(qint64 deckId);
    Q_INVOKABLE QVariantList wordHistory(qint64 deckId, qint64 wordId);
    bool                     deleteDeck(qint64 deckId);

    // Manual decks
    bool addWordToDeck(qint64 deckId, qint64 wordId);
    bool removeWordFromDeck(qint64 deckId, qint64 wordId);

    // Smart deck filters
    bool addTagFilter(qint64 deckId, qint64 tagId);
    bool removeTagFilter(qint64 deckId, qint64 tagId);

    QVariantList allWords();
    // Listing all tags for the smart-deck filter picker.
    QVariantList allTags();

signals:
    void selectedDeckChanged();
    void deckWordsChanged();
    void tagFiltersChanged();
    void errorOccurred(const QString& msg);

private:
    void reloadDeckWords();
    void reloadTagFilters();

    std::shared_ptr<Service::DeckService>  m_deckService;
    std::shared_ptr<Service::EntryService> m_entryService;
    std::unique_ptr<DeckListModel>         m_deckModel;

    qint64       m_selectedDeckId = -1;
    QString      m_selectedDeckName;
    bool         m_selectedDeckIsSmart = false;
    QVariantList m_deckWords;
    QVariantList m_tagFilters;
};
