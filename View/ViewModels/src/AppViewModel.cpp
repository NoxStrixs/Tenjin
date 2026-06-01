#include <DatabaseManager/DatabaseManager.h>
#include <DeckService/DeckService.h>
#include <ViewModels/AppViewModel.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>
#include <ViewModels/WordViewModel.h>
#include <WordService/WordService.h>

#include <QDir>
#include <QSettings>
#include <QStandardPaths>
#include <QUrl>

AppViewModel::AppViewModel(QObject* parent) : QObject(parent)
{
    const QString dataDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dataDir);
    const std::string dbPath = (dataDir + "/tenjin.db").toStdString();

    auto db = std::make_shared<Service::DatabaseManager>(dbPath);

    m_wordService = std::make_shared<Service::WordService>(db);
    m_deckService = std::make_shared<Service::DeckService>(db);

    m_wordVM    = std::make_unique<WordViewModel>(m_wordService, this);
    m_deckVM    = std::make_unique<DeckViewModel>(m_deckService, m_wordService, this);
    m_sidebarVM = std::make_unique<SidebarViewModel>(m_wordService, this);
    m_reviewVM  = std::make_unique<ReviewViewModel>(m_deckService, m_wordService, this);

    // Sidebar word selection → word VM
    connect(m_sidebarVM.get(),
            &SidebarViewModel::wordSelected,
            m_wordVM.get(),
            &WordViewModel::selectWord);

    // Word changes → sidebar reload
    connect(m_wordVM.get(),
            &WordViewModel::wordListChanged,
            m_sidebarVM.get(),
            &SidebarViewModel::reload);

    // Restore the persisted theme preference.
    QSettings settings;
    m_theme = settings.value("appearance/theme", 0).toInt();
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

bool AppViewModel::exportData(const QString& fileUrl)
{
    const QString path   = QUrl(fileUrl).isLocalFile() ? QUrl(fileUrl).toLocalFile() : fileUrl;
    auto          result = m_wordService->ExportToJson(path);
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
    auto          result = m_wordService->ImportFromJson(path);
    if (!result) {
        setStatusMessage(QStringLiteral("Import failed: ") +
                         QString::fromStdString(result.error()));
        return false;
    }
    // Refresh the views that read from the now-changed collection.
    m_sidebarVM->reload();
    m_deckVM->reloadDecks();
    setStatusMessage(QStringLiteral("Import complete."));
    return true;
}
