#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QSet>
#include <QString>
#include <QStringList>

bool EntryViewModel::addContentBlock(int type, const QString& content)
{
    if (m_selectedWordId < 0)
        return false;

    Service::ContentBlock_t block{.id      = 0,
                                  .wordId  = m_selectedWordId,
                                  .type    = static_cast<Service::ContentType_t>(type),
                                  .content = content.toStdString(),
                                  .row     = 0, // set by append/DB
                                  .col     = 0,
                                  .rowSpan = 1,
                                  .colSpan = 1,
                                  .pos     = ""};

    if (m_editMode) {
        const auto newId = m_contentModel->appendBlock(block);
        // Surface the newly-added block id so QML delegates can pulse-
        // highlight themselves on a match. EntryDetailView resets this
        // to -1 after consuming, but a stale value is harmless — only
        // a delegate whose own id equals lastAddedBlockId reacts.
        m_lastAddedBlockId = static_cast<qint64>(newId);
        emit lastAddedBlockIdChanged();
        return true;
    }

    // Outside edit mode: persist immediately.
    block.row   = rowCountForLayout();
    auto result = m_entryService->AddContentBlock(block);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    m_lastAddedBlockId = static_cast<qint64>(result.value().id);
    emit lastAddedBlockIdChanged();
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
    if (m_editMode) {
        m_contentModel->setBlockContent(id, content);
        return true;
    }

    // Not editing: persist immediately, preserving type/position.
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
    // Capture the media path BEFORE the row is removed -- after delete
    // we can't query the content column. Only media blocks have
    // cleanup-relevant content; for everything else mediaPath stays
    // empty and cleanupOrphanedMedia is a no-op.
    QString mediaPath;
    for (const auto& b : m_contentModel->blocks()) {
        if (b.id == id && b.type == Service::ContentType_t::Media) {
            mediaPath = QString::fromStdString(b.content);
            break;
        }
    }

    if (m_editMode) {
        m_contentModel->removeBlockById(id);
        // Edit-mode deletes are staged in memory until saveLayout(),
        // so we don't actually have a row to refcount against yet.
        // Cleanup happens when saveLayout persists the removal.
        return true;
    }

    auto result = m_entryService->DeleteContentBlock(id);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadContent();
    cleanupOrphanedMedia(mediaPath);
    return true;
}

bool EntryViewModel::saveLayout()
{
    // Snapshot the DB's view of this entry's media paths BEFORE we
    // overwrite it. Anything in this set that's missing from the
    // post-save model is an orphan candidate.
    QStringList beforeMedia;
    if (m_selectedWordId >= 0) {
        auto pre = m_entryService->GetContentForEntry(m_selectedWordId);
        if (pre) {
            for (const auto& b : *pre)
                if (b.type == Service::ContentType_t::Media)
                    beforeMedia.append(QString::fromStdString(b.content));
        }
    }

    auto result = m_entryService->SaveContentLayout(m_contentModel->blocks());
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }

    // Build the post-save set of media paths from the model we just
    // persisted (cheaper than re-querying).
    QSet<QString> afterMedia;
    for (const auto& b : m_contentModel->blocks())
        if (b.type == Service::ContentType_t::Media)
            afterMedia.insert(QString::fromStdString(b.content));

    for (const QString& p : beforeMedia) {
        if (!afterMedia.contains(p))
            cleanupOrphanedMedia(p);
    }
    return true;
}
