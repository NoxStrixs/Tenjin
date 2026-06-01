#include <DatabaseManager/Schema.h>

#include "TestHelpers.h"

#include <gtest/gtest.h>

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>

using namespace Service;

namespace {

int userVersion(QSqlDatabase& db)
{
    QSqlQuery q(db);
    q.exec("PRAGMA user_version;");
    q.next();
    return q.value(0).toInt();
}

// Open a connection with a unique name (so parallel tests don't collide).
QSqlDatabase openConn(const QString& path)
{
    const QString name = QUuid::createUuid().toString();
    QSqlDatabase db    = QSqlDatabase::addDatabase("QSQLITE", name);
    db.setDatabaseName(path);
    db.open();
    return db;
}

// Seed a "version 0" legacy database: the original word-centric tables, no
// user_version set, mimicking a DB created before the migration system existed.
void seedLegacyV0(QSqlDatabase& db)
{
    QSqlQuery q(db);
    q.exec("CREATE TABLE word(id INTEGER PRIMARY KEY, word TEXT NOT NULL UNIQUE, "
           "created_at TEXT);");
    q.exec("CREATE TABLE word_content(id INTEGER PRIMARY KEY, word_id INTEGER, type INTEGER "
           "NOT NULL, content TEXT, row INTEGER NOT NULL, col INTEGER NOT NULL, "
           "row_span INTEGER, col_span INTEGER, pos TEXT);");
    q.exec("CREATE TABLE tag(id INTEGER PRIMARY KEY, name TEXT UNIQUE);");
    q.exec("CREATE TABLE word_tag(word_id INTEGER, tag_id INTEGER, PRIMARY KEY(word_id,tag_id));");
    q.exec("CREATE TABLE word_relation(id INTEGER PRIMARY KEY, word_id INTEGER, "
           "related_word_id INTEGER, relation_type TEXT NOT NULL);");
    q.exec("CREATE TABLE deck(id INTEGER PRIMARY KEY, name TEXT NOT NULL, is_smart INTEGER, "
           "filter_mode TEXT, created_at TEXT);");
    q.exec("CREATE TABLE deck_word(deck_id INTEGER, word_id INTEGER, "
           "PRIMARY KEY(deck_id,word_id));");
    q.exec("CREATE TABLE deck_tag_filter(deck_id INTEGER, tag_id INTEGER, "
           "PRIMARY KEY(deck_id,tag_id));");
    q.exec("CREATE TABLE review(id INTEGER PRIMARY KEY, deck_id INTEGER, word_id INTEGER, "
           "ease_factor REAL, interval_days INTEGER, repetitions INTEGER, "
           "next_review_date TEXT, last_review_date TEXT, UNIQUE(deck_id,word_id));");
    q.exec("CREATE TABLE review_log(id INTEGER PRIMARY KEY, deck_id INTEGER, word_id INTEGER, "
           "quality INTEGER NOT NULL, ease_factor REAL, interval_days INTEGER, "
           "reviewed_at INTEGER NOT NULL);");
}

} // namespace

// A brand-new database should land directly on the latest schema version.
TEST(Schema, FreshDatabaseIsLatestVersion)
{
    TempDb       tmp;
    QSqlDatabase db = openConn(tmp.qpath());
    Schema::Migrate(db);
    EXPECT_EQ(userVersion(db), Schema::kSchemaVersion);
}

// The entry table and its FTS companion must exist after a fresh migrate.
TEST(Schema, FreshDatabaseHasEntrySchema)
{
    TempDb       tmp;
    QSqlDatabase db = openConn(tmp.qpath());
    Schema::Migrate(db);

    QSqlQuery q(db);
    ASSERT_TRUE(q.exec("SELECT name FROM sqlite_master WHERE type='table' AND name='entry';"));
    EXPECT_TRUE(q.next()) << "entry table missing";

    ASSERT_TRUE(q.exec("SELECT name FROM sqlite_master WHERE name='entry_content_fts';"));
    EXPECT_TRUE(q.next()) << "entry_content_fts missing";
}

