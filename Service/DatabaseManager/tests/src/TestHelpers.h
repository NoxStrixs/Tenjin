#pragma once

#include <QString>
#include <QTemporaryDir>

#include <memory>

// A unique on-disk SQLite path inside a per-test temp directory. Kept on disk
// (not :memory:) so migrations, PRAGMA user_version, and the QSQLITE driver
// behave exactly as in production. The QTemporaryDir cleans up on destruction.
class TempDb
{
public:
    TempDb() : m_dir() { m_path = m_dir.path() + "/tenjin-test.db"; }

    [[nodiscard]] std::string path() const { return m_path.toStdString(); }
    [[nodiscard]] QString     qpath() const { return m_path; }

private:
    QTemporaryDir m_dir;
    QString       m_path;
};
