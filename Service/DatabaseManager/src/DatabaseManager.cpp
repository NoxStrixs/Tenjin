#include <DatabaseManager/DatabaseManager.h>

#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QUuid>
#include <QVariant>

#include <cmath>

namespace Service {

DatabaseManager::DatabaseManager(const std::string& filepath)
{
    constexpr std::string_view fileExt = ".db";

    if (filepath.length() <= fileExt.length() ||
        filepath.substr(filepath.length() - fileExt.length()) != fileExt) {
        throw std::runtime_error("Invalid database filepath: " + filepath);
    }

    // Unique connection name prevents "duplicate connection" warnings when
    // multiple DatabaseManager instances exist (e.g. tests, iOS app lifecycle).
    const QString connName = QUuid::createUuid().toString();
    QSqlDatabase  db       = QSqlDatabase::addDatabase("QSQLITE", connName);
    db.setDatabaseName(QString::fromStdString(filepath));

    if (!db.open()) {
        throw std::runtime_error("Failed to open DB: " + db.lastError().text().toStdString());
    }

    m_db = db;

    std::array<const char*, 15> sql_cmds = {
        "PRAGMA foreign_keys = ON;",

        "CREATE TABLE IF NOT EXISTS word ("
        "id INTEGER PRIMARY KEY,"
        "word TEXT NOT NULL UNIQUE,"
        "created_at TEXT DEFAULT (datetime('now')));",

        "CREATE TABLE IF NOT EXISTS tag ("
        "id INTEGER PRIMARY KEY,"
        "name TEXT NOT NULL UNIQUE);",

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
        "pos      TEXT DEFAULT '');",

        "CREATE VIRTUAL TABLE IF NOT EXISTS word_content_fts USING fts5("
        "word_name,"
        "content,"
        "content=word_content,"
        "content_rowid=id);",

        // FTS5 external content triggers — keep FTS index in sync with word_content
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
        "created_at  TEXT DEFAULT (datetime('now')));",

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

        // History of every individual review event, for analytics (accuracy
        // over time, review-count charts, streaks). Append-only.
        "CREATE TABLE IF NOT EXISTS review_log ("
        "id            INTEGER PRIMARY KEY,"
        "deck_id       INTEGER,"
        "word_id       INTEGER,"
        "quality       INTEGER NOT NULL,"
        "ease_factor   REAL,"
        "interval_days INTEGER,"
        "reviewed_at   INTEGER NOT NULL);"};

    for (const auto& sql : sql_cmds) {
        QSqlQuery q(m_db);
        if (!q.exec(sql)) {
            throw std::runtime_error("Failed to execute SQL: " +
                                     q.lastError().text().toStdString());
        }
    }

    // ── Column migrations ──────────────────────────────────────────────
    // Adds a column to an existing table if absent. SQLite errors on a
    // duplicate ADD COLUMN, so we check table_info first.
    auto ensureColumn = [&](const QString& table, const QString& column, const QString& decl) {
        QSqlQuery check(m_db);
        bool      has = false;
        if (check.exec(QStringLiteral("PRAGMA table_info(%1);").arg(table))) {
            while (check.next()) {
                if (check.value(1).toString() == column) {
                    has = true;
                    break;
                }
            }
        }
        if (!has) {
            QSqlQuery alter(m_db);
            if (!alter.exec(
                    QStringLiteral("ALTER TABLE %1 ADD COLUMN %2 %3;").arg(table, column, decl))) {
                throw std::runtime_error("Migration failed adding " + column.toStdString() +
                                         " to " + table.toStdString() + ": " +
                                         alter.lastError().text().toStdString());
            }
        }
    };

    ensureColumn("word_content", "pos", "TEXT DEFAULT ''");

    // guid (stable cross-device identifier) and updated_at (epoch ms) on every
    // top-level entity, to support JSON export and timestamp-based merge import.
    for (const QString& t : {QStringLiteral("word"),
                             QStringLiteral("tag"),
                             QStringLiteral("deck"),
                             QStringLiteral("word_content")}) {
        ensureColumn(t, "guid", "TEXT DEFAULT ''");
        ensureColumn(t, "updated_at", "INTEGER DEFAULT 0");
    }

    // Backfill guids for any pre-existing rows that lack one.
    backfillGuids();
}

DatabaseManager::~DatabaseManager()
{
    const QString connName = m_db.connectionName();
    m_db.close();
    m_db = QSqlDatabase(); // release handle before removeDatabase
    QSqlDatabase::removeDatabase(connName);
}

Result_t<Word_t> DatabaseManager::AddWord(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO word (word) VALUES (:word);");
    q.bindValue(":word", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Word_t{.id = q.lastInsertId().toLongLong(), .word = word, .createdAt = {}};
}

Result_t<Word_t> DatabaseManager::GetWord(const std::string& word)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, word, created_at FROM word WHERE word = :word;");
    q.bindValue(":word", QString::fromStdString(word));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Word not found: " + std::string(word));

    return Word_t{.id        = q.value(0).toLongLong(),
                  .word      = q.value(1).toString().toStdString(),
                  .createdAt = q.value(2).toString().toStdString()};
}

Result_t<std::vector<Word_t>> DatabaseManager::GetAllWords()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, word, created_at FROM word ORDER BY word ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

Result_t<bool> DatabaseManager::DeleteWord(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM word WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word found with id: " + std::to_string(id));

    return true;
}

Result_t<Tag_t> DatabaseManager::AddTag(const std::string& name)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO tag (name) VALUES (:name);");
    q.bindValue(":name", QString::fromStdString(name));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Tag_t{.id = q.lastInsertId().toLongLong(), .name = name};
}

Result_t<Tag_t> DatabaseManager::GetTag(std::string_view name)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name FROM tag WHERE name = :name;");
    q.bindValue(":name", QString::fromStdString(std::string(name)));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("Tag not found: " + std::string(name));

    return Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()};
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetAllTags()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name FROM tag ORDER BY name ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<bool> DatabaseManager::DeleteTag(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM tag WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No tag found with id: " + std::to_string(id));

    return true;
}

