#pragma once

#include <DatabaseManager/DatabaseManager.h>
#include <EntryService/EntryService.h>

#include <QAbstractListModel>
#include <QObject>
#include <QString>
#include <QVariantList>

#include <memory>
#include <vector>

// ── ContentBlockModel ─────────────────────────────────────────────────────────
// QML-facing list model for a word's content blocks (definitions, notes, media).
// Backed by a flat std::vector kept in editor-friendly order.
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

    // Live snapshot of the underlying storage — used by EntryViewModel to commit
    // layout changes through to the service layer.
    const std::vector<Service::ContentBlock_t>& blocks() const
    {
        return m_blocks;
    }

    int                    rowCount(const QModelIndex& parent = {}) const override;
    QVariant               data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE void moveBlock(int from, int to);

    // Append a new block to the end of the model only (no DB write). Assigns a
    // temporary negative id so it's distinguishable from persisted rows; the
    // real id is assigned by the DB on saveEdit() via SaveContentLayout's
    // insert path. Returns the temp id.
    Service::ID_t appendBlock(Service::ContentBlock_t block);

    // Remove a block from the model only (no DB write). Persisted on saveEdit().
    void removeBlockById(Service::ID_t id);

    // Stage a text edit in the model only (no DB write). Persisted later by
    // EntryViewModel::saveEdit(). This lets cancelEdit() truly revert.
    void setBlockContent(Service::ID_t id, const QString& content);

    // Stage a grid-position change (row/col/span) in the model only; persisted
    // by saveEdit(). Powers drag-to-column and span resize.
    void setBlockGrid(Service::ID_t id, int row, int col, int rowSpan, int colSpan);

    // Stage a part-of-speech change (definitions only) in the model; persisted
    // by saveEdit().
    void setBlockPos(Service::ID_t id, const QString& pos);

    // Find a block by its database id. Returns nullptr if absent. Used by the
    // view model to do partial updates without losing the other fields.
    const Service::ContentBlock_t* findById(Service::ID_t id) const;

private:
    std::vector<Service::ContentBlock_t> m_blocks;
    // Decreasing counter for temporary ids of not-yet-persisted blocks added
    // during an edit session. Negative so they never collide with DB ids (>0).
    Service::ID_t m_nextTempId = -1;
};

// ── EntryViewModel ─────────────────────────────────────────────────────────────
class EntryViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(ContentBlockModel* contentModel READ contentModel CONSTANT)
    Q_PROPERTY(qint64 selectedEntryId READ selectedEntryId NOTIFY selectedEntryChanged)
    Q_PROPERTY(QString selectedWord READ selectedWord NOTIFY selectedEntryChanged)
    Q_PROPERTY(bool editMode READ editMode NOTIFY editModeChanged)
    Q_PROPERTY(QString searchQuery READ searchQuery WRITE setSearchQuery NOTIFY searchQueryChanged)
    // When true, the search dropdown also matches words by their content blocks.
    Q_PROPERTY(bool searchInContent READ searchInContent WRITE setSearchInContent NOTIFY
                   searchInContentChanged)
    // Live dropdown results for the current searchQuery: a list of maps with
    // keys {kind:"word"|"tag", id, label}.
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(QVariantList tagFilters READ tagFilters NOTIFY tagFiltersChanged)
    // Tags attached to the currently selected word. Reactive so QML tag chips
    // refresh automatically when a tag is attached/detached.
    Q_PROPERTY(QVariantList wordTags READ wordTags NOTIFY wordTagsChanged)

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
    QVariantList wordTags() const
    {
        return m_wordTags;
    }

