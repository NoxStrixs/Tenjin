#pragma once

#include <QAbstractListModel>
#include <QDateTime>
#include <QString>
#include <vector>

// In-memory ring buffer of log messages, fed by a global Qt message handler
// (installed in main.cpp). Exposed to QML as a model so the debug console can
// display captured qDebug/qWarning/qCritical and QML console.log output.
//
// Lives in the TenjinViewModels library (include/ViewModels/LogViewModel.h).
// A single instance is created in main and registered as a context property
// ("logModel"). The message handler forwards to it on the GUI thread via a
// queued invocation so it is safe to call from any thread.
class LogViewModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

public:
    enum Role_t {
        LevelRole = Qt::UserRole + 1, // "debug" | "info" | "warning" | "critical"
        MessageRole,
        TimeRole, // formatted HH:mm:ss
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

    // Append a log line. Safe to call only on the GUI thread (callers from the
    // message handler marshal via QMetaObject::invokeMethod queued).
    Q_INVOKABLE void append(const QString& level, const QString& message)
    {
        const int row = static_cast<int>(m_entries.size());
        beginInsertRows({}, row, row);
        m_entries.push_back({level, message, QDateTime::currentDateTime().toString("HH:mm:ss")});
        // Cap the buffer so a long session doesn't grow without bound.
        constexpr int kMax = 2000;
        if (static_cast<int>(m_entries.size()) > kMax) {
            beginRemoveRows({}, 0, 0);
            m_entries.erase(m_entries.begin());
            endRemoveRows();
        }
        endInsertRows();
        emit countChanged();
    }

    Q_INVOKABLE void clear()
    {
        beginResetModel();
        m_entries.clear();
        endResetModel();
        emit countChanged();
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