Result_t<bool> DatabaseManager::AddTagToWord(ID_t wordId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO word_tag (word_id, tag_id) VALUES (:wordId, :tagId);");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveTagFromWord(ID_t wordId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM word_tag WHERE word_id = :wordId AND tag_id = :tagId;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word-tag association found.");

    return true;
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetTagsForWord(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT t.id, t.name FROM tag t "
              "JOIN word_tag wt ON wt.tag_id = t.id "
              "WHERE wt.word_id = :wordId "
              "ORDER BY t.name ASC;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<std::vector<Word_t>> DatabaseManager::GetWordsForTag(ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT w.id, w.word, w.created_at FROM word w "
              "JOIN word_tag wt ON wt.word_id = w.id "
              "WHERE wt.tag_id = :tagId "
              "ORDER BY w.word ASC;");
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

Result_t<ContentBlock_t> DatabaseManager::AddContentBlock(const ContentBlock_t& block)
{
    QSqlQuery q(m_db);
    q.prepare(
        "INSERT INTO word_content (word_id, type, content, row, col, row_span, col_span, pos) "
        "VALUES (:wordId, :type, :content, :row, :col, :rowSpan, :colSpan, :pos);");
    q.bindValue(":wordId", QVariant::fromValue(block.wordId));
    q.bindValue(":type", static_cast<int>(block.type));
    q.bindValue(":content", QString::fromStdString(block.content));
    q.bindValue(":row", block.row);
    q.bindValue(":col", block.col);
    q.bindValue(":rowSpan", block.rowSpan);
    q.bindValue(":colSpan", block.colSpan);
    q.bindValue(":pos", QString::fromStdString(block.pos));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return ContentBlock_t{.id      = q.lastInsertId().toLongLong(),
                          .wordId  = block.wordId,
                          .type    = block.type,
                          .content = block.content,
                          .row     = block.row,
                          .col     = block.col,
                          .rowSpan = block.rowSpan,
                          .colSpan = block.colSpan,
                          .pos     = block.pos};
}

Result_t<ContentBlock_t> DatabaseManager::UpdateContentBlock(const ContentBlock_t& block)
{
    QSqlQuery q(m_db);
    q.prepare("UPDATE word_content SET type = :type, content = :content, row = :row, col = :col, "
              "row_span = :rowSpan, col_span = :colSpan, pos = :pos WHERE id = :id;");
    q.bindValue(":type", static_cast<int>(block.type));
    q.bindValue(":content", QString::fromStdString(block.content));
    q.bindValue(":row", block.row);
    q.bindValue(":col", block.col);
    q.bindValue(":rowSpan", block.rowSpan);
    q.bindValue(":colSpan", block.colSpan);
    q.bindValue(":pos", QString::fromStdString(block.pos));
    q.bindValue(":id", QVariant::fromValue(block.id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No content block found with id: " + std::to_string(block.id));

    return block;
}

Result_t<bool> DatabaseManager::DeleteContentBlock(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM word_content WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No content block found with id: " + std::to_string(id));

    return true;
}

Result_t<std::vector<ContentBlock_t>> DatabaseManager::GetContentForWord(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, word_id, type, content, row, col, row_span, col_span, pos "
              "FROM word_content WHERE word_id = :wordId "
              "ORDER BY row ASC, col ASC;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<ContentBlock_t> blocks;
    while (q.next()) {
        blocks.push_back(ContentBlock_t{.id      = q.value(0).toLongLong(),
                                        .wordId  = q.value(1).toLongLong(),
                                        .type    = static_cast<ContentType_t>(q.value(2).toInt()),
                                        .content = q.value(3).toString().toStdString(),
                                        .row     = q.value(4).toInt(),
                                        .col     = q.value(5).toInt(),
                                        .rowSpan = q.value(6).toInt(),
                                        .colSpan = q.value(7).toInt(),
                                        .pos     = q.value(8).toString().toStdString()});
    }
    return blocks;
}

Result_t<bool> DatabaseManager::SaveContentLayout(const std::vector<ContentBlock_t>& blocks)
{
    // Transaction — all blocks update atomically or none do
    if (!m_db.transaction())
        return std::unexpected("Failed to begin transaction.");

    QSqlQuery q(m_db);
    // Persist type and content as well as layout. Previously only the
    // row/col/span columns were written, so staged text edits made in edit
    // mode were never saved — blocks survived but their content did not.
    q.prepare("UPDATE word_content SET type = :type, content = :content, pos = :pos, "
              "row = :row, col = :col, row_span = :rowSpan, col_span = :colSpan "
              "WHERE id = :id;");

    for (const auto& block : blocks) {
        q.bindValue(":type", static_cast<int>(block.type));
        q.bindValue(":content", QString::fromStdString(block.content));
        q.bindValue(":pos", QString::fromStdString(block.pos));
        q.bindValue(":row", block.row);
        q.bindValue(":col", block.col);
        q.bindValue(":rowSpan", block.rowSpan);
        q.bindValue(":colSpan", block.colSpan);
        q.bindValue(":id", QVariant::fromValue(block.id));

        if (!q.exec()) {
            m_db.rollback();
            return std::unexpected(q.lastError().text().toStdString());
        }
    }

    if (!m_db.commit()) {
        m_db.rollback();
        return std::unexpected("Failed to commit layout transaction.");
    }

    return true;
}

Result_t<std::vector<Word_t>> DatabaseManager::SearchWords(const std::string& query)
{
    // Append * for prefix matching so partial input works (e.g. "ephe" matches "ephemeral")
    const QString ftsQuery = QString::fromStdString(query) + "*";

    QSqlQuery q(m_db);
    q.prepare("SELECT DISTINCT w.id, w.word, w.created_at FROM word w "
              "JOIN word_content_fts fts ON fts.rowid = (SELECT id FROM word_content WHERE word_id "
              "= w.id LIMIT 1) "
              "WHERE word_content_fts MATCH :query "
              "ORDER BY w.word ASC;");
    q.bindValue(":query", ftsQuery);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

Result_t<std::vector<ContentBlock_t>> DatabaseManager::SearchContent(const std::string& query)
{
    const QString ftsQuery = QString::fromStdString(query) + "*";

    QSqlQuery q(m_db);
    q.prepare(
        "SELECT wc.id, wc.word_id, wc.type, wc.content, wc.row, wc.col, wc.row_span, wc.col_span "
        "FROM word_content wc "
        "JOIN word_content_fts fts ON fts.rowid = wc.id "
        "WHERE word_content_fts MATCH :query;");
    q.bindValue(":query", ftsQuery);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<ContentBlock_t> blocks;
    while (q.next()) {
        blocks.push_back(ContentBlock_t{.id      = q.value(0).toLongLong(),
                                        .wordId  = q.value(1).toLongLong(),
                                        .type    = static_cast<ContentType_t>(q.value(2).toInt()),
                                        .content = q.value(3).toString().toStdString(),
                                        .row     = q.value(4).toInt(),
                                        .col     = q.value(5).toInt(),
                                        .rowSpan = q.value(6).toInt(),
                                        .colSpan = q.value(7).toInt()});
    }
    return blocks;
}

// ── Substring search (LIKE) ───────────────────────────────────────────────────

Result_t<std::vector<Word_t>> DatabaseManager::SearchWordsByName(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, word, created_at FROM word "
              "WHERE word LIKE :pat ESCAPE '\\' "
              "ORDER BY word ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

Result_t<std::vector<Tag_t>> DatabaseManager::SearchTagsByName(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name FROM tag "
              "WHERE name LIKE :pat ESCAPE '\\' "
              "ORDER BY name ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<std::vector<Word_t>> DatabaseManager::SearchWordsByContent(const std::string& substring)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT DISTINCT w.id, w.word, w.created_at FROM word w "
              "JOIN word_content wc ON wc.word_id = w.id "
              "WHERE wc.content LIKE :pat ESCAPE '\\' "
              "ORDER BY w.word ASC;");
    QString pat = QString::fromStdString(substring);
    pat.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    q.bindValue(":pat", "%" + pat + "%");

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                               .word      = q.value(1).toString().toStdString(),
                               .createdAt = q.value(2).toString().toStdString()});
    }
    return words;
}

