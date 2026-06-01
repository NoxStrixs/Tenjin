#include <DatabaseManager/Schema.h>

#include <QSqlError>
#include <QSqlQuery>
#include <QString>
#include <QStringList>

#include <stdexcept>
#include <vector>

namespace Service::Schema {
namespace {

// One migration step = the ordered SQL that upgrades the DB from version N-1
// to version N. steps[0] -> v1, steps[1] -> v2, ...
using Step = std::vector<const char*>;

// ── v1: baseline word-centric schema ────────────────────────────────────────
// Mirrors the original constructor SQL (now expressed as CREATE ... IF NOT
// EXISTS so it's a safe no-op on databases that already had it). guid /
// updated_at are included directly here for fresh DBs; pre-existing DBs that
// lacked them are handled by EnsureColumns() below before migrations run.
const Step kV1 = {
    "CREATE TABLE IF NOT EXISTS word ("
    "id INTEGER PRIMARY KEY,"
    "word TEXT NOT NULL UNIQUE,"
    "created_at TEXT DEFAULT (datetime('now')),"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE TABLE IF NOT EXISTS tag ("
    "id INTEGER PRIMARY KEY,"
    "name TEXT NOT NULL UNIQUE,"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE TABLE IF NOT EXISTS word_tag ("
    "word_id INTEGER REFERENCES word(id) ON DELETE CASCADE,"
    "tag_id  INTEGER REFERENCES tag(id)  ON DELETE CASCADE,"
    "PRIMARY KEY (word_id, tag_id));",

    "CREATE TABLE IF NOT EXISTS word_content ("
    "id       INTEGER PRIMARY KEY,"
    "word_id  INTEGER REFERENCES word(id) ON DELETE CASCADE,"
    "type     INTEGER NOT NULL,"
    "content  TEXT,"
    "row      INTEGER NOT NULL,"
    "col      INTEGER NOT NULL,"
    "row_span INTEGER DEFAULT 1,"
    "col_span INTEGER DEFAULT 1,"
    "pos      TEXT DEFAULT '',"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE VIRTUAL TABLE IF NOT EXISTS word_content_fts USING fts5("
    "word_name, content, content=word_content, content_rowid=id);",

    "CREATE TRIGGER IF NOT EXISTS word_content_ai AFTER INSERT ON word_content BEGIN "
    "  INSERT INTO word_content_fts(rowid, word_name, content) "
    "  SELECT NEW.id, w.word, NEW.content FROM word w WHERE w.id = NEW.word_id; "
    "END;",

    "CREATE TRIGGER IF NOT EXISTS word_content_ad AFTER DELETE ON word_content BEGIN "
    "  INSERT INTO word_content_fts(word_content_fts, rowid, word_name, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "END;",

    "CREATE TRIGGER IF NOT EXISTS word_content_au AFTER UPDATE ON word_content BEGIN "
    "  INSERT INTO word_content_fts(word_content_fts, rowid, word_name, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "  INSERT INTO word_content_fts(rowid, word_name, content) "
    "  SELECT NEW.id, w.word, NEW.content FROM word w WHERE w.id = NEW.word_id; "
    "END;",

    "CREATE TABLE IF NOT EXISTS word_relation ("
    "id              INTEGER PRIMARY KEY,"
    "word_id         INTEGER REFERENCES word(id) ON DELETE CASCADE,"
    "related_word_id INTEGER REFERENCES word(id) ON DELETE CASCADE,"
    "relation_type   TEXT NOT NULL);",

    "CREATE TABLE IF NOT EXISTS deck ("
    "id          INTEGER PRIMARY KEY,"
    "name        TEXT NOT NULL,"
    "is_smart    INTEGER DEFAULT 0,"
    "filter_mode TEXT DEFAULT 'AND',"
    "created_at  TEXT DEFAULT (datetime('now')),"
    "guid TEXT DEFAULT '',"
    "updated_at INTEGER DEFAULT 0);",

    "CREATE TABLE IF NOT EXISTS deck_word ("
    "deck_id INTEGER REFERENCES deck(id) ON DELETE CASCADE,"
    "word_id INTEGER REFERENCES word(id) ON DELETE CASCADE,"
    "PRIMARY KEY (deck_id, word_id));",

    "CREATE TABLE IF NOT EXISTS deck_tag_filter ("
    "deck_id INTEGER REFERENCES deck(id) ON DELETE CASCADE,"
    "tag_id  INTEGER REFERENCES tag(id)  ON DELETE CASCADE,"
    "PRIMARY KEY (deck_id, tag_id));",

    "CREATE TABLE IF NOT EXISTS review ("
    "id               INTEGER PRIMARY KEY,"
    "deck_id          INTEGER REFERENCES deck(id)  ON DELETE CASCADE,"
    "word_id          INTEGER REFERENCES word(id)  ON DELETE CASCADE,"
    "ease_factor      REAL DEFAULT 2.5,"
    "interval_days    INTEGER DEFAULT 1,"
    "repetitions      INTEGER DEFAULT 0,"
    "next_review_date TEXT,"
    "last_review_date TEXT,"
    "UNIQUE (deck_id, word_id));",

    "CREATE TABLE IF NOT EXISTS review_log ("
    "id            INTEGER PRIMARY KEY,"
    "deck_id       INTEGER,"
    "word_id       INTEGER,"
    "quality       INTEGER NOT NULL,"
    "ease_factor   REAL,"
    "interval_days INTEGER,"
    "reviewed_at   INTEGER NOT NULL);",
};

// ── v2: word → entry generalization ──────────────────────────────────────────
// A "word" becomes one kind of entry. We rebuild the spine so every reusable
// subsystem keys on entry_id; words are entries with kind='word'.
//
// Strategy: rename the word table and add a `kind` column (SQLite RENAME keeps
// data + rowids, so all existing word_id values stay valid as entry_id). The
// association/child tables keep their physical column data but are renamed for
// clarity; their integer values are unchanged, so foreign keys still line up.
// FTS + triggers are dropped and recreated against entry. All inside one
// transaction via the runner below.
const Step kV2 = {
    // entry = the generalized record. Rename preserves ids.
    "ALTER TABLE word RENAME TO entry;",
    "ALTER TABLE entry RENAME COLUMN word TO title;",
    "ALTER TABLE entry ADD COLUMN kind TEXT NOT NULL DEFAULT 'word';",

    // content blocks now belong to an entry
    "ALTER TABLE word_content RENAME TO entry_content;",
    "ALTER TABLE entry_content RENAME COLUMN word_id TO entry_id;",

    // tag association
    "ALTER TABLE word_tag RENAME TO entry_tag;",
    "ALTER TABLE entry_tag RENAME COLUMN word_id TO entry_id;",

    // relations
    "ALTER TABLE word_relation RENAME TO entry_relation;",
    "ALTER TABLE entry_relation RENAME COLUMN word_id TO entry_id;",
    "ALTER TABLE entry_relation RENAME COLUMN related_word_id TO related_entry_id;",

    // deck membership
    "ALTER TABLE deck_word RENAME TO deck_entry;",
    "ALTER TABLE deck_entry RENAME COLUMN word_id TO entry_id;",

    // review scheduling
    "ALTER TABLE review RENAME COLUMN word_id TO entry_id;",
    // review_log columns are loose (no FK); rename for consistency
    "ALTER TABLE review_log RENAME COLUMN word_id TO entry_id;",

    // Rebuild FTS against entry/entry_content.
    "DROP TRIGGER IF EXISTS word_content_ai;",
    "DROP TRIGGER IF EXISTS word_content_ad;",
    "DROP TRIGGER IF EXISTS word_content_au;",
    "DROP TABLE IF EXISTS word_content_fts;",

    "CREATE VIRTUAL TABLE entry_content_fts USING fts5("
    "title, content, content=entry_content, content_rowid=id);",

    // Repopulate the FTS index from existing rows.
    "INSERT INTO entry_content_fts(rowid, title, content) "
    "  SELECT ec.id, e.title, ec.content "
    "  FROM entry_content ec JOIN entry e ON e.id = ec.entry_id;",

    "CREATE TRIGGER entry_content_ai AFTER INSERT ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(rowid, title, content) "
    "  SELECT NEW.id, e.title, NEW.content FROM entry e WHERE e.id = NEW.entry_id; "
    "END;",

    "CREATE TRIGGER entry_content_ad AFTER DELETE ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(entry_content_fts, rowid, title, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "END;",

    "CREATE TRIGGER entry_content_au AFTER UPDATE ON entry_content BEGIN "
    "  INSERT INTO entry_content_fts(entry_content_fts, rowid, title, content) "
    "  VALUES('delete', OLD.id, '', ''); "
    "  INSERT INTO entry_content_fts(rowid, title, content) "
    "  SELECT NEW.id, e.title, NEW.content FROM entry e WHERE e.id = NEW.entry_id; "
    "END;",

    "CREATE INDEX IF NOT EXISTS idx_entry_kind ON entry(kind);",
};

// ── v3: type-blind content blocks ─────────────────────────────────────────────
// Add a stable string discriminator `kind` to content blocks and backfill it
// from the legacy integer `type` (0=definition, 1=media, 2=note, 3=divider).
// The integer `type` column is retained for now so existing read paths keep
// working; new code should branch on `kind`. Adding a new block kind (e.g.
// "formula") is henceforth an INSERT with kind='formula' — no schema change.
const Step kV3 = {
    "ALTER TABLE entry_content ADD COLUMN kind TEXT NOT NULL DEFAULT 'note';",
    "UPDATE entry_content SET kind = CASE type "
    "  WHEN 0 THEN 'definition' "
    "  WHEN 1 THEN 'media' "
    "  WHEN 2 THEN 'note' "
    "  WHEN 3 THEN 'divider' "
    "  ELSE 'note' END;",
    "CREATE INDEX IF NOT EXISTS idx_entry_content_kind ON entry_content(kind);",
};

// Ordered: index i upgrades to version i+1.
const std::vector<const Step*> kSteps = {&kV1, &kV2, &kV3};

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

// Pre-migration safety net for the oldest real databases: ensure guid /
// updated_at exist before v1's CREATE IF NOT EXISTS is skipped on them.
// (No-op on fresh DBs, where the tables don't yet exist.)
void ensureLegacyColumns(QSqlDatabase& db)
{
    auto tableExists = [&](const QString& t) {
        QSqlQuery q(db);
        q.prepare("SELECT 1 FROM sqlite_master WHERE type='table' AND name=:t;");
        q.bindValue(":t", t);
        return q.exec() && q.next();
    };
    auto hasColumn = [&](const QString& t, const QString& c) {
        QSqlQuery q(db);
        if (!q.exec(QStringLiteral("PRAGMA table_info(%1);").arg(t)))
            return false;
        while (q.next())
            if (q.value(1).toString() == c)
                return true;
        return false;
    };
    auto ensure = [&](const QString& t, const QString& c, const QString& decl) {
        if (tableExists(t) && !hasColumn(t, c))
            exec(db, QStringLiteral("ALTER TABLE %1 ADD COLUMN %2 %3;")
                         .arg(t, c, decl).toUtf8().constData());
    };

    if (tableExists("word_content"))
        ensure("word_content", "pos", "TEXT DEFAULT ''");
    for (const QString& t : {QStringLiteral("word"), QStringLiteral("tag"),
                             QStringLiteral("deck"), QStringLiteral("word_content")}) {
        ensure(t, "guid", "TEXT DEFAULT ''");
        ensure(t, "updated_at", "INTEGER DEFAULT 0");
    }
}

} // namespace

void Migrate(QSqlDatabase& db)
{
    exec(db, "PRAGMA foreign_keys = ON;");

    const int from = currentVersion(db);
    const int to   = kSchemaVersion;
    if (from >= to)
        return;

    // Patch legacy DBs (version 0 that predate guid/updated_at) before running
    // step SQL, so v2's title/content references resolve.
    if (from == 0)
        ensureLegacyColumns(db);

    if (!db.transaction())
        throw std::runtime_error("Failed to begin migration transaction.");

    try {
        for (int v = from; v < to; ++v)
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
