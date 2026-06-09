#include <DatabaseManager/DatabaseManager.h>
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/FormulaRenderer.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QUrl>
#include <QVariantMap>

AppViewModel::AppViewModel(QObject* parent) : QObject(parent)
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    const std::string dbPath = (dataDir + "/tenjin.db").toStdString();

    auto db = std::make_shared<Service::DatabaseManager>(dbPath);

    m_entryService = std::make_shared<Service::EntryService>(db);
    m_deckService  = std::make_shared<Service::DeckService>(db);

    m_entryVM   = std::make_unique<EntryViewModel>(m_entryService, this);
    m_deckVM    = std::make_unique<DeckViewModel>(m_deckService, m_entryService, this);
    m_sidebarVM = std::make_unique<SidebarViewModel>(m_entryService, this);
    m_reviewVM  = std::make_unique<ReviewViewModel>(m_deckService, m_entryService, this);

    connect(m_sidebarVM.get(),
            &SidebarViewModel::entrySelected,
            m_entryVM.get(),
            &EntryViewModel::selectEntry);

    connect(m_entryVM.get(),
            &EntryViewModel::entryListChanged,
            m_sidebarVM.get(),
            &SidebarViewModel::reload);

    // The set of distinct languages in use can change whenever an entry
    // is added, deleted, or has its language set. Piggyback on the
    // existing entryListChanged signal so the Settings picker rebinds
    // without us having to add a finer-grained signal upstream.
    connect(m_entryVM.get(),
            &EntryViewModel::entryListChanged,
            this,
            &AppViewModel::availableLanguagesChanged);

    QSettings settings;
    m_theme               = settings.value("appearance/theme", 0).toInt();
    m_welcomeAcknowledged = settings.value("onboarding/welcomeAcknowledged", false).toBool();

    const QStringList ids = settings.value("news/dismissed").toStringList();
    for (const QString& id : ids)
        m_newsDismissedIds.insert(id);

    loadBundledNews();
}

void AppViewModel::loadBundledNews()
{
    auto make =
        [](const char* id, const char* date, const char* title, const char* body, bool popup) {
            QVariantMap m;
            m.insert(QStringLiteral("id"), QString::fromUtf8(id));
            m.insert(QStringLiteral("date"), QString::fromUtf8(date));
            m.insert(QStringLiteral("title"), QString::fromUtf8(title));
            m.insert(QStringLiteral("body"), QString::fromUtf8(body));
            m.insert(QStringLiteral("popup"), popup);
            return QVariant::fromValue(m);
        };

    m_newsItems = {
        make("v1.0-launch",
             "2026-06-04",
             "Welcome to Tenjin 1.0",
             "Tenjin's first public release. Words, decks, spaced-repetition "
             "reviews, tags, and rich content blocks — all stored locally on "
             "your device.",
             false),
        make("multi-platform",
             "2026-06-04",
             "Coming soon: more platforms & polish",
             "We're working on broader platform coverage (Android, polished "
             "macOS builds), multilingual UI, in-app reminders, and a "
             "redesigned analytics page. Stay tuned.",
             true),
    };
}

void AppViewModel::setCurrentPage(int page)
{
    if (m_currentPage == page)
        return;
    m_currentPage = page;
    emit currentPageChanged();
}

void AppViewModel::setStatusMessage(const QString& msg)
{
    m_statusMessage = msg;
    emit statusMessageChanged();
}

void AppViewModel::setTheme(int theme)
{
    if (m_theme == theme)
        return;
    m_theme = theme;
    QSettings settings;
    settings.setValue("appearance/theme", theme);
    emit themeChanged();
}

void AppViewModel::setWelcomeAcknowledged(bool acknowledged)
{
    if (m_welcomeAcknowledged == acknowledged)
        return;
    m_welcomeAcknowledged = acknowledged;
    QSettings settings;
    settings.setValue("onboarding/welcomeAcknowledged", acknowledged);
    emit welcomeAcknowledgedChanged();
}

