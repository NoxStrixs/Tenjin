#pragma once
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <QObject>
#include <QString>

#include <memory>

class AppViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int currentPage READ currentPage WRITE setCurrentPage NOTIFY currentPageChanged)
    Q_PROPERTY(
        QString statusMessage READ statusMessage WRITE setStatusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(int theme READ theme WRITE setTheme NOTIFY themeChanged)

    Q_PROPERTY(EntryViewModel* entryVM READ entryVM CONSTANT)
    Q_PROPERTY(DeckViewModel* deckVM READ deckVM CONSTANT)
    Q_PROPERTY(SidebarViewModel* sidebarVM READ sidebarVM CONSTANT)
    Q_PROPERTY(ReviewViewModel* reviewVM READ reviewVM CONSTANT)
    Q_PROPERTY(bool webEngineAvailable READ webEngineAvailable CONSTANT)

public:
    enum Page_t {
        PageWords = 0,
        PageDecks = 1,
        PageTags  = 2,
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

public slots:
    void setCurrentPage(int page);
    void setStatusMessage(const QString& msg);
    void setTheme(int theme);

public:
    Q_INVOKABLE bool exportData(const QString& fileUrl);
    Q_INVOKABLE bool importData(const QString& fileUrl);

signals:
    void currentPageChanged();
    void statusMessageChanged();
    void themeChanged();

private:
    int     m_currentPage = PageWords;
    QString m_statusMessage;
    int     m_theme = 0;

    std::shared_ptr<Service::EntryService> m_entryService;
    std::shared_ptr<Service::DeckService>  m_deckService;

    std::unique_ptr<EntryViewModel>   m_entryVM;
    std::unique_ptr<DeckViewModel>    m_deckVM;
    std::unique_ptr<SidebarViewModel> m_sidebarVM;
    std::unique_ptr<ReviewViewModel>  m_reviewVM;
};
