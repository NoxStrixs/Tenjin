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

// kV2 — multi-language support, lightweight path. Adds a per-entry
// language code column (ISO 639-1 like "en", "es", "ja"; empty string
// means "unspecified"). Existing rows default to ''. The index speeds
// up the language filter applied by EntryViewModel::currentLanguageFilter.
const Step kV2 = {
    "ALTER TABLE entry ADD COLUMN language TEXT NOT NULL DEFAULT '';",
    "CREATE INDEX IF NOT EXISTS idx_entry_language ON entry(language);",
};

const std::vector<const Step*> kSteps = {&kV1, &kV2};

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

// True when the given table has a column with this name. Used by
// Migrate() to detect partial migrations (user_version was bumped but
// the ALTER TABLE never actually landed) and re-run them.
bool columnExists(QSqlDatabase& db, const char* table, const char* column)
{
    QSqlQuery q(db);
    if (!q.exec(QStringLiteral("PRAGMA table_info(%1);").arg(table)))
        return false;
    while (q.next()) {
        if (q.value(1).toString() == QLatin1String(column))
            return true;
    }
    return false;
}

void exec(QSqlDatabase& db, const char* sql)
{
    QSqlQuery q(db);
    if (!q.exec(QString::fromUtf8(sql))) {
        const QString err = q.lastError().text();
        // SQLite returns "duplicate column name" when ALTER TABLE ADD
        // COLUMN tries to add a column that already exists. Treat this
        // as benign so migrations are idempotent: if a prior attempt
        // added the column but failed to commit user_version (e.g. the
        // process was killed between the ALTER and the PRAGMA), the
        // re-run won't blow up here.
        if (err.contains(QLatin1String("duplicate column"), Qt::CaseInsensitive))
            return;
        throw std::runtime_error("Schema step failed: " + err.toStdString() +
                                 " | SQL: " + std::string(sql));
    }
}

} // namespace

void Migrate(QSqlDatabase& db)
{
    exec(db, "PRAGMA foreign_keys = ON;");

    int       from = currentVersion(db);
    const int to   = kSchemaVersion;

    // Self-heal: if user_version claims we have kV2 schema but the
    // language column is actually missing (a partial migration left the
    // DB in a wedge state), step back one version so kV2 re-runs. The
    // duplicate-column guard in exec() makes the re-run safe even if
    // the column actually IS there. Without this check, all SELECTs
    // that read "language" silently fail and the UI looks empty even
    // though entries exist.
    if (from >= 2 && !columnExists(db, "entry", "language")) {
        from = 1;
    }

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
