#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <QStringList>
#include <vector>

class LogViewModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role_t {
        LevelRole = Qt::UserRole + 1,
        MessageRole,
        TimeRole,
    };

    explicit LogViewModel(QObject* parent = nullptr) : QAbstractListModel(parent) {}

    int rowCount(const QModelIndex& parent = {}) const override
    {
        if (parent.isValid())
            return 0;
        return static_cast<int>(m_entries.size());
    }

    QVariant data(const QModelIndex& index, int role) const override
    {
        if (!index.isValid() || index.row() >= static_cast<int>(m_entries.size()))
            return {};
        const auto& e = m_entries[index.row()];
        switch (role) {
        case LevelRole:
            return e.level;
        case MessageRole:
            return e.message;
        case TimeRole:
            return e.time;
        }
        return {};
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {{LevelRole, "level"}, {MessageRole, "message"}, {TimeRole, "time"}};
    }

    // Called from the message handler (any thread) via QueuedConnection.
    Q_INVOKABLE void append(const QString& level, const QString& message)
    {
        const int row = static_cast<int>(m_entries.size());
        beginInsertRows({}, row, row);
        m_entries.push_back({level, message, QDateTime::currentDateTime().toString("HH:mm:ss")});
        endInsertRows();

        constexpr int kMax = 2000;
        if (static_cast<int>(m_entries.size()) > kMax) {
            beginRemoveRows({}, 0, 0);
            m_entries.erase(m_entries.begin());
            endRemoveRows();
        }

        emit countChanged();
    }

    Q_INVOKABLE void clear()
    {
        beginResetModel();
        m_entries.clear();
        endResetModel();
        emit countChanged();
    }

    // Returns the last `maxLines` log entries as "HH:mm:ss [level] message" strings.
    // Called from QML before postReport so CloudService receives a log snapshot
    // without needing a direct pointer to this model.
    Q_INVOKABLE QStringList snapshot(int maxLines = 200) const
    {
        QStringList out;
        const int   total = static_cast<int>(m_entries.size());
        const int   start = qMax(0, total - maxLines);
        out.reserve(total - start);
        for (int i = start; i < total; ++i) {
            const auto& e = m_entries[i];
            out.append(QStringLiteral("[%1] %2  %3").arg(e.time, e.level, e.message));
        }
        return out;
    }

signals:
    void countChanged();

private:
    struct Entry_t {
        QString level;
        QString message;
        QString time;
    };
    std::vector<Entry_t> m_entries;
};
