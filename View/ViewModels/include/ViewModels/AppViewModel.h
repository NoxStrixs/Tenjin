#pragma once
#include <DeckService/DeckService.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>
#include <ViewModels/WordViewModel.h>
#include <WordService/WordService.h>

#include <QObject>
#include <QString>

#include <memory>

// Root view model. Owns the service stack and all child VMs. Exposed to QML as
// a single context property (`appVM`) — see main.cpp.
class AppViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int currentPage READ currentPage WRITE setCurrentPage NOTIFY currentPageChanged)
    Q_PROPERTY(
        QString statusMessage READ statusMessage WRITE setStatusMessage NOTIFY statusMessageChanged)
    // Persisted UI theme (0 = light, 1 = dark). Saved to QSettings so the
    // choice survives restarts; Platform binds its palette to this via Main.qml.
    Q_PROPERTY(int theme READ theme WRITE setTheme NOTIFY themeChanged)

    Q_PROPERTY(WordViewModel* wordVM READ wordVM CONSTANT)
    Q_PROPERTY(DeckViewModel* deckVM READ deckVM CONSTANT)
    Q_PROPERTY(SidebarViewModel* sidebarVM READ sidebarVM CONSTANT)
    Q_PROPERTY(ReviewViewModel* reviewVM READ reviewVM CONSTANT)
    // True when QtWebEngine was compiled in (WEBVIEW_SUPPORT). Used by QML to
    // decide whether inline web embeds are possible.
    Q_PROPERTY(bool webEngineAvailable READ webEngineAvailable CONSTANT)
    // True when offline LaTeX rendering is available (FORMULA_SUPPORT, via
    // QtWebView). When false, formula blocks show a raw-LaTeX text fallback.
    Q_PROPERTY(bool formulaRenderingAvailable READ formulaRenderingAvailable CONSTANT)

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

    WordViewModel* wordVM() const
    {
        return m_wordVM.get();
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
    bool formulaRenderingAvailable() const
    {
#ifdef TENJIN_FORMULA
        return true;
#else
        return false;
#endif
    }

public slots:
    void setCurrentPage(int page);
    void setStatusMessage(const QString& msg);
    void setTheme(int theme);

public:
    // Export the whole collection to a JSON file. fileUrl may be a file:// URL
    // (from a FileDialog) or a plain path.
    Q_INVOKABLE bool exportData(const QString& fileUrl);
    // Merge a JSON file into the collection (timestamp-based, never deletes).
    Q_INVOKABLE bool importData(const QString& fileUrl);

signals:
    void currentPageChanged();
    void statusMessageChanged();
    void themeChanged();

private:
    int     m_currentPage = PageWords;
    QString m_statusMessage;
    int     m_theme = 0;

    std::shared_ptr<Service::WordService> m_wordService;
    std::shared_ptr<Service::DeckService> m_deckService;

    std::unique_ptr<WordViewModel>    m_wordVM;
    std::unique_ptr<DeckViewModel>    m_deckVM;
    std::unique_ptr<SidebarViewModel> m_sidebarVM;
    std::unique_ptr<ReviewViewModel>  m_reviewVM;
};
