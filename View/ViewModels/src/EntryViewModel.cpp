#include <EntryService/EntryService.h>
#include <ViewModels/EntryViewModel.h>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QUrl>

#include <algorithm>

// ── ContentBlockModel ─────────────────────────────────────────────────────────

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

    // beginMoveRows wants the destination row in the *pre-move* coordinate
    // space; when moving downward Qt expects to + 1.
    if (!beginMoveRows({}, from, from, {}, to > from ? to + 1 : to))
        return;

    auto first = m_blocks.begin() + from;
    if (to > from) {
        // Rotate the [from, to] window left by one so `from` lands at `to`.
        std::rotate(first, first + 1, m_blocks.begin() + to + 1);
    } else {
        // Rotate the [to, from] window right by one.
        std::rotate(m_blocks.begin() + to, first, first + 1);
    }

    // Renumber row indices so they stay contiguous and match visual order.
    for (int i = 0; i < static_cast<int>(m_blocks.size()); ++i)
        m_blocks[i].row = i;

    endMoveRows();
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
    for (int i = 0; i < static_cast<int>(m_blocks.size()); ++i) {
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
    for (int i = 0; i < static_cast<int>(m_blocks.size()); ++i) {
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
    for (int i = 0; i < static_cast<int>(m_blocks.size()); ++i) {
        if (m_blocks[i].id == id) {
            m_blocks[i].pos       = pos.toStdString();
            const QModelIndex idx = index(i, 0);
            emit              dataChanged(idx, idx);
            return;
        }
    }
}

// ── EntryViewModel ─────────────────────────────────────────────────────────────

EntryViewModel::EntryViewModel(std::shared_ptr<Service::EntryService> wordService, QObject* parent)
    : QObject(parent), m_entryService(std::move(wordService)),
      m_contentModel(std::make_unique<ContentBlockModel>(this))
{
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

bool EntryViewModel::addWord(const QString& word)
{
    auto result = m_entryService->CreateWord(word.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    emit entryListChanged();
    return true;
}

bool EntryViewModel::deleteEntry(qint64 wordId)
{
    auto result = m_entryService->DeleteEntry(wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedWordId == wordId)
        clearSelection();
    emit entryListChanged();
    return true;
}

bool EntryViewModel::addContentBlock(int type, const QString& content)
{
    if (m_selectedWordId < 0)
        return false;
    // Append at the end: next row index, single cell.
    const int               nextRow = rowCountForLayout();
    Service::ContentBlock_t block{.id      = 0,
                                  .wordId  = m_selectedWordId,
                                  .type    = static_cast<Service::ContentType_t>(type),
                                  .content = content.toStdString(),
                                  .row     = nextRow,
                                  .col     = 0,
                                  .rowSpan = 1,
                                  .colSpan = 1,
                                  .pos     = ""};
    auto                    result = m_entryService->AddContentBlock(block);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadContent();
    return true;
}

bool EntryViewModel::updateContentBlock(
    qint64 id, int type, const QString& content, int row, int col, int rowSpan, int colSpan)
{
    Service::ContentBlock_t block{.id      = id,
                                  .wordId  = m_selectedWordId,
                                  .type    = static_cast<Service::ContentType_t>(type),
                                  .content = content.toStdString(),
                                  .row     = row,
                                  .col     = col,
                                  .rowSpan = rowSpan,
                                  .colSpan = colSpan,
                                  .pos     = ""};
    auto                    result = m_entryService->UpdateContentBlock(block);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadContent();
    return true;
}

bool EntryViewModel::updateContentBlockText(qint64 id, const QString& content)
{
    // During an edit session, stage the change in the model only so cancelEdit()
    // can revert; saveEdit() persists everything via SaveContentLayout().
    if (m_editMode) {
        m_contentModel->setBlockContent(id, content);
        return true;
    }

    // Not editing (defensive): persist immediately, preserving type/position.
    const auto* existing = m_contentModel->findById(id);
    if (!existing) {
        emit errorOccurred(QStringLiteral("Cannot update: block %1 not found.").arg(id));
        return false;
    }
    Service::ContentBlock_t block = *existing;
    block.content                 = content.toStdString();

    auto result = m_entryService->UpdateContentBlock(block);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadContent();
    return true;
}

void EntryViewModel::moveContentBlock(int from, int to)
{
    m_contentModel->moveBlock(from, to);
}

void EntryViewModel::setBlockPosition(qint64 id, int row, int col)
{
    const auto* b = m_contentModel->findById(id);
    if (!b)
        return;
    m_contentModel->setBlockGrid(id, row, col, b->rowSpan, b->colSpan);
    if (!m_editMode)
        saveLayout();
}

void EntryViewModel::setBlockSpan(qint64 id, int rowSpan, int colSpan)
{
    const auto* b = m_contentModel->findById(id);
    if (!b)
        return;
    m_contentModel->setBlockGrid(id, b->row, b->col, rowSpan, colSpan);
    if (!m_editMode)
        saveLayout();
}

void EntryViewModel::setBlockPartOfSpeech(qint64 id, const QString& pos)
{
    if (!m_contentModel->findById(id))
        return;
    m_contentModel->setBlockPos(id, pos);
    if (!m_editMode)
        saveLayout();
}

int EntryViewModel::rowCountForLayout() const
{
    int maxRow = -1;
    for (const auto& b : m_contentModel->blocks())
        maxRow = std::max(maxRow, b.row);
    return maxRow + 1;
}

bool EntryViewModel::deleteContentBlock(qint64 id)
{
    auto result = m_entryService->DeleteContentBlock(id);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadContent();
    return true;
}

bool EntryViewModel::saveLayout()
{
    auto result = m_entryService->SaveContentLayout(m_contentModel->blocks());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    return true;
}

// ── Media ───────────────────────────────────────────────────────────────────

namespace {
// Directory where imported media is stored: <AppData>/media
QString mediaDir()
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return base + QStringLiteral("/media");
}
} // namespace

QString EntryViewModel::importMedia(const QString& sourceUrl)
{
    // Accept either a file:// URL (from FileDialog) or a plain local path.
    QString src = sourceUrl;
    if (src.startsWith(QStringLiteral("file:")))
        src = QUrl(src).toLocalFile();

    const QFileInfo info(src);
    if (!info.exists() || !info.isFile()) {
        emit errorOccurred(QStringLiteral("File not found: %1").arg(src));
        return {};
    }

    const QString dir = mediaDir();
    if (!QDir().mkpath(dir)) {
        emit errorOccurred(QStringLiteral("Could not create media directory."));
        return {};
    }

    // Build a unique destination name to avoid clobbering existing files.
    const QString baseName = info.completeBaseName();
    const QString suffix =
        info.suffix().isEmpty() ? QString() : QStringLiteral(".") + info.suffix();
    QString fileName = info.fileName();
    QString dest     = dir + QStringLiteral("/") + fileName;
    for (int n = 1; QFile::exists(dest); ++n) {
        fileName = QStringLiteral("%1_%2%3").arg(baseName).arg(n).arg(suffix);
        dest     = dir + QStringLiteral("/") + fileName;
    }

    if (!QFile::copy(src, dest)) {
        emit errorOccurred(QStringLiteral("Failed to copy media file."));
        return {};
    }

    // Store only the relative file name so the DB stays portable.
    return fileName;
}

QString EntryViewModel::resolveMediaUrl(const QString& storedPath) const
{
    if (storedPath.isEmpty())
        return {};

    // Already a URL — pass through.
    if (storedPath.startsWith(QStringLiteral("file:")))
        return storedPath;

    QFileInfo info(storedPath);
    // Legacy absolute paths resolve directly; relative paths live in the media dir.
    const QString abs =
        info.isAbsolute() ? storedPath : mediaDir() + QStringLiteral("/") + storedPath;
    return QUrl::fromLocalFile(abs).toString();
}

void EntryViewModel::setSearchQuery(const QString& q)
{
    if (m_searchQuery == q)
        return;
    m_searchQuery = q;
    emit searchQueryChanged();
    rebuildSearchResults();
    applySearch();
}

void EntryViewModel::setSearchInContent(bool on)
{
    if (m_searchInContent == on)
        return;
    m_searchInContent = on;
    emit searchInContentChanged();
    rebuildSearchResults();
    applySearch();
}

void EntryViewModel::rebuildSearchResults()
{
    m_searchResults.clear();

    const std::string q = m_searchQuery.trimmed().toStdString();
    if (!q.empty()) {
        // Tag suggestions first (clicking filters the word list).
        if (auto tags = m_entryService->SearchTagsByName(q)) {
            for (const auto& t : *tags) {
                QVariantMap m;
                m["kind"]  = QStringLiteral("tag");
                m["id"]    = QVariant::fromValue(t.id);
                m["label"] = QString::fromStdString(t.name);
                m_searchResults.append(m);
            }
        }
        // Word suggestions (clicking opens that word).
        if (auto words = m_entryService->SearchEntriesByName(q, m_searchInContent)) {
            const QString ql = m_searchQuery.trimmed().toLower();
            for (const auto& w : *words) {
                QVariantMap m;
                m["kind"]  = QStringLiteral("word");
                m["id"]    = QVariant::fromValue(w.id);
                m["label"] = QString::fromStdString(w.word);

                // If content search is on and the word *name* doesn't itself
                // contain the query, surface the matching content line.
                QString snippet;
                if (m_searchInContent && !QString::fromStdString(w.word).toLower().contains(ql)) {
                    if (auto blocks = m_entryService->GetContentForEntry(w.id)) {
                        for (const auto& b : *blocks) {
                            const QString c   = QString::fromStdString(b.content);
                            const int     idx = c.toLower().indexOf(ql);
                            if (idx >= 0) {
                                // ~60-char window around the match.
                                const int start = std::max(0, idx - 20);
                                snippet = (start > 0 ? QStringLiteral("…") : QString()) +
                                          c.mid(start, 60).simplified() +
                                          (c.size() > start + 60 ? QStringLiteral("…") : QString());
                                break;
                            }
                        }
                    }
                }
                m["snippet"] = snippet;
                m_searchResults.append(m);
            }
        }
    }
    emit searchResultsChanged();
}

void EntryViewModel::filterByTag(qint64 tagId, const QString& tagName)
{
    // Clear text search, set a single tag filter, refresh the list.
    m_searchQuery.clear();
    emit searchQueryChanged();
    m_searchResults.clear();
    emit searchResultsChanged();

    m_tagFilters.clear();
    m_tagFilters.append(QVariant::fromValue(tagId));
    emit tagFiltersChanged();
    applySearch();
}

bool EntryViewModel::createAndAttachTag(const QString& name)
{
    if (m_selectedWordId < 0)
        return false;
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty())
        return false;

    auto tag = m_entryService->GetOrCreateTag(trimmed.toStdString());
    if (!tag) {
        emit errorOccurred(QString::fromStdString(tag.error()));
        return false;
    }

    auto attached = m_entryService->AddTagToEntry(m_selectedWordId, tag->id);
    if (!attached) {
        emit errorOccurred(QString::fromStdString(attached.error()));
        return false;
    }
    reloadTags();
    emit entryListChanged(); // tag list in sidebar may have grown
    return true;
}

void EntryViewModel::addTagFilter(qint64 tagId)
{
    if (!isTagFiltered(tagId)) {
        m_tagFilters.append(QVariant::fromValue(tagId));
        emit tagFiltersChanged();
        applySearch();
    }
}

void EntryViewModel::removeTagFilter(qint64 tagId)
{
    for (int i = m_tagFilters.size() - 1; i >= 0; --i)
        if (m_tagFilters.at(i).toLongLong() == tagId)
            m_tagFilters.removeAt(i);
    emit tagFiltersChanged();
    applySearch();
}

void EntryViewModel::clearTagFilters()
{
    m_tagFilters.clear();
    emit tagFiltersChanged();
    applySearch();
}

bool EntryViewModel::attachTag(qint64 wordId, qint64 tagId)
{
    auto result = m_entryService->AddTagToEntry(wordId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (wordId == m_selectedWordId)
        reloadTags();
    return true;
}

bool EntryViewModel::detachTag(qint64 wordId, qint64 tagId)
{
    auto result = m_entryService->RemoveTagFromEntry(wordId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (wordId == m_selectedWordId)
        reloadTags();
    return true;
}

QVariantList EntryViewModel::getTagsForEntry(qint64 wordId)
{
    if (wordId < 0)
        return {};
    auto result = m_entryService->GetTagsForEntry(wordId);
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

QVariantList EntryViewModel::getAllEntries()
{
    // Build search params from current query + tag filters so the sidebar word
    // list reflects the active filter state.
    Service::EntryService::SearchParams_t params;
    params.query = m_searchQuery.trimmed().toStdString();
    for (const auto& v : m_tagFilters)
        params.tagIds.push_back(v.toLongLong());

    std::vector<Service::Entry_t> words;
    if (params.query.empty() && params.tagIds.empty()) {
        auto result = m_entryService->GetAllEntries();
        if (!result)
            return {};
        words = *result;
    } else if (!params.tagIds.empty() && params.query.empty()) {
        auto result = m_entryService->Search(params);
        if (!result)
            return {};
        words = *result;
    } else {
        // Text query (optionally + tag filters): use substring/content search,
        // then intersect with tag filters if any.
        auto result = m_entryService->SearchEntriesByName(params.query, m_searchInContent);
        if (!result)
            return {};
        words = *result;
        if (!params.tagIds.empty()) {
            params.query.clear();
            auto tagged = m_entryService->Search(params);
            if (tagged) {
                std::vector<Service::Entry_t> filtered;
                for (const auto& w : words)
                    for (const auto& tw : *tagged)
                        if (tw.id == w.id) {
                            filtered.push_back(w);
                            break;
                        }
                words = filtered;
            }
        }
    }

    QVariantList out;
    for (const auto& w : words) {
        QVariantMap m;
        m["wordId"] = QVariant::fromValue(w.id);
        m["word"]   = QString::fromStdString(w.word);
        out.append(m);
    }
    return out;
}

QVariantList EntryViewModel::getAllTags()
{
    auto result = m_entryService->GetAllTags();
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

bool EntryViewModel::createTag(const QString& name)
{
    auto result = m_entryService->CreateTag(name.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    emit entryListChanged();
    return true;
}

bool EntryViewModel::deleteTag(qint64 tagId)
{
    auto result = m_entryService->DeleteTag(tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    emit entryListChanged();
    return true;
}

bool EntryViewModel::renameTag(qint64 tagId, const QString& name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) {
        emit errorOccurred(QStringLiteral("Tag name cannot be empty."));
        return false;
    }
    auto result = m_entryService->RenameTag(tagId, trimmed.toStdString());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    // The selected word's chips and any tag-driven lists may show the old name.
    reloadTags();
    emit entryListChanged();
    return true;
}

bool EntryViewModel::isTagFiltered(qint64 tagId) const
{
    for (const auto& v : m_tagFilters)
        if (v.toLongLong() == tagId)
            return true;
    return false;
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
