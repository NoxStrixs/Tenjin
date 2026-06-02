#include <DatabaseManager/Schema.h>

#include <QSqlError>
#include <QSqlQuery>
#include <QString>
#include <QStringList>

#include <stdexcept>
#include <vector>

namespace Service::Schema {
namespace {

// Migration step = the ordered SQL that upgrades the DB from version N-1
// to version N.
using Step = std::vector<const char*>;

const Step kV1 = {
    "CREATE TABLE IF NOT EXISTS entry ("
    "id INTEGER PRIMARY KEY,"
    "title TEXT NOT NULL UNIQUE,"
    "kind TEXT NOT NULL DEFAULT 'word',"
    "created_at TEXT DEFAULT (datetime('now')),"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE INDEX IF NOT EXISTS idx_entry_kind ON entry(kind);",

    "CREATE TABLE IF NOT EXISTS tag ("
    "id INTEGER PRIMARY KEY,"
    "name TEXT NOT NULL UNIQUE,"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE TABLE IF NOT EXISTS entry_tag ("
    "entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "tag_id   INTEGER REFERENCES tag(id)   ON DELETE CASCADE,"
    "PRIMARY KEY (entry_id, tag_id));",

    "CREATE TABLE IF NOT EXISTS entry_content ("
    "id       INTEGER PRIMARY KEY,"
    "entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "type     INTEGER NOT NULL,"
    "kind     TEXT NOT NULL DEFAULT 'note',"
    "content  TEXT,"
    "row      INTEGER NOT NULL,"
    "col      INTEGER NOT NULL,"
    "row_span INTEGER DEFAULT 1,"
    "col_span INTEGER DEFAULT 1,"
    "pos      TEXT DEFAULT '',"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE INDEX IF NOT EXISTS idx_entry_content_kind ON entry_content(kind);",

    "CREATE VIRTUAL TABLE IF NOT EXISTS entry_content_fts USING fts5("
    "title, content, content=entry_content, content_rowid=id);",

    "CREATE TRIGGER IF NOT EXISTS entry_content_ai AFTER INSERT ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(rowid, title, content) "
    "  SELECT NEW.id, e.title, NEW.content FROM entry e WHERE e.id = NEW.entry_id; "
    "END;",

    "CREATE TRIGGER IF NOT EXISTS entry_content_ad AFTER DELETE ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(entry_content_fts, rowid, title, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "END;",

    "CREATE TRIGGER IF NOT EXISTS entry_content_au AFTER UPDATE ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(entry_content_fts, rowid, title, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "  INSERT INTO entry_content_fts(rowid, title, content) "
    "  SELECT NEW.id, e.title, NEW.content FROM entry e WHERE e.id = NEW.entry_id; "
    "END;",

    "CREATE TABLE IF NOT EXISTS entry_relation ("
    "id               INTEGER PRIMARY KEY,"
    "entry_id         INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "related_entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "relation_type    TEXT NOT NULL);",

    "CREATE TABLE IF NOT EXISTS deck ("
    "id          INTEGER PRIMARY KEY,"
    "name        TEXT NOT NULL,"
    "is_smart    INTEGER DEFAULT 0,"
    "filter_mode TEXT DEFAULT 'AND',"
    "created_at  TEXT DEFAULT (datetime('now')),"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE TABLE IF NOT EXISTS deck_entry ("
    "deck_id  INTEGER REFERENCES deck(id)  ON DELETE CASCADE,"
    "entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "PRIMARY KEY (deck_id, entry_id));",

    "CREATE TABLE IF NOT EXISTS deck_tag_filter ("
    "deck_id INTEGER REFERENCES deck(id) ON DELETE CASCADE,"
    "tag_id  INTEGER REFERENCES tag(id)  ON DELETE CASCADE,"
    "PRIMARY KEY (deck_id, tag_id));",

    "CREATE TABLE IF NOT EXISTS review ("
    "id               INTEGER PRIMARY KEY,"
    "deck_id          INTEGER REFERENCES deck(id)  ON DELETE CASCADE,"
    "entry_id         INTEGER REFERENCES entry(id) ON DELETE CASCADE,"
    "ease_factor      REAL DEFAULT 2.5,"
    "interval_days    INTEGER DEFAULT 1,"
    "repetitions      INTEGER DEFAULT 0,"
    "next_review_date TEXT,"
    "last_review_date TEXT,"
    "UNIQUE (deck_id, entry_id));",

    "CREATE TABLE IF NOT EXISTS review_log ("
    "id            INTEGER PRIMARY KEY,"
    "deck_id       INTEGER,"
    "entry_id      INTEGER,"
    "quality       INTEGER NOT NULL,"
    "ease_factor   REAL,"
    "interval_days INTEGER,"
    "reviewed_at   INTEGER NOT NULL);",
};

// Ordered: index i upgrades to version i+1.
// Append a new Step here and bump kSchemaVersion to evolve the schema.
const std::vector<const Step*> kSteps = {&kV1};

int currentVersion(QSqlDatabase& db)
{
    QSqlQuery q(db);
    if (q.exec("PRAGMA user_version;") && q.next())
        return q.value(0).toInt();
    return 0;
}

void setVersion(QSqlDatabase& db, int v)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA user_version = %1;").arg(v)))
        throw std::runtime_error("Failed to set user_version: " +
                                 q.lastError().text().toStdString());
}

void exec(QSqlDatabase& db, const char* sql)
{
    QSqlQuery q(db);
    if (!q.exec(QString::fromUtf8(sql)))
        throw std::runtime_error("Schema step failed: " + q.lastError().text().toStdString() +
                                 " | SQL: " + std::string(sql));
}

} // namespace

void Migrate(QSqlDatabase& db)
{
    exec(db, "PRAGMA foreign_keys = ON;");

    const int from = currentVersion(db);
    const int to   = kSchemaVersion;
    if (from >= to)
        return;

    if (!db.transaction())
        throw std::runtime_error("Failed to begin migration transaction.");

    try {
        for (int v = from; v < to; v++)
            for (const char* sql : *kSteps[v])
                exec(db, sql);
    } catch (...) {
        db.rollback();
        throw;
    }

    if (!db.commit())
        throw std::runtime_error("Failed to commit migrations.");

    setVersion(db, to);
}

} // namespace Service::Schema
