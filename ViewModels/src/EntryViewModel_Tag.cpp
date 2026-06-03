#include <ViewModels/EntryViewModel.h>

#include <EntryService/EntryService.h>

#include <QSettings>

void EntryViewModel::addTagFilter(qint64 tagId)
{
    if (!isTagFiltered(tagId)) {
        m_tagFilters.append(QVariant::fromValue(tagId));
        rebuildActiveTagIds();
        emit tagFiltersChanged();
        applySearch();
    }
}

void EntryViewModel::removeTagFilter(qint64 tagId)
{
    for (int i = m_tagFilters.size() - 1; i >= 0; i--)
        if (m_tagFilters.at(i).toLongLong() == tagId)
            m_tagFilters.removeAt(i);
    rebuildActiveTagIds();
    emit tagFiltersChanged();
    applySearch();
}

void EntryViewModel::clearTagFilters()
{
    m_tagFilters.clear();
    rebuildActiveTagIds();
    emit tagFiltersChanged();
    applySearch();
}

void EntryViewModel::setTagMatchMode(int mode)
{
    const int normalized = (mode == 0) ? 0 : 1;
    if (normalized == m_tagMatchMode)
        return;
    m_tagMatchMode = normalized;
    QSettings settings;
    settings.setValue("filters/tagMatchMode", m_tagMatchMode);
    emit tagMatchModeChanged();
    if (!m_tagFilters.isEmpty())
        applySearch();
}

bool EntryViewModel::isTagFiltered(qint64 tagId) const
{
    for (const auto& v : m_tagFilters)
        if (v.toLongLong() == tagId)
            return true;
    return false;
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
    reloadTags();
    emit entryListChanged();
    return true;
}