public slots:
    // Selection
    void selectEntry(qint64 wordId);
    void clearSelection();

    // Edit mode
    void beginEdit();
    void saveEdit();
    void cancelEdit();

    // Word CRUD
    bool addWord(const QString& word);
    bool deleteEntry(qint64 wordId);

    // Content block CRUD
    // Appends a new block of `type` at the end of the current list. The caller
    // does not need to know about grid coordinates — the view model assigns the
    // next row itself.
    bool addContentBlock(int type, const QString& content = QString());

    // Full update — every field is supplied. Kept for completeness/tests.
    bool updateContentBlock(
        qint64 id, int type, const QString& content, int row, int col, int rowSpan, int colSpan);

    // Convenience: edit only the text of an existing block. This is what the
    // QML editor calls; it preserves the block's type and position.
    bool updateContentBlockText(qint64 id, const QString& content);

    bool deleteContentBlock(qint64 id);

    // Reorder a block in the in-memory model (during edit mode). The new order
    // is persisted on saveEdit()/saveLayout().
    void moveContentBlock(int from, int to);

    // Grid editing (staged during edit mode, persisted on save):
    // Move a block to (row, col), keeping its spans.
    Q_INVOKABLE void setBlockPosition(qint64 id, int row, int col);
    // Set a block's row/col span.
    Q_INVOKABLE void setBlockSpan(qint64 id, int rowSpan, int colSpan);
    // Set a definition block's part of speech (staged; persisted on save).
    Q_INVOKABLE void setBlockPartOfSpeech(qint64 id, const QString& pos);
    // Number of distinct rows currently in the layout (for "+ column" bounds).
    Q_INVOKABLE int rowCountForLayout() const;

    bool saveLayout();

    // ── Media ─────────────────────────────────────────────────────────────────
    // Copy a picked file (given as a file:// URL or local path) into the app's
    // media directory and return the portable relative path to store in a block.
    // Returns an empty string on failure (and emits errorOccurred).
    Q_INVOKABLE QString importMedia(const QString& sourceUrl);

    // Turn a stored media path (relative to the media dir, or absolute for
    // legacy entries) into a file:// URL usable by an Image source.
    Q_INVOKABLE QString resolveMediaUrl(const QString& storedPath) const;

    // Search filters
    void setSearchQuery(const QString& q);
    void setSearchInContent(bool on);
    void addTagFilter(qint64 tagId);
    void removeTagFilter(qint64 tagId);
    void clearTagFilters();

    // Dropdown actions
    // Filter the word list to words carrying the given tag (and select Words page).
    Q_INVOKABLE void filterByTag(qint64 tagId, const QString& tagName);

    // Tag attach/detach (word-level)
    bool         attachTag(qint64 wordId, qint64 tagId);
    bool         detachTag(qint64 wordId, qint64 tagId);
    QVariantList getTagsForEntry(qint64 wordId);
    // Create the tag if it doesn't exist, then attach it to the selected word.
    Q_INVOKABLE bool createAndAttachTag(const QString& name);

    // List helpers for QML
    QVariantList getAllEntries();
    QVariantList getAllTags();

    // Global tag CRUD
    bool createTag(const QString& name);
    bool deleteTag(qint64 tagId);
    // Rename a tag everywhere. Refreshes chips + lists; false on empty/dup name.
    Q_INVOKABLE bool renameTag(qint64 tagId, const QString& name);
    // Robust active-filter test for QML (avoids QVariantList/qint64 coercion
    // pitfalls in the existing m_tagFilters storage).
    Q_INVOKABLE bool isTagFiltered(qint64 tagId) const;

signals:
    void selectedEntryChanged();
    void editModeChanged();
    void searchQueryChanged();
    void searchInContentChanged();
    void searchResultsChanged();
    void tagFiltersChanged();
    void wordTagsChanged();
    void entryListChanged();
    void errorOccurred(const QString& msg);

private:
    void reloadContent();
    void reloadTags();
    void applySearch();
    void rebuildSearchResults();

    std::shared_ptr<Service::EntryService> m_entryService;
    std::unique_ptr<ContentBlockModel>     m_contentModel;

    qint64       m_selectedWordId = -1;
    QString      m_selectedWord;
    bool         m_editMode = false;
    QString      m_searchQuery;
    bool         m_searchInContent = false;
    QVariantList m_searchResults;
    QVariantList m_tagFilters;
    QVariantList m_wordTags;

    std::vector<Service::ContentBlock_t> m_editSnapshot;
};
