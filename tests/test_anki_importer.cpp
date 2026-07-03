#include <QtTest>
#include <QTemporaryDir>
#include <QSqlDatabase>
#include <QSqlQuery>

#include <DatabaseManager/AnkiImporter.h>

#include <miniz.h>

using namespace Service;

class AnkiImporterTest : public QObject
{
    Q_OBJECT

private slots:
    void parsesNotesFromMinimalApkg();
    void rejectsNonZip();

private:
    // Build a minimal .apkg containing one note with two fields and a tag.
    QString buildSampleApkg(const QString& dir);
};

QString AnkiImporterTest::buildSampleApkg(const QString& dir)
{
    // 1. Create a tiny collection.anki21 SQLite DB.
    const QString dbPath = dir + "/collection.anki21";
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", "anki_build");
        db.setDatabaseName(dbPath);
        db.open();
        QSqlQuery q(db);
        q.exec("CREATE TABLE notes (id INTEGER PRIMARY KEY, flds TEXT, tags TEXT);");
        q.exec("CREATE TABLE cards (id INTEGER PRIMARY KEY, nid INTEGER, did INTEGER);");
        q.exec("CREATE TABLE decks (id INTEGER PRIMARY KEY, name TEXT);");
        q.exec("INSERT INTO decks (id, name) VALUES (1, 'Japanese');");
        // flds joined by 0x1f
        QSqlQuery ins(db);
        ins.prepare("INSERT INTO notes (id, flds, tags) VALUES (1, :f, :t);");
        ins.bindValue(":f", QString("\u3053\u3093\u306b\u3061\u306f\x1fhello"));
        ins.bindValue(":t", QString("greeting common"));
        ins.exec();
        QSqlQuery c(db);
        c.exec("INSERT INTO cards (id, nid, did) VALUES (1, 1, 1);");
        db.close();
    }
    QSqlDatabase::removeDatabase("anki_build");

    // 2. Zip it into an .apkg.
    const QString apkgPath = dir + "/sample.apkg";
    mz_zip_archive zip;
    memset(&zip, 0, sizeof(zip));
    mz_zip_writer_init_file(&zip, apkgPath.toUtf8().constData(), 0);
    mz_zip_writer_add_file(&zip, "collection.anki21",
                           dbPath.toUtf8().constData(), nullptr, 0, MZ_DEFAULT_COMPRESSION);
    // Empty media manifest.
    const char* media = "{}";
    mz_zip_writer_add_mem(&zip, "media", media, 2, MZ_DEFAULT_COMPRESSION);
    mz_zip_writer_finalize_archive(&zip);
    mz_zip_writer_end(&zip);

    return apkgPath;
}

void AnkiImporterTest::parsesNotesFromMinimalApkg()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    const QString apkg = buildSampleApkg(tmp.path());

    auto result = ParseApkg(apkg);
    QVERIFY2(result.has_value(), result ? "" : result.error().c_str());

    const auto& notes = result->notes;
    QCOMPARE(notes.size(), size_t(1));
    QCOMPARE(notes[0].title, QString("\u3053\u3093\u306b\u3061\u306f"));
    QCOMPARE(notes[0].extraFields.size(), size_t(1));
    QCOMPARE(notes[0].extraFields[0], QString("hello"));
    QCOMPARE(notes[0].tags.size(), size_t(2));
    QCOMPARE(notes[0].deckName, QString("Japanese"));
}

void AnkiImporterTest::rejectsNonZip()
{
    QTemporaryDir tmp;
    const QString bad = tmp.path() + "/not.apkg";
    QFile f(bad);
    f.open(QIODevice::WriteOnly);
    f.write("not a zip file");
    f.close();

    auto result = ParseApkg(bad);
    QVERIFY(!result.has_value());
}

int runAnkiImporterTests(int argc, char** argv)
{
    AnkiImporterTest t;
    return QTest::qExec(&t, argc, argv);
}

#include "test_anki_importer.moc"