void AppViewModel::setHighlightedTagId(int tagId)
{
    if (m_highlightedTagId == tagId)
        return;
    m_highlightedTagId = tagId;
    emit highlightedTagIdChanged();
}

bool AppViewModel::isNewsDismissed(const QString& newsId) const
{
    return m_newsDismissedIds.contains(newsId);
}

void AppViewModel::dismissNews(const QString& newsId)
{
    if (newsId.isEmpty())
        return;
    if (m_newsDismissedIds.contains(newsId))
        return;
    m_newsDismissedIds.insert(newsId);
    QSettings   settings;
    QStringList ids;
    ids.reserve(m_newsDismissedIds.size());
    for (const QString& id : m_newsDismissedIds)
        ids.append(id);
    settings.setValue("news/dismissed", ids);
    emit newsDismissedChanged();
}

void AppViewModel::resetNewsDismissals()
{
    if (m_newsDismissedIds.isEmpty())
        return;
    m_newsDismissedIds.clear();
    QSettings settings;
    settings.remove("news/dismissed");
    emit newsDismissedChanged();
}

void AppViewModel::refreshNews(const QString& url)
{
    // Stub: real network fetch is blocked on adding Qt6::Network to the
    // ViewModels CMakeLists. When that lands, this method will use a
    // QNetworkAccessManager against the provided url ("https://localhost"
    // for now) and merge / replace the bundled list on success.
    Q_UNUSED(url);
    loadBundledNews();
    emit newsItemsChanged();
}

