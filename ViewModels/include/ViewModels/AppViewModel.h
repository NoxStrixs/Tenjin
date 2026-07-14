#pragma once
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/DeckViewModel.h>
#include <ViewModels/EntryViewModel.h>
#include <ViewModels/ReviewViewModel.h>
#include <ViewModels/SidebarViewModel.h>
#include <ViewModels/DocumentPickerService.h>

#include <QLocale>
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
    // Custom-theme anchor colors (hex strings like "#rrggbb"). Persisted; pushed
    // into Platform when theme == 2 (custom). A single setter updates one anchor
    // by key so the QML picker stays simple.
    Q_PROPERTY(QString customAccent READ customAccent NOTIFY customThemeChanged)
    Q_PROPERTY(QString customBg READ customBg NOTIFY customThemeChanged)
    Q_PROPERTY(QString customSurface READ customSurface NOTIFY customThemeChanged)
    Q_PROPERTY(QString customText READ customText NOTIFY customThemeChanged)
    Q_PROPERTY(QString customDanger READ customDanger NOTIFY customThemeChanged)
    Q_PROPERTY(QString customSuccess READ customSuccess NOTIFY customThemeChanged)
    Q_PROPERTY(QString customBorder READ customBorder NOTIFY customThemeChanged)
    Q_PROPERTY(bool customIsDark READ customIsDark NOTIFY customThemeChanged)
    Q_PROPERTY(
        bool reducedMotion READ reducedMotion WRITE setReducedMotion NOTIFY reducedMotionChanged)
    // Read-only: whether the OS "reduce motion" accessibility setting is on.
    // Probed once at construction via a per-platform backend (iOS/Android);
    // false on platforms without the setting. The UI ORs this with the in-app
    // toggle so either source disables animations.
    Q_PROPERTY(bool systemReducedMotion READ systemReducedMotion CONSTANT)

    // ── Children's-privacy / consent state (COPPA, GDPR-K) ──────────────────
    // ageBand is set once by a neutral age screen; consentStatus tracks
    // verifiable parental consent for under-13 users. dataCollectionAllowed is
    // the single gate the network layer checks before any off-device call.
    Q_PROPERTY(int ageBand READ ageBand NOTIFY consentChanged)
    Q_PROPERTY(int consentStatus READ consentStatus NOTIFY consentChanged)
    Q_PROPERTY(bool ageScreenRequired READ ageScreenRequired NOTIFY consentChanged)
    Q_PROPERTY(bool dataCollectionAllowed READ dataCollectionAllowed NOTIFY consentChanged)
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

    // COPPA/GDPR-K age band, established by a neutral age screen on first run.
    // "Unknown" until the user answers; gates all off-device network calls.
    enum AgeBand_t {
        AgeUnknown = 0,
        AgeUnder13 = 1, // COPPA applies: parental consent required before any collection
        Age13Plus  = 2, // general audience
    };
    Q_ENUM(AgeBand_t)

    // Verifiable-parental-consent status for an under-13 user. Network calls
    // that transmit data stay blocked unless this is Granted.
    enum ConsentStatus_t {
        ConsentNotRequired = 0, // 13+ user, or nothing to consent to
        ConsentPending     = 1, // under-13, awaiting verifiable parental consent
        ConsentGranted     = 2, // parent verified and consented
        ConsentDenied      = 3, // parent declined; app runs fully local
    };
    Q_ENUM(ConsentStatus_t)

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
    QString customAccent() const
    {
        return m_customAccent;
    }
    QString customBg() const
    {
        return m_customBg;
    }
    QString customSurface() const
    {
        return m_customSurface;
    }
    QString customText() const
    {
        return m_customText;
    }
    QString customDanger() const
    {
        return m_customDanger;
    }
    QString customSuccess() const
    {
        return m_customSuccess;
    }
    QString customBorder() const
    {
        return m_customBorder;
    }
    bool customIsDark() const
    {
        return m_customIsDark;
    }
    // Update one custom-theme anchor by key ("accent"/"bg"/"surface"/"text").
    // Persists and notifies; the QML layer pushes the values into Platform.
    Q_INVOKABLE void setCustomColor(const QString& key, const QString& hex);
    Q_INVOKABLE void setCustomIsDark(bool dark);
    bool             reducedMotion() const
    {
        return m_reducedMotion;
    }
    bool systemReducedMotion() const
    {
        return m_systemReducedMotion;
    }

    int ageBand() const
    {
        return m_ageBand;
    }
    int consentStatus() const
    {
        return m_consentStatus;
    }
    // True until the user has answered the neutral age screen at least once.
    bool ageScreenRequired() const
    {
        return m_ageBand == AgeUnknown;
    }
    // The single authority the network layer consults. Off-device data
    // collection is allowed only when the user is 13+, OR an under-13 user has
    // recorded verifiable parental consent. Unknown age = blocked (fail closed).
    bool dataCollectionAllowed() const
    {
        if (m_ageBand == Age13Plus)
            return true;
        if (m_ageBand == AgeUnder13)
            return m_consentStatus == ConsentGranted;
        return false; // AgeUnknown — fail closed until the age screen is answered
    }

    // Records the age band from the neutral age screen. For under-13 this moves
    // consent into Pending; for 13+ no consent is required.
    Q_INVOKABLE void setAgeBand(int band);
    // Records the outcome of the (verifiable) parental-consent flow for an
    // under-13 user. `grantedBy` is a short audit note (method used).
    Q_INVOKABLE void recordParentalConsent(bool granted, const QString& grantedBy = QString());
    bool             welcomeAcknowledged() const
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
    // Render Anki-style cloze text ({{cN::answer::hint}}). When masked, each
    // deletion becomes "[…]" (or "[hint]" if a hint is present); when revealed,
    // the answer is shown emphasized. Returns rich text for a Text element.
    Q_INVOKABLE QString renderCloze(const QString& text, bool masked, int ordinal = 0) const;
    // True if the text contains at least one cloze deletion — the UI uses this
    // to decide whether a block participates in cloze review.
    Q_INVOKABLE bool hasCloze(const QString& text) const;

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
    void setReducedMotion(bool on);
    void setWelcomeAcknowledged(bool acknowledged);
    void setHighlightedTagId(int tagId);

