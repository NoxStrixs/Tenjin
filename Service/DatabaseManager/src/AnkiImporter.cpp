#include <DatabaseManager/AnkiImporter.h>

#include <QDir>
#include <QFile>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUuid>

#include <miniz.h>

namespace Service {

namespace {

// Strip Anki/HTML markup down to readable text while preserving media refs.
QString stripHtml(const QString& in)
{
    QString s = in;
    // Convert <br> and block tags to newlines before stripping.
    s.replace(QRegularExpression("<\\s*br\\s*/?>", QRegularExpression::CaseInsensitiveOption),
              "\n");
    s.replace(QRegularExpression("</\\s*(div|p)\\s*>", QRegularExpression::CaseInsensitiveOption),
              "\n");
    // Remove remaining tags.
    s.remove(QRegularExpression("<[^>]*>"));
    // Decode the handful of entities Anki commonly emits.
    s.replace("&nbsp;", " ");
    s.replace("&amp;", "&");
    s.replace("&lt;", "<");
    s.replace("&gt;", ">");
    s.replace("&quot;", "\"");
    s.replace("&#39;", "'");
    return s.trimmed();
}

// Collect [sound:x] and <img src="y"> references from a raw field.
void collectMediaRefs(const QString& raw, std::vector<QString>& out)
{
    static const QRegularExpression soundRe("\\[sound:([^\\]]+)\\]");
    static const QRegularExpression imgRe("<img[^>]*src=\"([^\"]+)\"",
                                          QRegularExpression::CaseInsensitiveOption);
    for (auto it = soundRe.globalMatch(raw); it.hasNext();)
        out.push_back(it.next().captured(1));
    for (auto it = imgRe.globalMatch(raw); it.hasNext();)
        out.push_back(it.next().captured(1));
}

// Extract a single named entry from the zip into destDir. Returns the written
// path, or empty on failure.
QString extractEntry(mz_zip_archive& zip, const char* name, const QString& destDir)
{
    size_t sz  = 0;
    void*  buf = mz_zip_reader_extract_file_to_heap(&zip, name, &sz, 0);
    if (!buf)
        return {};
    const QString outPath = destDir + "/" + QString::fromUtf8(name);
    QFile         f(outPath);
    bool          ok = false;
    if (f.open(QIODevice::WriteOnly)) {
        ok = (f.write(static_cast<const char*>(buf), static_cast<qint64>(sz)) ==
              static_cast<qint64>(sz));
        f.close();
    }
    mz_free(buf);
    return ok ? outPath : QString();
}

} // namespace

std::expected<AnkiImportResult, std::string> ParseApkg(const QString& apkgPath)
{
    QFile apkg(apkgPath);
    if (!apkg.exists())
        return std::unexpected("File does not exist: " + apkgPath.toStdString());

    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    if (!mz_zip_reader_init_file(&zip, apkgPath.toUtf8().constData(), 0))
        return std::unexpected("Not a valid .apkg (zip) file.");

    // Anki uses collection.anki21 (newer) or collection.anki2 (older).
    QTemporaryDir tmp;
    if (!tmp.isValid()) {
        mz_zip_reader_end(&zip);
        return std::unexpected("Could not create a temporary extraction directory.");
    }

    QString dbPath;
    for (const char* candidate : {"collection.anki21", "collection.anki2"}) {
        if (mz_zip_reader_locate_file(&zip, candidate, nullptr, 0) >= 0) {
            dbPath = extractEntry(zip, candidate, tmp.path());
            if (!dbPath.isEmpty())
                break;
        }
    }
    mz_zip_reader_end(&zip);

    if (dbPath.isEmpty())
        return std::unexpected("No Anki collection database found inside the package.");

    AnkiImportResult result;

    // Open the extracted SQLite DB under a unique connection name so it does
    // not collide with the app's primary connection.
    const QString connName = "anki_import_" + QUuid::createUuid().toString(QUuid::Id128);
    {
        QSqlDatabase adb = QSqlDatabase::addDatabase("QSQLITE", connName);
        adb.setDatabaseName(dbPath);
        if (!adb.open()) {
            QSqlDatabase::removeDatabase(connName);
            return std::unexpected("Could not open the Anki collection database.");
        }

        // Map deck ids → names from the `col` table's `decks` JSON (Anki <= 2.1.45)
        // or the `decks` table (newer schema). We try the table first.
        QHash<qint64, QString> deckNames;
        {
            QSqlQuery dq(adb);
            if (dq.exec("SELECT id, name FROM decks;")) {
                while (dq.next())
                    deckNames.insert(dq.value(0).toLongLong(), dq.value(1).toString());
            } else {
                QSqlQuery cq(adb);
                if (cq.exec("SELECT decks FROM col LIMIT 1;") && cq.next()) {
                    const auto doc = QJsonDocument::fromJson(cq.value(0).toString().toUtf8());
                    const auto obj = doc.object();
                    for (auto it = obj.begin(); it != obj.end(); ++it)
                        deckNames.insert(it.key().toLongLong(),
                                         it.value().toObject().value("name").toString());
                }
            }
        }

        // Pull notes joined to their deck via cards (a note can be in one deck
        // for our purposes; we take the first card's deck).
        QSqlQuery  nq(adb);
        const bool joined =
            nq.exec("SELECT n.flds, n.tags, "
                    "       (SELECT c.did FROM cards c WHERE c.nid = n.id LIMIT 1) AS did "
                    "FROM notes n;");
        if (!joined) {
            // Fall back to notes only if the cards join fails.
            nq.exec("SELECT flds, tags, 0 AS did FROM notes;");
        }

        const QChar kFieldSep(0x1f);
        while (nq.next()) {
            const QString flds = nq.value(0).toString();
            const QString tags = nq.value(1).toString().trimmed();
            const qint64  did  = nq.value(2).toLongLong();

            const QStringList fields = flds.split(kFieldSep);
            if (fields.isEmpty()) {
                ++result.skipped;
                continue;
            }

            AnkiNote note;
            // Collect media from all raw fields before stripping.
            for (const QString& f : fields)
                collectMediaRefs(f, note.mediaRefs);

            note.title = stripHtml(fields.first());
            if (note.title.isEmpty()) {
                ++result.skipped;
                continue;
            }
            for (int i = 1; i < fields.size(); ++i) {
                const QString body = stripHtml(fields.at(i));
                if (!body.isEmpty())
                    note.extraFields.push_back(body);
            }
            if (!tags.isEmpty()) {
                for (const QString& t : tags.split(' ', Qt::SkipEmptyParts))
                    note.tags.push_back(t);
            }
            note.deckName = deckNames.value(did);
            result.notes.push_back(std::move(note));
        }

        adb.close();
    }
    QSqlDatabase::removeDatabase(connName);

    if (result.notes.empty())
        return std::unexpected("The package contained no importable notes.");

    return result;
}

} // namespace Service