bool AppViewModel::exportData(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ExportToJson(path);
    if (!result) {
        setStatusMessage(QStringLiteral("Export failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    setStatusMessage(QStringLiteral("Exported collection to ") + path);
    return true;
}

bool AppViewModel::importData(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ImportFromJson(path);
    if (!result) {
        setStatusMessage(QStringLiteral("Import failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(QStringLiteral("Import complete."));
    return true;
}

// ── FileDialog-free import/export ─────────────────────────────────────

QString AppViewModel::documentsFolder() const
{
    // DocumentsLocation maps to ~/Documents on desktop and the app's iOS
    // sandboxed "Documents" directory on iOS (visible via the Files app
    // because Info.plist sets UIFileSharingEnabled +
    // LSSupportsOpeningDocumentsInPlace). Falls back to AppDataLocation
    // if Documents is somehow unwritable, which happens on locked-down
    // Android profiles.
    QString dir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (dir.isEmpty() || !QDir().mkpath(dir))
        dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return dir;
}

QString AppViewModel::exportToDocuments()
{
    const QString dir = documentsFolder();
    QDir().mkpath(dir);
    const QString stamp = QDateTime::currentDateTime().toString("yyyy-MM-dd-HHmmss");
    const QString path  = dir + "/tenjin-export-" + stamp + ".json";
    if (!exportData(QUrl::fromLocalFile(path).toString()))
        return {};
    return path;
}

QVariantList AppViewModel::availableExports() const
{
    QVariantList  out;
    const QString dir = documentsFolder();
    QDir          d(dir);
    // .json files only, sorted modified-time-descending so the freshest
    // export is on top. Sidebar's import picker renders this list as-is.
    const auto entries =
        d.entryInfoList(QStringList{} << "*.json", QDir::Files | QDir::Readable, QDir::Time);
    for (const QFileInfo& fi : entries) {
        QVariantMap m;
        m["name"]   = fi.fileName();
        m["path"]   = fi.absoluteFilePath();
        m["sizeKB"] = static_cast<double>(fi.size()) / 1024.0;
        m["sizeStr"] =
            QStringLiteral("%1 KB").arg(static_cast<double>(fi.size()) / 1024.0, 0, 'f', 1);
        m["modified"]    = fi.lastModified().toString("yyyy-MM-dd HH:mm");
        m["modifiedIso"] = fi.lastModified().toString(Qt::ISODate);
        out.append(m);
    }
    return out;
}

bool AppViewModel::importFromPath(const QString& absolutePath)
{
    // importData accepts either a file URL or a raw path; normalise to
    // a file URL so it consistently takes the QUrl branch.
    return importData(QUrl::fromLocalFile(absolutePath).toString());
}

QVariantList AppViewModel::availableMediaFiles() const
{
    QVariantList  out;
    const QString dir = documentsFolder();
    QDir          d(dir);
    // Image / video / audio extensions matching what ContentBlock.qml's
    // mediaKind classifier knows how to render. Sorted newest-first so
    // the file the user just dropped via Files.app is on top.
    static const QStringList kFilters = {// Images
                                         "*.png",
                                         "*.jpg",
                                         "*.jpeg",
                                         "*.gif",
                                         "*.bmp",
                                         "*.webp",
                                         "*.svg",
                                         "*.heic",
                                         // Video
                                         "*.mp4",
                                         "*.webm",
                                         "*.mkv",
                                         "*.mov",
                                         "*.m4v",
                                         // Audio
                                         "*.mp3",
                                         "*.wav",
                                         "*.ogg",
                                         "*.flac",
                                         "*.m4a"};
    const auto entries = d.entryInfoList(kFilters, QDir::Files | QDir::Readable, QDir::Time);
    for (const QFileInfo& fi : entries) {
        QVariantMap m;
        m["name"]   = fi.fileName();
        m["path"]   = fi.absoluteFilePath();
        m["sizeKB"] = static_cast<double>(fi.size()) / 1024.0;
        m["sizeStr"] =
            QStringLiteral("%1 KB").arg(static_cast<double>(fi.size()) / 1024.0, 0, 'f', 1);
        m["modified"]    = fi.lastModified().toString("yyyy-MM-dd HH:mm");
        m["modifiedIso"] = fi.lastModified().toString(Qt::ISODate);
        m["suffix"]      = fi.suffix().toLower();
        out.append(m);
    }
    return out;
}

QString AppViewModel::renderFormula(const QString& latex) const
{
    return Tenjin::FormulaRenderer::toRichText(latex);
}

QString AppViewModel::clipboardPlainText() const
{
    // QClipboard::text() returns the clipboard's text/plain representation,
    // not text/html. Pasting via this path strips foreign font, color, size
    // attributes that come from web-page copies — only the literal
    // characters survive. Tenjin's in-app bold/italic/underline are
    // applied separately through the cursorSelection font API.
    const auto* cb = QGuiApplication::clipboard();
    return cb ? cb->text() : QString{};
}

QString AppViewModel::appDataLocation() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}

// ── Tag delete companion + danger zone ──────────────────────────────

QVariantList AppViewModel::smartDecksUsingTag(qint64 tagId) const
{
    QVariantList out;
    auto         decks = m_deckService->GetSmartDecksUsingTag(static_cast<Service::ID_t>(tagId));
    if (!decks)
        return out;
    for (const auto& d : decks.value()) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(d.id);
        m["name"] = QString::fromStdString(d.name);
        out.append(m);
    }
    return out;
}

bool AppViewModel::deleteTagAndAffectedDecks(qint64 tagId)
{
    // Collect affected decks BEFORE deleting the tag — once the tag is
    // gone, the deck_tag_filter rows cascade-delete and we lose the
    // ability to query which decks were affected.
    auto decks = m_deckService->GetSmartDecksUsingTag(static_cast<Service::ID_t>(tagId));

    // Delete the tag first; cascade handles deck_tag_filter cleanup.
    auto tagRes = m_entryService->DeleteTag(static_cast<Service::ID_t>(tagId));
    if (!tagRes) {
        setStatusMessage("Could not delete tag: " + QString::fromStdString(tagRes.error()));
        return false;
    }

    int deckCount = 0;
    if (decks) {
        for (const auto& d : decks.value()) {
            auto r = m_deckService->DeleteDeck(d.id);
            if (r)
                ++deckCount;
        }
    }

    // Refresh the views — m_sidebarVM caches tag + word state,
    // m_deckVM caches the deck list; entryVM caches the filter set.
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(deckCount > 0
                         ? QStringLiteral("Tag deleted; %1 smart deck(s) removed.").arg(deckCount)
                         : QStringLiteral("Tag deleted."));
    return true;
}

int AppViewModel::deleteAllWords()
{
    auto r = m_entryService->DeleteAllEntries();
    if (!r) {
        setStatusMessage("Could not delete words: " + QString::fromStdString(r.error()));
        return 0;
    }
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(QStringLiteral("Deleted %1 word(s).").arg(r.value()));
    return r.value();
}

int AppViewModel::deleteAllTags()
{
    auto r = m_entryService->DeleteAllTags();
    if (!r) {
        setStatusMessage("Could not delete tags: " + QString::fromStdString(r.error()));
        return 0;
    }
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks(); // smart decks lose all their filters
    setStatusMessage(QStringLiteral("Deleted %1 tag(s).").arg(r.value()));
    return r.value();
}

int AppViewModel::deleteAllDecks()
{
    auto r = m_deckService->DeleteAllDecks();
    if (!r) {
        setStatusMessage("Could not delete decks: " + QString::fromStdString(r.error()));
        return 0;
    }
    m_deckVM->reloadDecks();
    setStatusMessage(QStringLiteral("Deleted %1 deck(s).").arg(r.value()));
    return r.value();
}

bool AppViewModel::deleteEverything()
{
    // Order matters: kill decks first so they can't try to recompute
    // smart-filter membership while words/tags are mid-delete. Tags
    // before words is fine either way — both cascade.
    auto       d  = m_deckService->DeleteAllDecks();
    auto       t  = m_entryService->DeleteAllTags();
    auto       w  = m_entryService->DeleteAllEntries();
    const bool ok = d.has_value() && t.has_value() && w.has_value();
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    emit availableLanguagesChanged();
    setStatusMessage(ok ? "All data deleted." : "Some deletes failed — see logs.");
    return ok;
}

QStringList AppViewModel::availableLanguages() const
{
    QStringList out;
    auto        res = m_entryService->GetAllLanguages();
    if (!res)
        return out;
    for (const auto& s : res.value())
        out << QString::fromStdString(s);
    return out;
}

QVariantList AppViewModel::builtinLanguages() const
{
    // Initialised once on first call. Ordering is rough-by-speaker-count
    // and then alphabetic for European languages -- the most-used codes
    // surface near the top of the picker without forcing alphabetical
    // navigation through ar/bn/cs/da/etc. The set is intentionally
    // a curated common-case list; users can type any code in the
    // picker's "+ Add" field for languages that aren't included.
    static const QVariantList kList = [] {
        const struct {
            const char* code;
            const char* name;
        } items[] = {
            {"en", "English"},   {"es", "Spanish"},    {"zh", "Chinese"},    {"hi", "Hindi"},
            {"ar", "Arabic"},    {"pt", "Portuguese"}, {"bn", "Bengali"},    {"ru", "Russian"},
            {"ja", "Japanese"},  {"de", "German"},     {"fr", "French"},     {"ko", "Korean"},
            {"it", "Italian"},   {"tr", "Turkish"},    {"vi", "Vietnamese"}, {"pl", "Polish"},
            {"nl", "Dutch"},     {"sv", "Swedish"},    {"da", "Danish"},     {"fi", "Finnish"},
            {"no", "Norwegian"}, {"el", "Greek"},      {"he", "Hebrew"},     {"cs", "Czech"},
            {"ro", "Romanian"},  {"hu", "Hungarian"},  {"th", "Thai"},       {"id", "Indonesian"},
            {"ms", "Malay"},     {"uk", "Ukrainian"},  {"fa", "Persian"},    {"ur", "Urdu"},
            {"ta", "Tamil"},     {"te", "Telugu"},     {"sw", "Swahili"},    {"tl", "Tagalog"},
            {"la", "Latin"},     {"sa", "Sanskrit"},   {"eo", "Esperanto"},
        };
        QVariantList list;
        for (const auto& it : items) {
            QVariantMap m;
            m["code"] = QString::fromLatin1(it.code);
            m["name"] = QString::fromLatin1(it.name);
            list.append(m);
        }
        return list;
    }();
    return kList;
}
