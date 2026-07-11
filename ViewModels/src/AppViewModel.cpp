#include <DatabaseManager/DatabaseManager.h>
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/FormulaRenderer.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <TenjinConfig.h>

#include <QClipboard>
#include <QCoreApplication>
#include <QDateTime>

#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QLocale>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QStringList>
#include <QTranslator>
#include <QUrl>
#include <QVariantMap>
#include <functional>

#include <ViewModels/PlatformHooks.h>


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
    m_reducedMotion       = settings.value("appearance/reducedMotion", false).toBool();
    m_systemReducedMotion = tenjin::platformPrefersReducedMotion();
    m_customAccent        = settings.value("appearance/customAccent", m_customAccent).toString();
    m_customBg            = settings.value("appearance/customBg", m_customBg).toString();
    m_customSurface       = settings.value("appearance/customSurface", m_customSurface).toString();
    m_customText          = settings.value("appearance/customText", m_customText).toString();
    m_customDanger        = settings.value("appearance/customDanger", m_customDanger).toString();
    m_customSuccess       = settings.value("appearance/customSuccess", m_customSuccess).toString();
    m_customBorder        = settings.value("appearance/customBorder", m_customBorder).toString();
    m_customIsDark        = settings.value("appearance/customIsDark", false).toBool();
    m_customLanguages     = settings.value("language/customCodes").toStringList();
    m_ageBand             = settings.value("privacy/ageBand", AgeUnknown).toInt();
    m_consentStatus       = settings.value("privacy/consentStatus", ConsentNotRequired).toInt();
    m_welcomeAcknowledged = settings.value("onboarding/welcomeAcknowledged", false).toBool();

    const QStringList ids = settings.value("news/dismissed").toStringList();
    for (const QString& id : ids)
        m_newsDismissedIds.insert(id);

    // UI language: persisted code, fall back to the system locale's
    // language only if we actually ship a .qm for it; otherwise English.
    {
        QString stored = settings.value("ui/language").toString();
        if (stored.isEmpty()) {
            const QString sysCode = QLocale::system().name().section('_', 0, 0);
            if (supportedUiLanguages().contains(sysCode))
                stored = sysCode;
            else
                stored = QStringLiteral("en");
        }
        // Install without emitting -- m_qmlEngine isn't wired yet anyway.
        m_uiLanguage = stored;
        if (m_uiLanguage != QStringLiteral("en")) {
            auto t = std::make_unique<QTranslator>();
            if (t->load(QStringLiteral(":/i18n/tenjin_") + m_uiLanguage + QStringLiteral(".qm"))) {
                QCoreApplication::installTranslator(t.get());
                m_uiTranslator = std::move(t);
            }
        }
        // Apply the locale's direction at startup so RTL languages come up
        // mirrored on first paint rather than after a language change.
        if (auto* gui = qobject_cast<QGuiApplication*>(QCoreApplication::instance()))
            gui->setLayoutDirection(QLocale(m_uiLanguage).textDirection());
    }

    loadBundledNews();
}

void AppViewModel::addCustomLanguage(const QString& code)
{
    const QString c = code.trimmed().toLower();
    // ISO-ish sanity: 2..8 chars, letters/digits/hyphen. Reject junk quietly.
    if (c.isEmpty() || c.size() > 8 || m_customLanguages.contains(c))
        return;
    for (const QChar ch : c) {
        if (!ch.isLetterOrNumber() && ch != QLatin1Char('-'))
            return;
    }
    m_customLanguages.append(c);
    m_customLanguages.sort();
    QSettings().setValue("language/customCodes", m_customLanguages);
    emit customLanguagesChanged();
}

void AppViewModel::removeCustomLanguage(const QString& code)
{
    if (m_customLanguages.removeAll(code.trimmed().toLower()) == 0)
        return;
    QSettings().setValue("language/customCodes", m_customLanguages);
    emit customLanguagesChanged();
}

