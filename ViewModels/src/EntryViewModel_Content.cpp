#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

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
        m_contentModel->appendBlock(block);
        return true;
    }

    // Outside edit mode: persist immediately.
    block.row   = rowCountForLayout();
    auto result = m_entryService->AddContentBlock(block);
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
    if (m_editMode) {
        m_contentModel->removeBlockById(id);
        return true;
    }

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
