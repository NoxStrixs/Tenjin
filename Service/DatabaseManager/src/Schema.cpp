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

// Single consolidated schema (version 1). Pre-release: there are no databases
// in the wild to migrate from, so the former kV2 (language) and kV3 (leech)
// migrations are folded directly into the base table definitions below.
const Step kV1 = {
    "CREATE TABLE IF NOT EXISTS entry ("
    "id INTEGER PRIMARY KEY,"
    "title TEXT NOT NULL UNIQUE,"
    "kind TEXT NOT NULL DEFAULT 'word',"
    "created_at TEXT DEFAULT (datetime('now')),"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0,"
    "language TEXT NOT NULL DEFAULT '');",

    "CREATE INDEX IF NOT EXISTS idx_entry_kind ON entry(kind);",
    "CREATE INDEX IF NOT EXISTS idx_entry_language ON entry(language);",

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
    "updated_at INTEGER DEFAULT 0,"
    "new_cards_per_day INTEGER NOT NULL DEFAULT 20,"
    // Scheduler per deck: 'sm2' (default, unchanged for existing decks) or
    // 'fsrs'. fsrs_retention is the FSRS desired-recall target (0.7..0.97).
    "scheduler TEXT NOT NULL DEFAULT 'sm2',"
    "fsrs_retention REAL NOT NULL DEFAULT 0.9,"
    // Optimized FSRS weights as a JSON array of 19 numbers, empty = use
    // defaults. Populated by the optimizer from the deck's review history.
    "fsrs_weights TEXT NOT NULL DEFAULT '');",

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
    "lapses           INTEGER NOT NULL DEFAULT 0,"
    "is_leech         INTEGER NOT NULL DEFAULT 0,"
    // FSRS-5 memory state. stability/difficulty are 0 until a card's first FSRS
    // review; SM-2 cards leave them untouched. These coexist with the SM-2
    // columns so a deck can switch schedulers without losing history.
    "stability        REAL NOT NULL DEFAULT 0,"
    "difficulty       REAL NOT NULL DEFAULT 0,"
    // Per-deletion cloze scheduling: 0 = the entry's normal card; 1,2,3… map to
    // cloze deletions c1,c2,c3 so each schedules independently. Non-cloze
    // entries only ever use ordinal 0.
    "cloze_ordinal    INTEGER NOT NULL DEFAULT 0,"
    "next_review_date TEXT,"
    "last_review_date TEXT,"
    "UNIQUE (deck_id, entry_id, cloze_ordinal));",

    "CREATE TABLE IF NOT EXISTS review_log ("
    "id            INTEGER PRIMARY KEY,"
    "deck_id       INTEGER,"
    "entry_id      INTEGER,"
    "quality       INTEGER NOT NULL,"
    "ease_factor   REAL,"
    "interval_days INTEGER,"
    "reviewed_at   INTEGER NOT NULL);",
};

// Single-version schema: everything is created by kV1. New schema changes
// pre-release should edit the kV1 tables directly; post-release, reintroduce
// an ordered migration step here and bump kSchemaVersion.
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

// Drop every user table so the consolidated schema can be recreated from
// scratch. PRE-RELEASE ONLY: there is no migration path from older dev
// databases (the kV2/kV3 migrations were folded into the base schema), so a DB
// whose user_version doesn't match the current schema is simply rebuilt. This
// is safe before launch; once shipped, replace this with real migrations.
void dropAllTables(QSqlDatabase& db)
{
    QSqlQuery   q(db);
    QStringList tables;
    if (q.exec("SELECT name FROM sqlite_master WHERE type='table' "
               "AND name NOT LIKE 'sqlite_%';")) {
        while (q.next())
            tables << q.value(0).toString();
    }
    exec(db, "PRAGMA foreign_keys = OFF;");
    for (const QString& t : tables)
        exec(db, QStringLiteral("DROP TABLE IF EXISTS %1;").arg(t).toUtf8().constData());
    exec(db, "PRAGMA foreign_keys = ON;");
}

void Migrate(QSqlDatabase& db)
{
    exec(db, "PRAGMA foreign_keys = ON;");

    const int from = currentVersion(db);
    const int to   = kSchemaVersion;

    // Already current.
    if (from == to)
        return;

    // Pre-release policy: any non-empty database whose version does not match
    // the current consolidated schema is wiped and recreated, because no forward
    // migration path exists from the pre-consolidation layouts. A brand-new DB
    // reports version 0 and simply has the schema created below.
    if (from != 0 && from != to) {
        dropAllTables(db);
    }

    if (!db.transaction())
        throw std::runtime_error("Failed to begin schema-build transaction.");

    try {
        // Single consolidated schema (kV1) recreates every table.
        for (const char* sql : *kSteps[0])
            exec(db, sql);
        setVersion(db, to);
    } catch (...) {
        db.rollback();
        throw;
    }

    if (!db.commit())
        throw std::runtime_error("Failed to commit schema build.");
}

} // namespace Service::Schema
