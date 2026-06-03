#pragma once

#include <DatabaseManager/DatabaseManager.h>
#include <EntryService/EntryService.h>

#include <QAbstractItemModel>
#include <QAbstractListModel>
#include <QObject>
#include <QString>

#include <functional>
#include <memory>
#include <vector>

class SidebarModel : public QAbstractListModel
{
    Q_OBJECT

public:
    enum Role_t {
        IdRole = Qt::UserRole + 1,
        NameRole,
        IsTagRole,
        ExpandedRole,
    };

    explicit SidebarModel(QObject* parent = nullptr);

    using EntryFetcher_t = std::function<std::vector<Service::Entry_t>(Service::ID_t)>;

    void setData(const std::vector<Service::Tag_t>& tags, EntryFetcher_t wordFetcher);

    int                    rowCount(const QModelIndex& parent = {}) const override;
    QVariant               data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    // tagRow is the flat row index of a tag row.
    Q_INVOKABLE void toggleExpanded(int tagRow);

private:
    struct EntryItem_t {
        Service::ID_t id;
        QString       name;
    };
    struct TagItem_t {
        Service::ID_t            id;
        QString                  name;
        bool                     expanded = false;
        std::vector<EntryItem_t> words;
    };

    // A single visible row in the flat list.
    struct Row_t {
        bool          isTag;
        Service::ID_t id;
        QString       name;
        bool          expanded; // tag rows only
        int           tagIndex; // index into m_tags this row belongs to
    };

    void rebuildRows();

    std::vector<TagItem_t> m_tags;
    std::vector<Row_t>     m_rows;
};

class SidebarViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(SidebarModel* model READ model CONSTANT)
    Q_PROPERTY(QString filterText READ filterText WRITE setFilterText NOTIFY filterTextChanged)
    Q_PROPERTY(bool collapsed READ collapsed WRITE setCollapsed NOTIFY collapsedChanged)

public:
    explicit SidebarViewModel(std::shared_ptr<Service::EntryService> wordService,
                              QObject*                               parent = nullptr);

    SidebarModel* model() const
    {
        return m_model.get();
    }
    QString filterText() const
    {
        return m_filterText;
    }
    bool collapsed() const
    {
        return m_collapsed;
    }

public slots:
    void setFilterText(const QString& text);
    void setCollapsed(bool v);
    void reload();
    void onEntrySelected(qint64 wordId);
    void onTagSelected(qint64 tagId);

signals:
    void filterTextChanged();
    void collapsedChanged();
    void entrySelected(qint64 wordId);
    void tagFilterChanged(qint64 tagId, bool active);

private:
    std::shared_ptr<Service::EntryService> m_entryService;
    std::unique_ptr<SidebarModel>          m_model;

    QString m_filterText;
    bool    m_collapsed = false;
};