Result_t<WordRelation_t>
DatabaseManager::AddWordRelation(ID_t wordId, ID_t relatedId, const std::string& type)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO word_relation (word_id, related_word_id, relation_type) "
              "VALUES (:wordId, :relatedId, :type);");
    q.bindValue(":wordId", QVariant::fromValue(wordId));
    q.bindValue(":relatedId", QVariant::fromValue(relatedId));
    q.bindValue(":type", QString::fromStdString(type));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return WordRelation_t{.id             = q.lastInsertId().toLongLong(),
                          .wordId         = wordId,
                          .wordRelationId = relatedId,
                          .relationType   = type};
}

Result_t<bool> DatabaseManager::RemoveWordRelation(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM word_relation WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No word relation found with id: " + std::to_string(id));

    return true;
}

Result_t<std::vector<WordRelation_t>> DatabaseManager::GetRelationsForWord(ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, word_id, related_word_id, relation_type "
              "FROM word_relation WHERE word_id = :wordId;");
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<WordRelation_t> relations;
    while (q.next()) {
        relations.push_back(WordRelation_t{.id             = q.value(0).toLongLong(),
                                           .wordId         = q.value(1).toLongLong(),
                                           .wordRelationId = q.value(2).toLongLong(),
                                           .relationType   = q.value(3).toString().toStdString()});
    }
    return relations;
}

Result_t<Deck_t> DatabaseManager::AddDeck(const std::string& name, bool isSmart, FilterMode_t mode)
{
    const QString filterMode = (mode == FilterMode_t::And) ? "AND" : "OR";

    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck (name, is_smart, filter_mode) "
              "VALUES (:name, :isSmart, :filterMode);");
    q.bindValue(":name", QString::fromStdString(name));
    q.bindValue(":isSmart", isSmart ? 1 : 0);
    q.bindValue(":filterMode", filterMode);

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return Deck_t{.id         = q.lastInsertId().toLongLong(),
                  .name       = name,
                  .bIsSmart   = isSmart,
                  .filterMode = mode,
                  .createdAt  = {}};
}

Result_t<Deck_t> DatabaseManager::GetDeck(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, name, is_smart, filter_mode, created_at FROM deck WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (!q.next())
        return std::unexpected("No deck found with id: " + std::to_string(id));

    const bool         isSmart = q.value(2).toInt() != 0;
    const std::string  fmStr   = q.value(3).toString().toStdString();
    const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

    return Deck_t{.id         = q.value(0).toLongLong(),
                  .name       = q.value(1).toString().toStdString(),
                  .bIsSmart   = isSmart,
                  .filterMode = mode,
                  .createdAt  = q.value(4).toString().toStdString()};
}

Result_t<std::vector<Deck_t>> DatabaseManager::GetAllDecks()
{
    QSqlQuery q(m_db);
    if (!q.exec("SELECT id, name, is_smart, filter_mode, created_at FROM deck ORDER BY name ASC;"))
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Deck_t> decks;
    while (q.next()) {
        const bool         isSmart = q.value(2).toInt() != 0;
        const std::string  fmStr   = q.value(3).toString().toStdString();
        const FilterMode_t mode    = (fmStr == "OR") ? FilterMode_t::Or : FilterMode_t::And;

        decks.push_back(Deck_t{.id         = q.value(0).toLongLong(),
                               .name       = q.value(1).toString().toStdString(),
                               .bIsSmart   = isSmart,
                               .filterMode = mode,
                               .createdAt  = q.value(4).toString().toStdString()});
    }
    return decks;
}

