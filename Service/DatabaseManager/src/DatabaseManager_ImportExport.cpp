#include <DatabaseManager/DatabaseManager.h>
#include <DatabaseManager/Schema.h>

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
        if (!wq.exec("SELECT id, guid, title, created_at, updated_at FROM entry;"))
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
                       "FROM entry_content WHERE entry_id = :wid;");
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
            tq.prepare("SELECT t.guid FROM tag t JOIN entry_tag wt ON wt.tag_id = t.id "
                       "WHERE wt.entry_id = :wid;");
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
            mq.prepare("SELECT w.guid FROM entry w JOIN deck_entry dw ON dw.entry_id = w.id "
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
        qint64 wid         = findByGuid("entry", g, existingUpd);
        if (wid < 0) {
            QSqlQuery ins(m_db);
            ins.prepare("INSERT INTO entry (title, guid, updated_at) VALUES (:w, :g, :u);");
            ins.bindValue(":w", txt);
            ins.bindValue(":g", g);
            ins.bindValue(":u", upd);
            if (!ins.exec()) {
                // A word with the same text but different guid may already exist
                // (UNIQUE on word). Treat that as the same word and adopt it.
                QSqlQuery byName(m_db);
                byName.prepare("SELECT id FROM entry WHERE title = :w;");
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
            up.prepare("UPDATE entry SET title = :w, updated_at = :u WHERE id = :id;");
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
            qint64 bid       = findByGuid("entry_content", bg, bExisting);
            if (bid < 0) {
                QSqlQuery ins(m_db);
                ins.prepare("INSERT INTO entry_content "
                            "(entry_id, type, kind, content, row, col, row_span, col_span, pos, "
                            "guid, updated_at) "
                            "VALUES (:wid, :ty, :knd, :ct, :r, :c, :rs, :cs, :pos, :g, :u);");
                ins.bindValue(":wid", wid);
                ins.bindValue(":ty", b.value("type").toInt());
                ins.bindValue(":knd",
                              QString::fromStdString(ToKindString(
                                  static_cast<ContentType_t>(b.value("type").toInt()))));
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
                    "UPDATE entry_content SET type = :ty, kind = :knd, content = :ct, row = :r, "
                    "col = :c, "
                    "row_span = :rs, col_span = :cs, pos = :pos, updated_at = :u WHERE id = :id;");
                up.bindValue(":ty", b.value("type").toInt());
                up.bindValue(":knd",
                             QString::fromStdString(ToKindString(
                                 static_cast<ContentType_t>(b.value("type").toInt()))));
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
            link.prepare("INSERT OR IGNORE INTO entry_tag (entry_id, tag_id) VALUES (:w, :t);");
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
            link.prepare("INSERT OR IGNORE INTO deck_entry (deck_id, entry_id) VALUES (:d, :w);");
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