void AppViewModel::renameCustomLanguage(const QString& oldCode, const QString& newCode)
{
    const QString o = oldCode.trimmed().toLower();
    if (!m_customLanguages.contains(o))
        return;
    removeCustomLanguage(o);
    addCustomLanguage(newCode);
}

bool AppViewModel::openNativeImportPicker()
{
    // Delegates to the injected platform DocumentPickerService. The result
    // arrives asynchronously via documentPicked() (wired in setDocumentPicker),
    // which calls importFromPath(). Returns false when no native picker is
    // available so the caller can show the in-app Documents picker.
    if (!m_documentPicker)
        return false;
    m_documentPicker->pickImportDocument();
    return true;
}

void AppViewModel::setDocumentPicker(DocumentPickerService* picker)
{
    if (m_documentPicker == picker)
        return;
    m_documentPicker = picker;
    if (m_documentPicker) {
        connect(m_documentPicker, &DocumentPickerService::documentPicked, this,
                [this](const QString& path) { importFromPath(path); });
        // Native media picker result → relay to QML for attachment to the
        // active content block.
        connect(m_documentPicker, &DocumentPickerService::mediaPicked, this,
                [this](const QString& path) { emit entryMediaPicked(path); });
    }
}

bool AppViewModel::pickEntryMedia(int source)
{
    if (!m_documentPicker)
        return false;
    m_documentPicker->pickMedia(static_cast<DocumentPickerService::MediaSource>(source));
    return true;
}

bool AppViewModel::shareFile(const QString& absPath)
{
    if (absPath.isEmpty())
        return false;
    return tenjin::platformShareFile(absPath);
}

QString AppViewModel::languageDisplayName(const QString& code) const
{
    if (code.isEmpty())
        return {};
    const QLocale loc(code);
    // nativeLanguageName gives the endonym (e.g. "español", "日本語"). Empty for
    // codes QLocale can't parse — fall back to the raw code so nothing renders
    // blank.
    const QString native = loc.nativeLanguageName();
    return native.isEmpty() ? code : native;
}

void AppViewModel::setUiLanguage(const QString& code)
{
    if (code == m_uiLanguage)
        return;

    // Remove previous translator if any.
    if (m_uiTranslator) {
        QCoreApplication::removeTranslator(m_uiTranslator.get());
        m_uiTranslator.reset();
    }

    // Install the new one (English == no translator, base strings).
    if (code != QStringLiteral("en")) {
        auto t = std::make_unique<QTranslator>();
        if (!t->load(QStringLiteral(":/i18n/tenjin_") + code + QStringLiteral(".qm"))) {
            // .qm missing -- fall back silently to English so the picker
            // never leaves the UI in a broken half-translated state.
            m_uiLanguage = QStringLiteral("en");
        } else {
            QCoreApplication::installTranslator(t.get());
            m_uiTranslator = std::move(t);
            m_uiLanguage   = code;
        }
    } else {
        m_uiLanguage = QStringLiteral("en");
    }

    QSettings().setValue("ui/language", m_uiLanguage);

    // Drive the global layout direction from the active locale. The root
    // ApplicationWindow's LayoutMirroring and the direction-aware icons in
    // TenjinIcons read this (singletons cannot see appVM), so both flip
    // together for RTL languages.
    if (auto* gui = qobject_cast<QGuiApplication*>(QCoreApplication::instance()))
        gui->setLayoutDirection(QLocale(m_uiLanguage).textDirection());

    // Live-swap: tell the QML engine to re-evaluate every qsTr() binding.
    // Without this the change only shows after restart.
    if (m_qmlEngine)
        m_qmlEngine->retranslate();

    emit uiLanguageChanged();
}

