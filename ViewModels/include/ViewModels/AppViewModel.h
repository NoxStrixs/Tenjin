#pragma once
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <QObject>
#include <QSet>
#include <QString>
#include <QVariantList>

#include <memory>

class AppViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int currentPage READ currentPage WRITE setCurrentPage NOTIFY currentPageChanged)
    Q_PROPERTY(
        QString statusMessage READ statusMessage WRITE setStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(int theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(bool welcomeAcknowledged READ welcomeAcknowledged WRITE setWelcomeAcknowledged NOTIFY
                   welcomeAcknowledgedChanged)
    Q_PROPERTY(QVariantList newsItems READ newsItems NOTIFY newsItemsChanged)
    Q_PROPERTY(QString appDataLocation READ appDataLocation CONSTANT)

    // Tag id that the universal search asked the Tags page to highlight.
    // -1 = no highlight active. TagsPage can bind to this and briefly
    // outline / scroll-to the matching tag chip. Cleared automatically by
    // a write of -1 from the page once it acknowledges the request.
    Q_PROPERTY(int highlightedTagId READ highlightedTagId WRITE setHighlightedTagId NOTIFY
                   highlightedTagIdChanged)

    Q_PROPERTY(EntryViewModel* entryVM READ entryVM CONSTANT)
    Q_PROPERTY(DeckViewModel* deckVM READ deckVM CONSTANT)
    Q_PROPERTY(SidebarViewModel* sidebarVM READ sidebarVM CONSTANT)
    Q_PROPERTY(ReviewViewModel* reviewVM READ reviewVM CONSTANT)
    Q_PROPERTY(bool webEngineAvailable READ webEngineAvailable CONSTANT)

public:
    enum Page_t {
        PageWords    = 0,
        PageDecks    = 1,
        PageTags     = 2,
        PageHelp     = 3,
        PageNews     = 4,
        PageSettings = 5,
    };
    Q_ENUM(Page_t)

    explicit AppViewModel(QObject* parent = nullptr);

    int currentPage() const
    {
        return m_currentPage;
    }
    QString statusMessage() const
    {
        return m_statusMessage;
    }
    int theme() const
    {
        return m_theme;
    }
    bool welcomeAcknowledged() const
    {
        return m_welcomeAcknowledged;
    }
    QVariantList newsItems() const
    {
        return m_newsItems;
    }
    QString appDataLocation() const;
    int     highlightedTagId() const
    {
        return m_highlightedTagId;
    }

    EntryViewModel* entryVM() const
    {
        return m_entryVM.get();
    }
    DeckViewModel* deckVM() const
    {
        return m_deckVM.get();
    }
    SidebarViewModel* sidebarVM() const
    {
        return m_sidebarVM.get();
    }
    ReviewViewModel* reviewVM() const
    {
        return m_reviewVM.get();
    }
    bool webEngineAvailable() const
    {
#ifdef TENJIN_WEBVIEW
        return true;
#else
        return false;
#endif
    }

    Q_INVOKABLE QString renderFormula(const QString& latex) const;

    Q_INVOKABLE bool isNewsDismissed(const QString& newsId) const;
    Q_INVOKABLE void dismissNews(const QString& newsId);
    Q_INVOKABLE void resetNewsDismissals();
    Q_INVOKABLE void refreshNews(const QString& url = QString());

public slots:
    void setCurrentPage(int page);
    void setStatusMessage(const QString& msg);
    void setTheme(int theme);
    void setWelcomeAcknowledged(bool acknowledged);
    void setHighlightedTagId(int tagId);

public:
    Q_INVOKABLE bool exportData(const QString& fileUrl);
    Q_INVOKABLE bool importData(const QString& fileUrl);

signals:
    void currentPageChanged();
    void statusMessageChanged();
    void themeChanged();
    void welcomeAcknowledgedChanged();
    void newsDismissedChanged();
    void newsItemsChanged();
    void highlightedTagIdChanged();

private:
    void loadBundledNews();

    int           m_currentPage = PageWords;
    QString       m_statusMessage;
    int           m_theme               = 0;
    bool          m_welcomeAcknowledged = false;
    QSet<QString> m_newsDismissedIds;
    QVariantList  m_newsItems;
    int           m_highlightedTagId = -1;

    std::shared_ptr<Service::EntryService> m_entryService;
    std::shared_ptr<Service::DeckService>  m_deckService;

    std::unique_ptr<EntryViewModel>   m_entryVM;
    std::unique_ptr<DeckViewModel>    m_deckVM;
    std::unique_ptr<SidebarViewModel> m_sidebarVM;
    std::unique_ptr<ReviewViewModel>  m_reviewVM;
};
