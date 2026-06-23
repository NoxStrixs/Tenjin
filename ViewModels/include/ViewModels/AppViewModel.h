#pragma once
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>

#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QString>
#include <QTranslator>
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

    // Returns the current clipboard contents as plain text. QClipboard::text()
    // ignores HTML/RTF entirely, so calling this and inserting the result
    // strips foreign formatting from pastes -- the right behaviour for our
    // rich-text content blocks, which keep bold/italic/underline as an
    // intentional in-app feature but should never inherit web-page fonts,
    // colors, or sizes.
    Q_INVOKABLE QString clipboardPlainText() const;

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
    // Import an Anki .apkg package. fileUrl may be a file:// URL or raw path.
    // Returns true on success and posts a status message with the count.
    Q_INVOKABLE bool importAnki(const QString& fileUrl, const QString& intoDeck = {});

    // Returns true exactly once after the app's version changes (i.e. just
    // after an update). Records the current version so the next call returns
    // false. Used to show the "What's new" sheet a single time per update.
    // Returns false on a fresh install (no prior version stored) so new users
    // see onboarding instead of a changelog.
    Q_INVOKABLE bool consumeJustUpdated();

    // FileDialog-free import/export surface. QtQuick.Dialogs.FileDialog
    // doesn't work on iOS (no native picker available, the Quick fallback
    // doesn't render -- emits the no-native-option error at runtime). Rather than
    // ship two divergent code paths, every platform now uses these:
    //
    //   exportToDocuments() -- writes the export to the OS's user-visible
    //   Documents folder with a timestamped filename and returns the path.
    //   On iOS users find it via the Files app (we set
    //   UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace in
    //   Info.plist); on desktop it sits in ~/Documents.
    //
    //   availableExports() -- lists *.json files currently in that folder
    //   so the import flow can present a QML picker instead of a
    //   FileDialog. Each entry carries display name, full path, size
    //   string, and modified-date string for the UI to render.
    //
    //   importFromPath(path) -- imports a file by absolute path; used
    //   when the user taps a row in the picker.
    Q_INVOKABLE QString      exportToDocuments();
    Q_INVOKABLE QVariantList availableExports() const;
    // Like availableExports but also lists *.apkg (Anki) files so the mobile
    // import picker can offer both formats.
    Q_INVOKABLE QVariantList availableImports() const;
    Q_INVOKABLE bool         importFromPath(const QString& absolutePath);

    // FileDialog-free media picker companion to availableExports(). Lists
    // image / video / audio files currently in appVM.documentsFolder so
    // the QML media picker can let the user pick one without the broken
    // QtQuick.Dialogs.FileDialog. On iOS the user drops files into the
    // app's Documents folder via the Files app (or via AirDrop /
    // Save to Files from another app); they then show up here.
    Q_INVOKABLE QVariantList availableMediaFiles() const;

    // -- Tag-delete companion + danger zone --------------------------
    //
    // smartDecksUsingTag(tagId) returns [{ id, name }] for smart decks
    // whose filter set includes the given tag. The QML delete-tag
    // flow calls this first; if any decks come back, it lists them in
    // the confirmation popup and calls deleteTagAndAffectedDecks on
    // confirm. If none come back, plain `entryVM.deleteTag(id)` is
    // enough -- the schema's ON DELETE CASCADE handles the join tables.
    //
    // The bulk wipes drop everything in the named table. FK cascades
    // clean up dependent rows (entry_tag, entry_relation, content,
    // deck_entry, deck_tag_filter). deleteEverything() runs the three
    // table wipes in order.
    Q_INVOKABLE QVariantList smartDecksUsingTag(qint64 tagId) const;
    Q_INVOKABLE bool         deleteTagAndAffectedDecks(qint64 tagId);
    Q_INVOKABLE int          deleteAllWords();
    Q_INVOKABLE int          deleteAllTags();
    Q_INVOKABLE int          deleteAllDecks();
    Q_INVOKABLE bool         deleteEverything();

    // kV2 multi-language -- distinct list of language codes currently used
    // by any entry. The Settings page picker reads this to populate its
    // dropdown. Auto-refreshes via the same entryListChanged path the
    // sidebar reload uses.
    Q_PROPERTY(
        QStringList availableLanguages READ availableLanguages NOTIFY availableLanguagesChanged)
    QStringList availableLanguages() const;

    // Built-in language catalogue used by the picker UIs. Returns a list
    // of QVariantMap { code, name } entries, e.g.
    //   [{ code: "en", name: "English" }, { code: "ja", name: "Japanese" }]
    // The list covers common ISO 639-1 codes -- not exhaustive, but the
    // long tail can still be entered as a custom code via the "+ Add"
    // affordance in the picker. CONSTANT because the list doesn't change
    // at runtime.
    Q_PROPERTY(QVariantList builtinLanguages READ builtinLanguages CONSTANT)
    QVariantList builtinLanguages() const;

    Q_PROPERTY(QString documentsFolder READ documentsFolder CONSTANT)
    QString documentsFolder() const;

    // -- UI language (separate from content-language filter) ----------
    //
    // `uiLanguage` is the locale code (e.g. "en", "ja", "es") for the
    // app chrome. Persisted via QSettings. Setting it installs the
    // matching QTranslator and calls QQmlEngine::retranslate() so all
    // qsTr() bindings in QML re-evaluate live -- no restart required.
    //
    // Translations are .qm files compiled from .ts files at build time
    // (translations/tenjin_<code>.ts). The .ts files are populated by
    // `tools/translate.py` which uses Argos Translate (FOSS, MIT) to
    // machine-translate strings from English. Run that script on a
    // developer machine; CI ships the resulting .qm files baked into
    // the qrc.
    //
    // `supportedUiLanguages` is the list of codes for which a .qm
    // file is present in the qrc -- this drives the picker so we
    // only offer locales that actually have translations.
    Q_PROPERTY(QString uiLanguage READ uiLanguage WRITE setUiLanguage NOTIFY uiLanguageChanged)
    Q_PROPERTY(QStringList supportedUiLanguages READ supportedUiLanguages CONSTANT)
    QString uiLanguage() const
    {
        return m_uiLanguage;
    }
    void        setUiLanguage(const QString& code);
    QStringList supportedUiLanguages() const;

    // Wired from main.cpp after engine construction so the VM can call
    // retranslate() on language switch.
    void setQmlEngine(QQmlEngine* engine)
    {
        m_qmlEngine = engine;
    }

signals:
    void currentPageChanged();
    void statusMessageChanged();
    void availableLanguagesChanged();
    void uiLanguageChanged();
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

    // UI translation infra. Installed/swapped on setUiLanguage().
    QString                      m_uiLanguage = QStringLiteral("en");
    std::unique_ptr<QTranslator> m_uiTranslator;
    QQmlEngine*                  m_qmlEngine = nullptr;
};
