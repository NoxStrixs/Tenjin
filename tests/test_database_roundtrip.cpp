#include <QtTest>
#include <QTemporaryDir>

#include <DatabaseManager/DatabaseManager.h>
#include <DatabaseManager/Types.h>

using namespace Service;

class DatabaseRoundtripTest : public QObject
{
    Q_OBJECT

private slots:
    void addAndFetchEntry();
    void tagLifecycle();
    void exportImportRoundtrip();
};

void DatabaseRoundtripTest::addAndFetchEntry()
{
    QTemporaryDir tmp;
    QVERIFY(tmp.isValid());
    DatabaseManager db((tmp.path() + "/t1.db").toStdString());

    auto added = db.AddEntry("\u3072\u3089\u304c\u306a"); // hiragana
    QVERIFY(added.has_value());
    QVERIFY(added->id > 0);

    auto fetched = db.GetEntryById(added->id);
    QVERIFY(fetched.has_value());
    QCOMPARE(QString::fromStdString(fetched->word), QString("\u3072\u3089\u304c\u306a"));

    auto all = db.GetAllEntries();
    QVERIFY(all.has_value());
    QCOMPARE(all->size(), size_t(1));
}

void DatabaseRoundtripTest::tagLifecycle()
{
    QTemporaryDir tmp;
    DatabaseManager db((tmp.path() + "/t2.db").toStdString());

    auto word = db.AddEntry("inu");
    QVERIFY(word.has_value());
    auto tag = db.AddTag("animals");
    QVERIFY(tag.has_value());

    QVERIFY(db.AddTagToEntry(word->id, tag->id).has_value());

    auto tags = db.GetTagsForEntry(word->id);
    QVERIFY(tags.has_value());
    QCOMPARE(tags->size(), size_t(1));
    QCOMPARE(QString::fromStdString(tags->front().name), QString("animals"));

    QVERIFY(db.RemoveTagFromEntry(word->id, tag->id).has_value());
    auto after = db.GetTagsForEntry(word->id);
    QVERIFY(after.has_value());
    QCOMPARE(after->size(), size_t(0));
}

void DatabaseRoundtripTest::exportImportRoundtrip()
{
    QTemporaryDir tmp;
    const QString exportPath = tmp.path() + "/export.json";

    // Populate the source DB.
    {
        DatabaseManager src((tmp.path() + "/src.db").toStdString());
        auto w1 = src.AddEntry("first");
        auto w2 = src.AddEntry("second");
        QVERIFY(w1.has_value());
        QVERIFY(w2.has_value());
        auto tag = src.AddTag("sample");
        QVERIFY(tag.has_value());
        QVERIFY(src.AddTagToEntry(w1->id, tag->id).has_value());

        auto exported = src.ExportToJson(exportPath);
        QVERIFY2(exported.has_value(), exported ? "" : exported.error().c_str());
    }

    // Import into a fresh DB and verify counts.
    {
        DatabaseManager dst((tmp.path() + "/dst.db").toStdString());
        auto imported = dst.ImportFromJson(exportPath);
        QVERIFY2(imported.has_value(), imported ? "" : imported.error().c_str());

        auto entries = dst.GetAllEntries();
        QVERIFY(entries.has_value());
        QCOMPARE(entries->size(), size_t(2));

        auto tags = dst.GetAllTags();
        QVERIFY(tags.has_value());
        QCOMPARE(tags->size(), size_t(1));
    }
}

int runDatabaseRoundtripTests(int argc, char** argv)
{
    DatabaseRoundtripTest t;
    return QTest::qExec(&t, argc, argv);
}

#include "test_database_roundtrip.moc"
