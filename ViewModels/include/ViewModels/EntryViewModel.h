#pragma once

#include <DatabaseManager/DatabaseManager.h>
#include <EntryService/EntryService.h>

#include <QAbstractListModel>
#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>

#include <memory>
#include <vector>

class ContentBlockModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role_t {
        IdRole = Qt::UserRole + 1,
        EntryIdRole,
        TypeRole,
        ContentRole,
        RowRole,
        ColRole,
        RowSpanRole,
        ColSpanRole,
        PosRole,
    };

    explicit ContentBlockModel(QObject* parent = nullptr);

    void setBlocks(const std::vector<Service::ContentBlock_t>& blocks);

    const std::vector<Service::ContentBlock_t>& blocks() const
    {
        return m_blocks;
    }

    int                    rowCount(const QModelIndex& parent = {}) const override;
    QVariant               data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void moveBlock(int from, int to);

    Service::ID_t appendBlock(Service::ContentBlock_t block);

    void removeBlockById(Service::ID_t id);

    void setBlockContent(Service::ID_t id, const QString& content);

    void setBlockGrid(Service::ID_t id, int row, int col, int rowSpan, int colSpan);

    void setBlockPos(Service::ID_t id, const QString& pos);

    const Service::ContentBlock_t* findById(Service::ID_t id) const;

private:
    std::vector<Service::ContentBlock_t> m_blocks;
    Service::ID_t                        m_nextTempId = -1;
};

class EntryViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(ContentBlockModel* contentModel READ contentModel CONSTANT)
    Q_PROPERTY(qint64 selectedEntryId READ selectedEntryId NOTIFY selectedEntryChanged)
    Q_PROPERTY(QString selectedWord READ selectedWord NOTIFY selectedEntryChanged)
    Q_PROPERTY(bool editMode READ editMode NOTIFY editModeChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    Q_PROPERTY(bool searchInContent READ searchInContent WRITE setSearchInContent NOTIFY
                   searchInContentChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(QVariantList tagFilters READ tagFilters NOTIFY tagFiltersChanged)
    Q_PROPERTY(QList<qint64> activeTagIds READ activeTagIds NOTIFY tagFiltersChanged)
    Q_PROPERTY(int tagMatchMode READ tagMatchMode WRITE setTagMatchMode NOTIFY tagMatchModeChanged)
    Q_PROPERTY(QVariantList wordTags READ wordTags NOTIFY wordTagsChanged)

    // Typed relations between entries. Rebuilt whenever the selected entry
    // changes (or a relation is added/removed). Each entry is
    // { id, relatedId, word, kind } where kind is one of the canonical
    // strings: synonym, antonym, related, translation, inflection.
    // QML groups by kind to render Synonyms / Antonyms / etc. sections.
    Q_PROPERTY(QVariantList selectedEntryRelations READ selectedEntryRelations NOTIFY
                   selectedEntryRelationsChanged)

    // Id of the most recently added content block. QML's ContentBlock
    // delegate binds against this to pulse-highlight itself when it
    // matches; consumed by the caller (EntryDetailView) which resets it
    // after the pulse Animation completes. -1 = nothing recent.
    Q_PROPERTY(qint64 lastAddedBlockId READ lastAddedBlockId WRITE setLastAddedBlockId NOTIFY
                   lastAddedBlockIdChanged)
    qint64 lastAddedBlockId() const
    {
        return m_lastAddedBlockId;
    }
    // Setter body lives in EntryViewModel_Tag.cpp -- moc's header parser
    // can't reliably read multi-statement inline bodies with `if` /
    // `return` / `emit` in them, even though the compiler can. Keep
    // anything non-trivial out of headers in classes that go through moc.
    void setLastAddedBlockId(qint64 v);

    // kV2 multi-language: per-entry ISO 639-1 code + a global filter.
    // The Q_PROPERTY plus its inline READ getter must live OUT of any
    // public slots: / signals: section -- moc cannot generate code for
    // inline bodies in those sections. Mutators (setCurrentLanguageFilter,
    // setEntryLanguage, etc.) are in public slots: below.
    Q_PROPERTY(QString currentLanguageFilter READ currentLanguageFilter WRITE
                   setCurrentLanguageFilter NOTIFY currentLanguageFilterChanged)
    QString currentLanguageFilter() const
    {
        return m_languageFilter;
    }

public:
    explicit EntryViewModel(std::shared_ptr<Service::EntryService> wordService,
                            QObject*                               parent = nullptr);

    ContentBlockModel* contentModel() const
    {
        return m_contentModel.get();
    }
    qint64 selectedEntryId() const
    {
        return m_selectedWordId;
    }
    QString selectedWord() const
    {
        return m_selectedWord;
    }
    bool editMode() const
    {
        return m_editMode;
    }
    QString searchQuery() const
    {
        return m_searchQuery;
    }
    bool searchInContent() const
    {
        return m_searchInContent;
    }
    QVariantList searchResults() const
    {
        return m_searchResults;
    }
    QVariantList tagFilters() const
    {
        return m_tagFilters;
    }
    QList<qint64> activeTagIds() const
    {
        return m_activeTagIds;
    }
    int tagMatchMode() const
    {
        return m_tagMatchMode;
    }
    QVariantList wordTags() const
    {
        return m_wordTags;
    }

public slots:
    void selectEntry(qint64 wordId);
    void clearSelection();

    void beginEdit();
    void saveEdit();
    void cancelEdit();

    // Creates a new entry and returns its database id on success, or -1 on
    // failure. Returning the id lets the caller (AddEntryDialog) navigate
    // straight to the new entry's detail page without a second lookup.
    qint64 addWord(const QString& word);
    bool   deleteEntry(qint64 wordId);

    bool addContentBlock(int type, const QString& content = QString());
    bool updateContentBlock(
        qint64 id, int type, const QString& content, int row, int col, int rowSpan, int colSpan);
    bool updateContentBlockText(qint64 id, const QString& content);
    bool deleteContentBlock(qint64 id);
    void moveContentBlock(int from, int to);

    // Grid editing (staged during edit mode, persisted on save)
    Q_INVOKABLE void setBlockPosition(qint64 id, int row, int col);
    Q_INVOKABLE void setBlockSpan(qint64 id, int rowSpan, int colSpan);
    Q_INVOKABLE void setBlockPartOfSpeech(qint64 id, const QString& pos);
    Q_INVOKABLE int  rowCountForLayout() const;

    bool saveLayout();

    Q_INVOKABLE QString importMedia(const QString& sourceUrl);
    Q_INVOKABLE QString resolveMediaUrl(const QString& storedPath) const;

    // -- Typed relations ---------------------------------------------
    // The relation `kind` is a free-form string at the DB layer, but the
    // UI treats the following five values as the canonical set:
    //   synonym, antonym, related, translation, inflection
    // QML's AddRelationDialog only emits these, and the grouped relations
    // section in EntryDetailView renders sections for each.
    QVariantList     selectedEntryRelations() const;
    Q_INVOKABLE bool addRelation(qint64 entryId, qint64 relatedId, const QString& kind);
    Q_INVOKABLE bool removeRelation(qint64 relationId);

    // Search filters
    void setSearchQuery(const QString& q);
    void setSearchInContent(bool on);
    void addTagFilter(qint64 tagId);
    void removeTagFilter(qint64 tagId);
    void clearTagFilters();
    // 0 = Any (OR), 1 = All (AND). Persisted via QSettings. No-op if unchanged.
    void setTagMatchMode(int mode);

    Q_INVOKABLE void filterByTag(qint64 tagId, const QString& tagName);

    bool             attachTag(qint64 wordId, qint64 tagId);
    bool             detachTag(qint64 wordId, qint64 tagId);
    QVariantList     getTagsForEntry(qint64 wordId);
    Q_INVOKABLE bool createAndAttachTag(const QString& name);

    QVariantList getAllEntries();
    QVariantList getAllTags();

    bool             createTag(const QString& name);
    bool             deleteTag(qint64 tagId);
    Q_INVOKABLE bool renameTag(qint64 tagId, const QString& name);
    Q_INVOKABLE bool isTagFiltered(qint64 tagId) const;

    // -- Multi-language (lightweight) --------------------------------
    // Each entry can be tagged with an ISO 639-1 code via setEntryLanguage.
    // currentLanguageFilter narrows searchResults to a single language;
    // empty string means all languages and is the default. Persisted in
    // QSettings under multilang/currentFilter so the filter survives
    // restarts. The Q_PROPERTY itself and its inline READ getter are
    // declared in the public: block above (moc rejects inline bodies
    // inside public slots:). Only the non-inline mutators live here.
    void                setCurrentLanguageFilter(const QString& code);
    Q_INVOKABLE bool    setEntryLanguage(qint64 entryId, const QString& code);
    Q_INVOKABLE QString entryLanguage(qint64 entryId) const;

    // Rename the entry's title. Returns true on success; on failure
    // (empty name, duplicate title) emits errorOccurred with a message
    // the UI can surface. Refreshes the search-result cache + sidebar
    // so the new title shows up everywhere the old one did.
    Q_INVOKABLE bool renameEntry(qint64 entryId, const QString& newName);

    // Called by AppViewModel after a bulk-delete operation (Settings
    // danger zone, tag-delete with affected decks). Clears active tag
    // filters, reloads the per-entry tag cache and the search-result
    // cache, and re-emits the signals every view binds to. Safe to call
    // even when nothing actually changed.
    Q_INVOKABLE void reloadAfterDataChange();

signals:
    void selectedEntryChanged();
    void editModeChanged();
    void searchQueryChanged();
    void searchInContentChanged();
    void searchResultsChanged();
    void tagFiltersChanged();
    void tagMatchModeChanged();
    void wordTagsChanged();
    void entryListChanged();
    void selectedEntryRelationsChanged();
    void currentLanguageFilterChanged();
    void lastAddedBlockIdChanged();
    void errorOccurred(const QString& msg);

private:
    void reloadContent();
    void reloadTags();
    void applySearch();
    void rebuildSearchResults();
    void rebuildActiveTagIds();

    std::shared_ptr<Service::EntryService> m_entryService;
    std::unique_ptr<ContentBlockModel>     m_contentModel;

    qint64        m_selectedWordId = -1;
    QString       m_selectedWord;
    bool          m_editMode = false;
    QString       m_searchQuery;
    bool          m_searchInContent = false;
    QVariantList  m_searchResults;
    QVariantList  m_tagFilters;
    QList<qint64> m_activeTagIds;
    int           m_tagMatchMode = 1;
    QVariantList  m_wordTags;
    QString       m_languageFilter; // kV2 -- empty = all languages
    qint64        m_lastAddedBlockId = -1;

    std::vector<Service::ContentBlock_t> m_editSnapshot;
};
