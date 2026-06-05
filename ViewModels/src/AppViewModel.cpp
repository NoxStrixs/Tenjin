#include <DatabaseManager/DatabaseManager.h>
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/FormulaRenderer.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <QDir>
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

    // Restore persisted user preferences.
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
    // Bundled news. Replaced/augmented by refreshNews() once network fetch
    // is wired in (which is gated on adding Qt6::Network to the ViewModels
    // CMakeLists). Schema mirrors the future remote JSON one-for-one:
    //   id     unique persistent id (used by dismissNews)
    //   date   YYYY-MM-DD
    //   title  short heading
    //   body   plain-text body
    //   popup  true → surface as a single-item popup on next launch
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
    // Stub: network fetch isn't wired yet (the ViewModels module would need
    // Qt6::Network added to its CMakeLists). The configured destination
    // ("https://localhost" today) will be used once that lands. For now we
    // just re-publish the bundled list so QML clients can wire refresh
    // gestures without a behavioural change.
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

QString AppViewModel::renderFormula(const QString& latex) const
{
    return Tenjin::FormulaRenderer::toRichText(latex);
}

QString AppViewModel::appDataLocation() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
}