QStringList AppViewModel::supportedUiLanguages() const
{
    // Languages for which a .qm file ships in the qrc. The qrc prefix is
    // "/i18n" (see translations/CMakeLists.txt -- the qt_add_translations
    // call uses RESOURCE_PREFIX "/i18n"). QDir scans the qrc; this
    // implicitly tracks whatever the build actually shipped.
    QStringList out{QStringLiteral("en")};
    QDir        d(QStringLiteral(":/i18n"));
    const auto  qms = d.entryList({QStringLiteral("tenjin_*.qm")}, QDir::Files);
    for (const QString& f : qms) {
        // tenjin_<code>.qm -> <code>
        QString code = f;
        code.remove(QStringLiteral("tenjin_"));
        code.chop(3);
        if (!code.isEmpty() && code != QStringLiteral("en"))
            out.append(code);
    }
    return out;
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

void AppViewModel::setCustomColor(const QString& key, const QString& hex)
{
    // Validate a #rrggbb (or #rgb) hex string before storing, so a bad value
    // from QML can't poison the palette.
    static const QRegularExpression re(QStringLiteral("^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$"));
    if (!re.match(hex).hasMatch())
        return;

    QString*    slot       = nullptr;
    const char* settingKey = nullptr;
    if (key == QLatin1String("accent")) {
        slot       = &m_customAccent;
        settingKey = "appearance/customAccent";
    } else if (key == QLatin1String("bg")) {
        slot       = &m_customBg;
        settingKey = "appearance/customBg";
    } else if (key == QLatin1String("surface")) {
        slot       = &m_customSurface;
        settingKey = "appearance/customSurface";
    } else if (key == QLatin1String("text")) {
        slot       = &m_customText;
        settingKey = "appearance/customText";
    } else if (key == QLatin1String("danger")) {
        slot       = &m_customDanger;
        settingKey = "appearance/customDanger";
    } else if (key == QLatin1String("success")) {
        slot       = &m_customSuccess;
        settingKey = "appearance/customSuccess";
    } else if (key == QLatin1String("border")) {
        slot       = &m_customBorder;
        settingKey = "appearance/customBorder";
    } else {
        return; // unknown key
    }

    if (*slot == hex)
        return;
    *slot = hex;
    QSettings().setValue(QLatin1String(settingKey), hex);
    emit customThemeChanged();
}

void AppViewModel::setCustomIsDark(bool dark)
{
    if (m_customIsDark == dark)
        return;
    m_customIsDark = dark;
    QSettings().setValue("appearance/customIsDark", dark);
    emit customThemeChanged();
}

void AppViewModel::setReducedMotion(bool on)
{
    if (m_reducedMotion == on)
        return;
    m_reducedMotion = on;
    QSettings().setValue("appearance/reducedMotion", on);
    emit reducedMotionChanged();
}

void AppViewModel::setAgeBand(int band)
{
    if (band != AgeUnder13 && band != Age13Plus)
        band = AgeUnknown;
    m_ageBand = band;

    // 13+ needs no parental consent; under-13 starts in Pending until a verified
    // parent grants it. The neutral age screen must not be re-answerable to
    // raise the band trivially, so callers should treat this as one-shot.
    if (band == Age13Plus)
        m_consentStatus = ConsentNotRequired;
    else if (band == AgeUnder13 && m_consentStatus == ConsentNotRequired)
        m_consentStatus = ConsentPending;

    QSettings settings;
    settings.setValue("privacy/ageBand", m_ageBand);
    settings.setValue("privacy/consentStatus", m_consentStatus);
    settings.setValue("privacy/ageSetAt", QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    emit consentChanged();
}

void AppViewModel::recordParentalConsent(bool granted, const QString& grantedBy)
{
    // Only meaningful for under-13 users.
    if (m_ageBand != AgeUnder13)
        return;

    m_consentStatus = granted ? ConsentGranted : ConsentDenied;

    // COPPA requires a record of the consent event: who/when/for-what. We log an
    // auditable entry locally; when the backend exists this should also be
    // mirrored server-side. We deliberately store only the method note, not any
    // parent identity document.
    QSettings settings;
    settings.setValue("privacy/consentStatus", m_consentStatus);
    settings.setValue("privacy/consentRecordedAt",
                      QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    settings.setValue("privacy/consentMethod", grantedBy);
    emit consentChanged();
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
    Q_UNUSED(url);
    // Network fetch via CloudService (wired externally from main.cpp).
    // Falls back to bundled list when no cloud URL is configured.
    loadBundledNews();
    emit newsItemsChanged();
}

bool AppViewModel::exportData(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ExportToJson(path);
    if (!result) {
        setStatusMessage(tr("Export failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    setStatusMessage(tr("Exported collection to %1").arg(path));
    return true;
}

bool AppViewModel::exportDataCsv(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ExportToCsv(path);
    if (!result) {
        setStatusMessage(tr("Export failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    setStatusMessage(tr("Exported CSV to %1").arg(path));
    return true;
}

bool AppViewModel::importData(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ImportFromJson(path);
    if (!result) {
        setStatusMessage(tr("Import failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(tr("Import complete."));
    return true;
}

bool AppViewModel::consumeJustUpdated()
{
    QSettings     settings;
    const QString current = QCoreApplication::applicationVersion();
    const QString stored  = settings.value("app/lastSeenVersion").toString();

    settings.setValue("app/lastSeenVersion", current);

    // Fresh install (no stored version) → not an update; show onboarding instead.
    if (stored.isEmpty())
        return false;
    return stored != current;
}

bool AppViewModel::importAnki(const QString& fileUrl, const QString& intoDeck)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_entryService->ImportFromAnki(path, intoDeck);
    if (!result) {
        setStatusMessage(tr("Anki import failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(tr("Imported %1 cards from Anki.").arg(result.value()));
    return true;
}

// FileDialog-free import/export
QString AppViewModel::appVersion() const
{
    return QString::fromLatin1(Tenjin::Config::kVersionString);
}

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

void AppViewModel::autoBackupBeforeDestructive(const QString& reason)
{
    // Write a timestamped JSON snapshot of all data into the documents folder
    // before a destructive bulk delete. Recoverable through the normal import
    // picker. Best effort: failure is surfaced but does not block the delete
    // the user already confirmed.
    const QString dir = documentsFolder();
    QDir().mkpath(dir);
    const QString stamp = QDateTime::currentDateTime().toString("yyyy-MM-dd-HHmmss");
    const QString path  = dir + "/tenjin-backup-" + reason + "-" + stamp + ".json";
    if (exportData(QUrl::fromLocalFile(path).toString()))
        setStatusMessage(tr("Backup saved before deleting: %1").arg(path));
    else
        setStatusMessage(tr("Warning: automatic backup failed before delete."));

    pruneAutoBackups(dir);
}

// Keep only the N most recent auto-backups. Only files matching the
// auto-backup name pattern are considered — user-initiated manual exports
// (different name) are never touched.
void AppViewModel::pruneAutoBackups(const QString& dir)
{
    constexpr int kKeep = 5;
    QDir d(dir);
    // Auto-backups are named "tenjin-backup-<reason>-<stamp>.json".
    QStringList backups =
        d.entryList(QStringList{ QStringLiteral("tenjin-backup-*.json") },
                    QDir::Files, QDir::Time); // newest first
    for (int i = kKeep; i < backups.size(); ++i)
        QFile::remove(d.filePath(backups.at(i)));
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

QString AppViewModel::exportToDocumentsCsv()
{
    const QString dir = documentsFolder();
    QDir().mkpath(dir);
    const QString stamp = QDateTime::currentDateTime().toString("yyyy-MM-dd-HHmmss");
    const QString path  = dir + "/tenjin-export-" + stamp + ".csv";
    if (!exportDataCsv(QUrl::fromLocalFile(path).toString()))
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

QVariantList AppViewModel::availableImports() const
{
    QVariantList  out;
    const QString dir = documentsFolder();
    QDir          d(dir);
    // Both Tenjin (*.json) and Anki (*.apkg) packages.
    const auto entries = d.entryInfoList(
        QStringList{} << "*.json" << "*.apkg", QDir::Files | QDir::Readable, QDir::Time);
    for (const QFileInfo& fi : entries) {
        const bool  isAnki = fi.suffix().compare("apkg", Qt::CaseInsensitive) == 0;
        QVariantMap m;
        m["name"]   = fi.fileName();
        m["path"]   = fi.absoluteFilePath();
        m["format"] = isAnki ? QStringLiteral("anki") : QStringLiteral("tenjin");
        m["sizeStr"] =
            QStringLiteral("%1 KB").arg(static_cast<double>(fi.size()) / 1024.0, 0, 'f', 1);
        m["modified"] = fi.lastModified().toString("yyyy-MM-dd HH:mm");
        out.append(m);
    }
    return out;
}

bool AppViewModel::importFromPath(const QString& absolutePath)
{
    // Dispatch by extension: .apkg → Anki import, everything else → JSON.
    if (absolutePath.endsWith(QStringLiteral(".apkg"), Qt::CaseInsensitive))
        return importAnki(QUrl::fromLocalFile(absolutePath).toString());
    return importData(QUrl::fromLocalFile(absolutePath).toString());
}

QVariantList AppViewModel::availableMediaFiles() const
{
    QVariantList  out;
    const QString dir = documentsFolder();
    QDir          d(dir);
    // Any file the user dropped into Documents is fair game -- the
    // block renderer falls back to a generic "open externally" link
    // for unknown extensions (ContentBlock.qml mediaKind === "file").
    // No filter = no surprises when the user expects a .pdf or .zip
    // to be selectable.
    const auto entries = d.entryInfoList(QDir::Files | QDir::Readable, QDir::Time);
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

// Tag delete companion + danger zone
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
        setStatusMessage(tr("Could not delete tag: %1").arg(QString::fromStdString(tagRes.error())));
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
    autoBackupBeforeDestructive(QStringLiteral("delete-words"));
    auto r = m_entryService->DeleteAllEntries();
    if (!r) {
        setStatusMessage(tr("Could not delete words: %1").arg(QString::fromStdString(r.error())));
        return 0;
    }
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();

    // All entries gone -> nothing can reference any media file. Wipe
    // the managed media dir entirely. External-link imports (paths
    // outside this dir) were never copied, so there's nothing to do
    // for them.
    {
        const QString mediaDirPath =
            QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
            QStringLiteral("/media");
        QDir(mediaDirPath).removeRecursively();
    }

    setStatusMessage(tr("Deleted %1 word(s).").arg(r.value()));
    return r.value();
}

int AppViewModel::deleteAllTags()
{
    autoBackupBeforeDestructive(QStringLiteral("delete-tags"));
    auto r = m_entryService->DeleteAllTags();
    if (!r) {
        setStatusMessage(tr("Could not delete tags: %1").arg(QString::fromStdString(r.error())));
        return 0;
    }
    m_entryVM->reloadAfterDataChange();
    m_sidebarVM->reload();
    m_deckVM->reloadDecks(); // smart decks lose all their filters
    setStatusMessage(tr("Deleted %1 tag(s).").arg(r.value()));
    return r.value();
}

int AppViewModel::deleteAllDecks()
{
    autoBackupBeforeDestructive(QStringLiteral("delete-decks"));
    auto r = m_deckService->DeleteAllDecks();
    if (!r) {
        setStatusMessage(tr("Could not delete decks: %1").arg(QString::fromStdString(r.error())));
        return 0;
    }
    m_deckVM->reloadDecks();
    setStatusMessage(tr("Deleted %1 deck(s).").arg(r.value()));
    return r.value();
}

bool AppViewModel::deleteEverything()
{
    // Safety net: write a timestamped backup before wiping everything, so an
    // accidental "delete all" is recoverable via the normal import flow. Best
    // effort — if the backup fails we still proceed (the user explicitly
    // confirmed), but we surface a note so they know.
    autoBackupBeforeDestructive(QStringLiteral("delete-all"));
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

    // No entries left -> no media references -> remove the managed
    // media dir wholesale.
    {
        const QString mediaDirPath =
            QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) +
            QStringLiteral("/media");
        QDir(mediaDirPath).removeRecursively();
    }

    setStatusMessage(ok ? tr("All data deleted.") : tr("Some deletes failed — see logs."));
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