public:
    Q_INVOKABLE bool exportData(const QString& fileUrl);
    Q_INVOKABLE bool exportDataCsv(const QString& fileUrl);
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
    Q_INVOKABLE QString      exportToDocumentsCsv();
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

    // Native media attach picker for entry content. `source` maps to
    // DocumentPickerService::MediaSource (0=Files, 1=Photos, 2=Camera). The
    // QML custom chooser (SheetPopup) selects the source; the result arrives
    // via the entryMediaPicked() signal (wired in setDocumentPicker). Returns
    // false if no picker is injected so QML can fall back to the in-app
    // MediaPickerDialog (desktop / no native picker).
    Q_INVOKABLE bool pickEntryMedia(int source);

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

    // User-defined language codes (rare ISO codes, conlangs, personal
    // categories). Persisted globally so a custom code stays offered in every
    // language picker even when no entry currently uses it. Managed via the
    // add/remove/rename invokables below (edit UI hooks).
    Q_PROPERTY(QStringList customLanguages READ customLanguages NOTIFY customLanguagesChanged)
    QStringList customLanguages() const
    {
        return m_customLanguages;
    }
    Q_INVOKABLE void addCustomLanguage(const QString& code);
    Q_INVOKABLE void removeCustomLanguage(const QString& code);
    Q_INVOKABLE void renameCustomLanguage(const QString& oldCode, const QString& newCode);

    // Built-in language catalogue used by the picker UIs. Returns a list
    // of QVariantMap { code, name } entries, e.g.
    //   [{ code: "en", name: "English" }, { code: "ja", name: "Japanese" }]
    // The list covers common ISO 639-1 codes -- not exhaustive, but the
    // long tail can still be entered as a custom code via the "+ Add"
    // affordance in the picker. CONSTANT because the list doesn't change
    // at runtime.
    Q_PROPERTY(QVariantList builtinLanguages READ builtinLanguages CONSTANT)
    QVariantList builtinLanguages() const;


    // Display version string (major.minor.patch+<git-hash>) from the generated
    // config header. Single source of truth: project(VERSION)/git describe.
    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)
    QString appVersion() const;

    Q_PROPERTY(QString documentsFolder READ documentsFolder CONSTANT)
    QString documentsFolder() const;
    // Writes a timestamped JSON backup of all data before a destructive bulk
    // delete (recoverable via import). Best effort; never blocks the delete.
    void autoBackupBeforeDestructive(const QString& reason);
    void pruneAutoBackups(const QString& dir);

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

    // True when the active UI language is written right-to-left (Arabic,
    // Hebrew, Persian, Urdu). The root ApplicationWindow binds LayoutMirroring
    // to this so anchors and RowLayouts mirror automatically. Derived from
    // QLocale rather than a hardcoded list so new locales work unchanged.
    Q_PROPERTY(bool uiLayoutRightToLeft READ uiLayoutRightToLeft NOTIFY uiLanguageChanged)
    bool uiLayoutRightToLeft() const
    {
        return QLocale(uiLanguage()).textDirection() == Qt::RightToLeft;
    }
    Q_PROPERTY(QStringList supportedUiLanguages READ supportedUiLanguages CONSTANT)
    QString uiLanguage() const
    {
        return m_uiLanguage;
    }
    Q_INVOKABLE void setUiLanguage(const QString& code);
    // Human-readable, native display name for an ISO 639-1 code (e.g. "es" ->
    // "español"). Backed by QLocale so it stays correct without a hand-kept
    // table. Falls back to the code itself for unrecognised inputs.
    Q_INVOKABLE QString languageDisplayName(const QString& code) const;
    // Opens the platform share sheet for a file exported to the app sandbox.
    // False on platforms without a share backend (desktop; Android pending
    // FileProvider) so QML can fall back to a path toast.
    Q_INVOKABLE bool shareFile(const QString& absPath);
    // Native Files/iCloud picker for import; false where unsupported so QML
    // falls back to the in-app Documents picker.
    Q_INVOKABLE bool openNativeImportPicker();

    // Injected by main.cpp (owns the platform service). AppViewModel wires
    // documentPicked -> importFromPath and drives the picker from
    // openNativeImportPicker(). Not owned.
    void setDocumentPicker(DocumentPickerService* picker);
    QStringList      supportedUiLanguages() const;

    // Wired from main.cpp after engine construction so the VM can call
    // retranslate() on language switch.
    void setQmlEngine(QQmlEngine* engine)
    {
        m_qmlEngine = engine;
    }

