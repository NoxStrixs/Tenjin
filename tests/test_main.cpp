#include <QtTest>

// Each test class self-registers via QTEST_APPLESS_MAIN-free pattern.
// We declare them here and run sequentially.
int runAnkiImporterTests(int argc, char** argv);
int runDatabaseRoundtripTests(int argc, char** argv);
int runSchedulingTests(int argc, char** argv);

int main(int argc, char** argv)
{
    int status = 0;
    status |= runAnkiImporterTests(argc, argv);
    status |= runDatabaseRoundtripTests(argc, argv);
    status |= runSchedulingTests(argc, argv);
    return status;
}