Result_t<bool> DatabaseManager::DeleteDeck(ID_t id)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck WHERE id = :id;");
    q.bindValue(":id", QVariant::fromValue(id));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck found with id: " + std::to_string(id));

    return true;
}

Result_t<bool> DatabaseManager::AddWordToDeck(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck_word (deck_id, word_id) VALUES (:deckId, :wordId);");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveWordFromDeck(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck_word WHERE deck_id = :deckId AND word_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck-word association found.");

    return true;
}

Result_t<bool> DatabaseManager::AddTagFilterToDeck(ID_t deckId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("INSERT INTO deck_tag_filter (deck_id, tag_id) VALUES (:deckId, :tagId);");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    return true;
}

Result_t<bool> DatabaseManager::RemoveTagFilterFromDeck(ID_t deckId, ID_t tagId)
{
    QSqlQuery q(m_db);
    q.prepare("DELETE FROM deck_tag_filter WHERE deck_id = :deckId AND tag_id = :tagId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":tagId", QVariant::fromValue(tagId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    if (q.numRowsAffected() == 0)
        return std::unexpected("No deck-tag filter found.");

    return true;
}

Result_t<std::vector<Tag_t>> DatabaseManager::GetTagFiltersForDeck(ID_t deckId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT t.id, t.name FROM tag t "
              "JOIN deck_tag_filter dtf ON dtf.tag_id = t.id "
              "WHERE dtf.deck_id = :deckId "
              "ORDER BY t.name ASC;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Tag_t> tags;
    while (q.next()) {
        tags.push_back(
            Tag_t{.id = q.value(0).toLongLong(), .name = q.value(1).toString().toStdString()});
    }
    return tags;
}

Result_t<Review_t> DatabaseManager::InitReview(ID_t deckId, ID_t wordId)
{
    // INSERT OR IGNORE — safe to call multiple times, won't overwrite existing progress
    QSqlQuery q(m_db);
    q.prepare("INSERT OR IGNORE INTO review (deck_id, word_id, next_review_date) "
              "VALUES (:deckId, :wordId, date('now'));");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    // Fetch the row whether it was just inserted or already existed
    q.prepare("SELECT id, deck_id, word_id, ease_factor, interval_days, repetitions, "
              "next_review_date, last_review_date "
              "FROM review WHERE deck_id = :deckId AND word_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec() || !q.next())
        return std::unexpected(q.lastError().text().toStdString());

    return Review_t{.id             = q.value(0).toLongLong(),
                    .deckId         = q.value(1).toLongLong(),
                    .wordId         = q.value(2).toLongLong(),
                    .easeFactor     = q.value(3).toFloat(),
                    .intervalDays   = static_cast<uint16_t>(q.value(4).toInt()),
                    .repetitions    = static_cast<uint16_t>(q.value(5).toInt()),
                    .nextReviewDate = q.value(6).toString().toStdString(),
                    .lastReviewDate = q.value(7).toString().toStdString()};
}

Result_t<Review_t> DatabaseManager::SubmitReview(ID_t deckId, ID_t wordId, int quality)
{
    // Fetch current state
    QSqlQuery q(m_db);
    q.prepare("SELECT id, ease_factor, interval_days, repetitions "
              "FROM review WHERE deck_id = :deckId AND word_id = :wordId;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec() || !q.next())
        return std::unexpected("Review not found. Call initReview first.");

    const ID_t reviewId     = q.value(0).toLongLong();
    float      easeFactor   = q.value(1).toFloat();
    int        intervalDays = q.value(2).toInt();
    int        repetitions  = q.value(3).toInt();

    // SM-2 algorithm
    if (quality >= 3) {
        if (repetitions == 0)
            intervalDays = 1;
        else if (repetitions == 1)
            intervalDays = 6;
        else
            intervalDays = static_cast<int>(std::round(intervalDays * easeFactor));

        easeFactor += 0.1f - (5 - quality) * (0.08f + (5 - quality) * 0.02f);
        easeFactor = std::max(1.3f, easeFactor);
        repetitions++;
    } else {
        // Failed — reset streak, keep ease factor
        repetitions  = 0;
        intervalDays = 1;
    }

    const QString today    = QDate::currentDate().toString("yyyy-MM-dd");
    const QString nextDate = QDate::currentDate().addDays(intervalDays).toString("yyyy-MM-dd");

    q.prepare(
        "UPDATE review SET ease_factor = :ef, interval_days = :interval, repetitions = :reps, "
        "next_review_date = :nextDate, last_review_date = :lastDate "
        "WHERE deck_id = :deckId AND word_id = :wordId;");
    q.bindValue(":ef", easeFactor);
    q.bindValue(":interval", intervalDays);
    q.bindValue(":reps", repetitions);
    q.bindValue(":nextDate", nextDate);
    q.bindValue(":lastDate", today);
    q.bindValue(":deckId", QVariant::fromValue(deckId));
    q.bindValue(":wordId", QVariant::fromValue(wordId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    // Append to the review history log (analytics). Non-fatal if it fails.
    {
        QSqlQuery log(m_db);
        log.prepare("INSERT INTO review_log "
                    "(deck_id, word_id, quality, ease_factor, interval_days, reviewed_at) "
                    "VALUES (:d, :w, :q, :ef, :iv, :ts);");
        log.bindValue(":d", QVariant::fromValue(deckId));
        log.bindValue(":w", QVariant::fromValue(wordId));
        log.bindValue(":q", quality);
        log.bindValue(":ef", easeFactor);
        log.bindValue(":iv", intervalDays);
        log.bindValue(":ts", QDateTime::currentMSecsSinceEpoch());
        log.exec();
    }

    return Review_t{.id             = reviewId,
                    .deckId         = deckId,
                    .wordId         = wordId,
                    .easeFactor     = easeFactor,
                    .intervalDays   = static_cast<uint16_t>(intervalDays),
                    .repetitions    = static_cast<uint16_t>(repetitions),
                    .nextReviewDate = nextDate.toStdString(),
                    .lastReviewDate = today.toStdString()};
}

Result_t<std::vector<Review_t>> DatabaseManager::GetDueReviews(ID_t deckId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT id, deck_id, word_id, ease_factor, interval_days, repetitions, "
              "next_review_date, last_review_date "
              "FROM review WHERE deck_id = :deckId AND next_review_date <= date('now') "
              "ORDER BY next_review_date ASC;");
    q.bindValue(":deckId", QVariant::fromValue(deckId));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Review_t> reviews;
    while (q.next()) {
        reviews.push_back(Review_t{.id             = q.value(0).toLongLong(),
                                   .deckId         = q.value(1).toLongLong(),
                                   .wordId         = q.value(2).toLongLong(),
                                   .easeFactor     = q.value(3).toFloat(),
                                   .intervalDays   = static_cast<uint16_t>(q.value(4).toInt()),
                                   .repetitions    = static_cast<uint16_t>(q.value(5).toInt()),
                                   .nextReviewDate = q.value(6).toString().toStdString(),
                                   .lastReviewDate = q.value(7).toString().toStdString()});
    }
    return reviews;
}

Result_t<DeckStats_t> DatabaseManager::GetDeckStats(ID_t deckId)
{
    DeckStats_t stats;

    auto words = GetWordsForDeck(deckId);
    if (!words)
        return std::unexpected(words.error());
    stats.total = static_cast<int>(words->size());
    if (stats.total == 0)
        return stats;

    QSqlQuery q(m_db);
    q.prepare("SELECT word_id, next_review_date FROM review WHERE deck_id = :d;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    QHash<qint64, QString> nextByWord;
    while (q.next())
        nextByWord.insert(q.value(0).toLongLong(), q.value(1).toString());

    const QString today = QDate::currentDate().toString("yyyy-MM-dd");
    QString       earliestUpcoming;

    for (const auto& w : *words) {
        const auto it = nextByWord.find(static_cast<qint64>(w.id));
        if (it == nextByWord.end()) {
            ++stats.due; // never reviewed → new card, due
            continue;
        }
        const QString next = it.value();
        if (next.isEmpty() || next <= today) {
            ++stats.due;
        } else if (earliestUpcoming.isEmpty() || next < earliestUpcoming) {
            earliestUpcoming = next;
        }
    }
    stats.nextDue = earliestUpcoming.toStdString();
    return stats;
}

Result_t<DeckAnalytics_t> DatabaseManager::GetDeckAnalytics(ID_t deckId)
{
    DeckAnalytics_t a;

    // Daily aggregates: count + average grade per day, chronological.
    // reviewed_at is epoch ms; convert to a local date string in SQL via SQLite's
    // datetime on (ms/1000) seconds.
    QSqlQuery q(m_db);
    q.prepare("SELECT date(reviewed_at/1000, 'unixepoch', 'localtime') AS d, "
              "COUNT(*) AS c, AVG(quality) AS aq "
              "FROM review_log WHERE deck_id = :d "
              "GROUP BY d ORDER BY d ASC;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());
    while (q.next()) {
        a.daily.push_back(DailyStat_t{
            q.value(0).toString().toStdString(), q.value(1).toInt(), q.value(2).toDouble()});
        a.totalReviews += q.value(1).toInt();
    }

    // Retention: fraction of all grades that were "remembered" (quality >= 2).
    QSqlQuery rq(m_db);
    rq.prepare("SELECT "
               "SUM(CASE WHEN quality >= 2 THEN 1 ELSE 0 END) AS good, COUNT(*) AS total "
               "FROM review_log WHERE deck_id = :d;");
    rq.bindValue(":d", QVariant::fromValue(deckId));
    if (rq.exec() && rq.next()) {
        const int total = rq.value(1).toInt();
        a.retention     = (total > 0) ? rq.value(0).toDouble() / total : 0.0;
    }
    return a;
}

Result_t<std::vector<WordReviewEvent_t>> DatabaseManager::GetWordHistory(ID_t deckId, ID_t wordId)
{
    QSqlQuery q(m_db);
    q.prepare("SELECT reviewed_at, quality, ease_factor, interval_days "
              "FROM review_log WHERE deck_id = :d AND word_id = :w "
              "ORDER BY reviewed_at ASC;");
    q.bindValue(":d", QVariant::fromValue(deckId));
    q.bindValue(":w", QVariant::fromValue(wordId));
    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<WordReviewEvent_t> events;
    while (q.next()) {
        events.push_back(WordReviewEvent_t{q.value(0).toLongLong(),
                                           q.value(1).toInt(),
                                           q.value(2).toDouble(),
                                           q.value(3).toInt()});
    }
    return events;
}

Result_t<std::vector<Word_t>> DatabaseManager::GetWordsForDeck(ID_t deckId)
{
    auto deck = GetDeck(deckId);
    if (!deck)
        return std::unexpected(deck.error());

    if (!deck->bIsSmart) {
        // Manual deck — read directly from deck_word junction
        QSqlQuery q(m_db);
        q.prepare("SELECT w.id, w.word, w.created_at FROM word w "
                  "JOIN deck_word dw ON dw.word_id = w.id "
                  "WHERE dw.deck_id = :deckId "
                  "ORDER BY w.word ASC;");
        q.bindValue(":deckId", QVariant::fromValue(deckId));

        if (!q.exec())
            return std::unexpected(q.lastError().text().toStdString());

        std::vector<Word_t> words;
        while (q.next()) {
            words.push_back(Word_t{.id        = q.value(0).toLongLong(),
                                   .word      = q.value(1).toString().toStdString(),
                                   .createdAt = q.value(2).toString().toStdString()});
        }
        return words;
    }

    // Smart deck — collect tag filters then delegate to getWordsByTags
    auto tags = GetTagFiltersForDeck(deckId);
    if (!tags)
        return std::unexpected(tags.error());

    std::vector<ID_t> tagIds;
    tagIds.reserve(tags->size());
    for (const auto& tag : *tags)
        tagIds.push_back(tag.id);

    return GetWordsByTags(tagIds, deck->filterMode);
}

Result_t<std::vector<Word_t>> DatabaseManager::GetWordsByTags(const std::vector<ID_t>& tagIds,
                                                              FilterMode_t             mode)
{
    if (tagIds.empty())
        return std::vector<Word_t>{};

    // Build the IN clause placeholder list: (:t0, :t1, :t2 ...)
    QStringList placeholders;
    for (size_t i = 0; i < tagIds.size(); ++i)
        placeholders << QString(":t%1").arg(i);

    QString sql;
    if (mode == FilterMode_t::And) {
        // Relational division — word must have ALL specified tags
        sql = QString("SELECT w.id, w.word, w.created_at FROM word w "
                      "JOIN word_tag wt ON wt.word_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "GROUP BY w.id "
                      "HAVING COUNT(DISTINCT wt.tag_id) = %2 "
                      "ORDER BY w.word ASC;")
                  .arg(placeholders.join(", "))
                  .arg(tagIds.size());
    } else {
        // OR — word must have at least one of the specified tags
        sql = QString("SELECT DISTINCT w.id, w.word, w.created_at FROM word w "
                      "JOIN word_tag wt ON wt.word_id = w.id "
                      "WHERE wt.tag_id IN (%1) "
                      "ORDER BY w.word ASC;")
                  .arg(placeholders.join(", "));
    }

    QSqlQuery q(m_db);
    q.prepare(sql);
    for (size_t i = 0; i < tagIds.size(); ++i)
        q.bindValue(QString(":t%1").arg(i), QVariant::fromValue(tagIds[i]));

    if (!q.exec())
        return std::unexpected(q.lastError().text().toStdString());

    std::vector<Word_t> words;
    while (q.next()) {
        words.emplace_back(q.value(0).toLongLong(),
                           q.value(1).toString().toStdString(),
                           q.value(2).toString().toStdString());
    }
    return words;
}

// ── Import / Export ─────────────────────────────────────────────────────────

void DatabaseManager::backfillGuids()
{
    const char* tables[] = {"word", "tag", "deck", "word_content"};
    for (const char* t : tables) {
        QSqlQuery sel(m_db);
        sel.exec(QStringLiteral("SELECT id FROM %1 WHERE guid IS NULL OR guid = '';").arg(t));
        std::vector<qint64> ids;
        while (sel.next())
            ids.push_back(sel.value(0).toLongLong());
        for (qint64 id : ids) {
            QSqlQuery upd(m_db);
            upd.prepare(
                QStringLiteral("UPDATE %1 SET guid = :g, updated_at = :u WHERE id = :id;").arg(t));
            upd.bindValue(":g", QUuid::createUuid().toString(QUuid::WithoutBraces));
            upd.bindValue(":u", QDateTime::currentMSecsSinceEpoch());
            upd.bindValue(":id", id);
            upd.exec();
        }
    }
}

Result_t<bool> DatabaseManager::ExportToJson(const QString& path)
{
    // Ensure every row has a guid (rows created since startup may not).
    backfillGuids();

    QJsonObject root;
    root["format"]     = "tenjin-export";
    root["version"]    = 1;
    root["exportedAt"] = QDateTime::currentMSecsSinceEpoch();

    // Words (with their content blocks and tag guids embedded).
    QJsonArray wordsArr;
    {
        QSqlQuery wq(m_db);
        if (!wq.exec("SELECT id, guid, word, created_at, updated_at FROM word;"))
            return std::unexpected(wq.lastError().text().toStdString());
        while (wq.next()) {
            const qint64 wid = wq.value(0).toLongLong();
            QJsonObject  w;
            w["guid"]      = wq.value(1).toString();
            w["word"]      = wq.value(2).toString();
            w["createdAt"] = wq.value(3).toString();
            w["updatedAt"] = wq.value(4).toLongLong();

            // Content blocks.
            QJsonArray blocks;
            QSqlQuery  cq(m_db);
            cq.prepare("SELECT guid, type, content, row, col, row_span, col_span, pos, updated_at "
                       "FROM word_content WHERE word_id = :wid;");
            cq.bindValue(":wid", wid);
            cq.exec();
            while (cq.next()) {
                QJsonObject b;
                b["guid"]      = cq.value(0).toString();
                b["type"]      = cq.value(1).toInt();
                b["content"]   = cq.value(2).toString();
                b["row"]       = cq.value(3).toInt();
                b["col"]       = cq.value(4).toInt();
                b["rowSpan"]   = cq.value(5).toInt();
                b["colSpan"]   = cq.value(6).toInt();
                b["pos"]       = cq.value(7).toString();
                b["updatedAt"] = cq.value(8).toLongLong();
                blocks.append(b);
            }
            w["blocks"] = blocks;

            // Tag guids attached to this word.
            QJsonArray tagGuids;
            QSqlQuery  tq(m_db);
            tq.prepare("SELECT t.guid FROM tag t JOIN word_tag wt ON wt.tag_id = t.id "
                       "WHERE wt.word_id = :wid;");
            tq.bindValue(":wid", wid);
            tq.exec();
            while (tq.next())
                tagGuids.append(tq.value(0).toString());
            w["tags"] = tagGuids;

            wordsArr.append(w);
        }
    }
    root["words"] = wordsArr;

    // Tags.
    QJsonArray tagsArr;
    {
        QSqlQuery q(m_db);
        q.exec("SELECT guid, name, updated_at FROM tag;");
        while (q.next()) {
            QJsonObject t;
            t["guid"]      = q.value(0).toString();
            t["name"]      = q.value(1).toString();
            t["updatedAt"] = q.value(2).toLongLong();
            tagsArr.append(t);
        }
    }
    root["tags"] = tagsArr;

    // Decks (with member-word guids and tag-filter guids).
    QJsonArray decksArr;
    {
        QSqlQuery dq(m_db);
        dq.exec("SELECT id, guid, name, is_smart, filter_mode, updated_at FROM deck;");
        while (dq.next()) {
            const qint64 did = dq.value(0).toLongLong();
            QJsonObject  d;
            d["guid"]       = dq.value(1).toString();
            d["name"]       = dq.value(2).toString();
            d["isSmart"]    = dq.value(3).toInt() != 0;
            d["filterMode"] = dq.value(4).toString();
            d["updatedAt"]  = dq.value(5).toLongLong();

            QJsonArray memberWords;
            QSqlQuery  mq(m_db);
            mq.prepare("SELECT w.guid FROM word w JOIN deck_word dw ON dw.word_id = w.id "
                       "WHERE dw.deck_id = :did;");
            mq.bindValue(":did", did);
            mq.exec();
            while (mq.next())
                memberWords.append(mq.value(0).toString());
            d["words"] = memberWords;

            QJsonArray filterTags;
            QSqlQuery  fq(m_db);
            fq.prepare("SELECT t.guid FROM tag t JOIN deck_tag_filter dtf ON dtf.tag_id = t.id "
                       "WHERE dtf.deck_id = :did;");
            fq.bindValue(":did", did);
            fq.exec();
            while (fq.next())
                filterTags.append(fq.value(0).toString());
            d["tagFilters"] = filterTags;

            decksArr.append(d);
        }
    }
    root["decks"] = decksArr;

    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return std::unexpected("Cannot open file for writing: " + path.toStdString());
    f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    f.close();
    return true;
}

Result_t<bool> DatabaseManager::ImportFromJson(const QString& path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return std::unexpected("Cannot open file for reading: " + path.toStdString());
    const QByteArray bytes = f.readAll();
    f.close();

    QJsonParseError     perr;
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return std::unexpected("Invalid JSON: " + perr.errorString().toStdString());
    const QJsonObject root = doc.object();
    if (root.value("format").toString() != "tenjin-export")
        return std::unexpected("Not a Tenjin export file.");

    if (!m_db.transaction())
        return std::unexpected("Failed to begin import transaction.");

    auto fail = [&](const QString& msg) -> Result_t<bool> {
        m_db.rollback();
        return std::unexpected(msg.toStdString());
    };

    // Helper: look up a row id by guid; returns -1 if absent. Also returns the
    // stored updated_at via out-param.
    auto findByGuid = [&](const QString& table, const QString& guid, qint64& outUpdated) -> qint64 {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("SELECT id, updated_at FROM %1 WHERE guid = :g;").arg(table));
        q.bindValue(":g", guid);
        if (q.exec() && q.next()) {
            outUpdated = q.value(1).toLongLong();
            return q.value(0).toLongLong();
        }
        outUpdated = 0;
        return -1;
    };

    // ── Tags ──
    QHash<QString, qint64> tagIdByGuid;
    for (const QJsonValue& v : root.value("tags").toArray()) {
        const QJsonObject t   = v.toObject();
        const QString     g   = t.value("guid").toString();
        const QString     nm  = t.value("name").toString();
        const qint64      upd = t.value("updatedAt").toVariant().toLongLong();
        if (g.isEmpty())
            continue;
        qint64 existingUpd = 0;
        qint64 id          = findByGuid("tag", g, existingUpd);
        if (id < 0) {
            QSqlQuery ins(m_db);
            ins.prepare("INSERT INTO tag (name, guid, updated_at) VALUES (:n, :g, :u);");
            ins.bindValue(":n", nm);
            ins.bindValue(":g", g);
            ins.bindValue(":u", upd);
            if (!ins.exec())
                return fail("tag insert: " + ins.lastError().text());
            id = ins.lastInsertId().toLongLong();
        } else if (upd > existingUpd) {
            QSqlQuery up(m_db);
            up.prepare("UPDATE tag SET name = :n, updated_at = :u WHERE id = :id;");
            up.bindValue(":n", nm);
            up.bindValue(":u", upd);
            up.bindValue(":id", id);
            up.exec();
        }
        tagIdByGuid.insert(g, id);
    }

    // ── Words + content blocks ──
    QHash<QString, qint64> wordIdByGuid;
    for (const QJsonValue& v : root.value("words").toArray()) {
        const QJsonObject w   = v.toObject();
        const QString     g   = w.value("guid").toString();
        const QString     txt = w.value("word").toString();
        const qint64      upd = w.value("updatedAt").toVariant().toLongLong();
        if (g.isEmpty() || txt.isEmpty())
            continue;

        qint64 existingUpd = 0;
        qint64 wid         = findByGuid("word", g, existingUpd);
        if (wid < 0) {
            QSqlQuery ins(m_db);
            ins.prepare("INSERT INTO word (word, guid, updated_at) VALUES (:w, :g, :u);");
            ins.bindValue(":w", txt);
            ins.bindValue(":g", g);
            ins.bindValue(":u", upd);
            if (!ins.exec()) {
                // A word with the same text but different guid may already exist
                // (UNIQUE on word). Treat that as the same word and adopt it.
                qint64    dummy = 0;
                QSqlQuery byName(m_db);
                byName.prepare("SELECT id FROM word WHERE word = :w;");
                byName.bindValue(":w", txt);
                if (byName.exec() && byName.next()) {
                    wid = byName.value(0).toLongLong();
                } else {
                    return fail("word insert: " + ins.lastError().text());
                }
            } else {
                wid = ins.lastInsertId().toLongLong();
            }
        } else if (upd > existingUpd) {
            QSqlQuery up(m_db);
            up.prepare("UPDATE word SET word = :w, updated_at = :u WHERE id = :id;");
            up.bindValue(":w", txt);
            up.bindValue(":u", upd);
            up.bindValue(":id", wid);
            up.exec();
        }
        wordIdByGuid.insert(g, wid);

        // Content blocks (merge by block guid).
        for (const QJsonValue& bv : w.value("blocks").toArray()) {
            const QJsonObject b   = bv.toObject();
            const QString     bg  = b.value("guid").toString();
            const qint64      bup = b.value("updatedAt").toVariant().toLongLong();
            if (bg.isEmpty())
                continue;
            qint64 bExisting = 0;
            qint64 bid       = findByGuid("word_content", bg, bExisting);
            if (bid < 0) {
                QSqlQuery ins(m_db);
                ins.prepare(
                    "INSERT INTO word_content "
                    "(word_id, type, content, row, col, row_span, col_span, pos, guid, updated_at) "
                    "VALUES (:wid, :ty, :ct, :r, :c, :rs, :cs, :pos, :g, :u);");
                ins.bindValue(":wid", wid);
                ins.bindValue(":ty", b.value("type").toInt());
                ins.bindValue(":ct", b.value("content").toString());
                ins.bindValue(":r", b.value("row").toInt());
                ins.bindValue(":c", b.value("col").toInt());
                ins.bindValue(":rs", b.value("rowSpan").toInt());
                ins.bindValue(":cs", b.value("colSpan").toInt());
                ins.bindValue(":pos", b.value("pos").toString());
                ins.bindValue(":g", bg);
                ins.bindValue(":u", bup);
                if (!ins.exec())
                    return fail("block insert: " + ins.lastError().text());
            } else if (bup > bExisting) {
                QSqlQuery up(m_db);
                up.prepare(
                    "UPDATE word_content SET type = :ty, content = :ct, row = :r, col = :c, "
                    "row_span = :rs, col_span = :cs, pos = :pos, updated_at = :u WHERE id = :id;");
                up.bindValue(":ty", b.value("type").toInt());
                up.bindValue(":ct", b.value("content").toString());
                up.bindValue(":r", b.value("row").toInt());
                up.bindValue(":c", b.value("col").toInt());
                up.bindValue(":rs", b.value("rowSpan").toInt());
                up.bindValue(":cs", b.value("colSpan").toInt());
                up.bindValue(":pos", b.value("pos").toString());
                up.bindValue(":u", bup);
                up.bindValue(":id", bid);
                up.exec();
            }
        }

        // Word↔tag links (additive; never removes existing links).
        for (const QJsonValue& tg : w.value("tags").toArray()) {
            const auto it = tagIdByGuid.find(tg.toString());
            if (it == tagIdByGuid.end())
                continue;
            QSqlQuery link(m_db);
            link.prepare("INSERT OR IGNORE INTO word_tag (word_id, tag_id) VALUES (:w, :t);");
            link.bindValue(":w", wid);
            link.bindValue(":t", it.value());
            link.exec();
        }
    }

    // ── Decks ──
    for (const QJsonValue& v : root.value("decks").toArray()) {
        const QJsonObject d   = v.toObject();
        const QString     g   = d.value("guid").toString();
        const QString     nm  = d.value("name").toString();
        const qint64      upd = d.value("updatedAt").toVariant().toLongLong();
        if (g.isEmpty())
            continue;
        qint64 existingUpd = 0;
        qint64 did         = findByGuid("deck", g, existingUpd);
        if (did < 0) {
            QSqlQuery ins(m_db);
            ins.prepare("INSERT INTO deck (name, is_smart, filter_mode, guid, updated_at) "
                        "VALUES (:n, :s, :m, :g, :u);");
            ins.bindValue(":n", nm);
            ins.bindValue(":s", d.value("isSmart").toBool() ? 1 : 0);
            ins.bindValue(":m", d.value("filterMode").toString());
            ins.bindValue(":g", g);
            ins.bindValue(":u", upd);
            if (!ins.exec())
                return fail("deck insert: " + ins.lastError().text());
            did = ins.lastInsertId().toLongLong();
        } else if (upd > existingUpd) {
            QSqlQuery up(m_db);
            up.prepare(
                "UPDATE deck SET name = :n, is_smart = :s, filter_mode = :m, updated_at = :u "
                "WHERE id = :id;");
            up.bindValue(":n", nm);
            up.bindValue(":s", d.value("isSmart").toBool() ? 1 : 0);
            up.bindValue(":m", d.value("filterMode").toString());
            up.bindValue(":u", upd);
            up.bindValue(":id", did);
            up.exec();
        }

        for (const QJsonValue& wg : d.value("words").toArray()) {
            const auto it = wordIdByGuid.find(wg.toString());
            if (it == wordIdByGuid.end())
                continue;
            QSqlQuery link(m_db);
            link.prepare("INSERT OR IGNORE INTO deck_word (deck_id, word_id) VALUES (:d, :w);");
            link.bindValue(":d", did);
            link.bindValue(":w", it.value());
            link.exec();
        }
        for (const QJsonValue& tg : d.value("tagFilters").toArray()) {
            const auto it = tagIdByGuid.find(tg.toString());
            if (it == tagIdByGuid.end())
                continue;
            QSqlQuery link(m_db);
            link.prepare(
                "INSERT OR IGNORE INTO deck_tag_filter (deck_id, tag_id) VALUES (:d, :t);");
            link.bindValue(":d", did);
            link.bindValue(":t", it.value());
            link.exec();
        }
    }

    if (!m_db.commit())
        return fail("Failed to commit import transaction.");
    return true;
}

} // namespace Service