// Migrating a legacy v0 DB must preserve rows and keep their ids stable
// (word N becomes entry N), so foreign keys in child tables stay valid.
TEST(Schema, LegacyMigrationPreservesDataAndIds)
{
    TempDb tmp;
    {
        QSqlDatabase db = openConn(tmp.qpath());
        seedLegacyV0(db);
        QSqlQuery q(db);
        q.exec("INSERT INTO word(id, word) VALUES (42, 'ephemeral');");
        q.exec("INSERT INTO word_content(id, word_id, type, content, row, col) "
                "VALUES (1, 42, 0, 'lasting a very short time', 0, 0);");
        db.close();
    }

    QSqlDatabase db = openConn(tmp.qpath());
    ASSERT_NO_THROW(Schema::Migrate(db));
    EXPECT_EQ(userVersion(db), Schema::kSchemaVersion);

    QSqlQuery q(db);
    ASSERT_TRUE(q.exec("SELECT title, kind FROM entry WHERE id = 42;"));
    ASSERT_TRUE(q.next()) << "entry 42 lost in migration";
    EXPECT_EQ(q.value(0).toString().toStdString(), "ephemeral");
    EXPECT_EQ(q.value(1).toString().toStdString(), "word");

    ASSERT_TRUE(q.exec("SELECT entry_id, content FROM entry_content WHERE id = 1;"));
    ASSERT_TRUE(q.next()) << "content block lost in migration";
    EXPECT_EQ(q.value(0).toLongLong(), 42);
    EXPECT_EQ(q.value(1).toString().toStdString(), "lasting a very short time");
}

// After migration the FTS index must be searchable via the app's join path,
// proving the rebuild repopulated it from existing rows.
TEST(Schema, LegacyMigrationRebuildsFtsIndex)
{
    TempDb tmp;
    {
        QSqlDatabase db = openConn(tmp.qpath());
        seedLegacyV0(db);
        QSqlQuery q(db);
        q.exec("INSERT INTO word(id, word) VALUES (1, 'verbose');");
        q.exec("INSERT INTO word_content(id, word_id, type, content, row, col) "
                "VALUES (1, 1, 0, 'using many words', 0, 0);");
        db.close();
    }

    QSqlDatabase db = openConn(tmp.qpath());
    Schema::Migrate(db);

    QSqlQuery q(db);
    ASSERT_TRUE(q.exec("SELECT e.title FROM entry e "
                       "JOIN entry_content ec ON ec.entry_id = e.id "
                       "JOIN entry_content_fts f ON f.rowid = ec.id "
                       "WHERE entry_content_fts MATCH 'many*';"));
    ASSERT_TRUE(q.next()) << "FTS not searchable after migration";
    EXPECT_EQ(q.value(0).toString().toStdString(), "verbose");
}

// v3 must add the kind column and backfill it from the legacy integer type.
TEST(Schema, V3BackfillsContentKindFromType)
{
    TempDb tmp;
    {
        QSqlDatabase db = openConn(tmp.qpath());
        seedLegacyV0(db);
        QSqlQuery q(db);
        q.exec("INSERT INTO word(id, word) VALUES (1, 'x');");
        // one block of each legacy type 0..3
        for (int t = 0; t <= 3; ++t)
            q.exec(QStringLiteral("INSERT INTO word_content(word_id, type, content, row, col) "
                                  "VALUES (1, %1, 'c', 0, 0);").arg(t));
        db.close();
    }

    QSqlDatabase db = openConn(tmp.qpath());
    Schema::Migrate(db);

    QSqlQuery q(db);
    ASSERT_TRUE(q.exec("SELECT type, kind FROM entry_content ORDER BY type;"));
    const char* expected[] = {"definition", "media", "note", "divider"};
    int         i          = 0;
    while (q.next()) {
        ASSERT_LT(i, 4);
        EXPECT_EQ(q.value(1).toString().toStdString(), expected[i]) << "type " << i;
        ++i;
    }
    EXPECT_EQ(i, 4);
}

// Running Migrate twice must be a no-op the second time (idempotent), never
// throwing or double-applying.
TEST(Schema, MigrationIsIdempotent)
{
    TempDb       tmp;
    QSqlDatabase db = openConn(tmp.qpath());
    Schema::Migrate(db);
    const int first = userVersion(db);
    ASSERT_NO_THROW(Schema::Migrate(db));
    EXPECT_EQ(userVersion(db), first);
}