signals:
    void currentPageChanged();
    // Emitted when the native media picker returns a file for entry attachment.
    // QML connects this to import the path into the active content block.
    void entryMediaPicked(const QString& path);
    void statusMessageChanged();
    void availableLanguagesChanged();
    void customLanguagesChanged();
    void uiLanguageChanged();
    void themeChanged();
    void customThemeChanged();
    void reducedMotionChanged();
    void consentChanged();
    void welcomeAcknowledgedChanged();
    void newsDismissedChanged();
    void newsItemsChanged();
    void highlightedTagIdChanged();

private:
    void loadBundledNews();

    int           m_currentPage = PageWords;
    QString       m_statusMessage;
    int           m_theme               = 0;
    QString       m_customAccent        = QStringLiteral("#d4a373");
    QString       m_customBg            = QStringLiteral("#fefae0");
    QString       m_customSurface       = QStringLiteral("#faedcd");
    QString       m_customText          = QStringLiteral("#3d2c1e");
    QString       m_customDanger        = QStringLiteral("#c0392b");
    QString       m_customSuccess       = QStringLiteral("#6a8f5a");
    QString       m_customBorder        = QStringLiteral("#e0d4b8");
    bool          m_customIsDark        = false;
    bool          m_reducedMotion       = false;
    bool          m_systemReducedMotion = false;
    int           m_ageBand             = AgeUnknown;
    int           m_consentStatus       = ConsentNotRequired;
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
    QStringList                  m_customLanguages;
    std::unique_ptr<QTranslator> m_uiTranslator;
    QQmlEngine*                  m_qmlEngine = nullptr;
    DocumentPickerService* m_documentPicker = nullptr; // not owned
};
