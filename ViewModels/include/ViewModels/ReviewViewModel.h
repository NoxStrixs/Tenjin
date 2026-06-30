#pragma once

#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>

#include <QObject>
#include <QString>

#include <memory>
#include <optional>

class ReviewViewModel : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool active READ active NOTIFY sessionChanged)
    Q_PROPERTY(bool complete READ complete NOTIFY sessionChanged)
    Q_PROPERTY(int totalCards READ totalCards NOTIFY sessionChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY sessionChanged)
    Q_PROPERTY(qint64 currentWordId READ currentWordId NOTIFY sessionChanged)
    Q_PROPERTY(QString currentWord READ currentWord NOTIFY sessionChanged)
    // All definition blocks of the current word, joined — shown on the answer side.
    Q_PROPERTY(QString currentAnswer READ currentAnswer NOTIFY sessionChanged)
    // True when the current card has been flagged a leech (failed many times).
    // The review UI surfaces this so the user can give it extra attention.
    Q_PROPERTY(bool currentIsLeech READ currentIsLeech NOTIFY sessionChanged)
    Q_PROPERTY(bool showingAnswer READ showingAnswer NOTIFY showingAnswerChanged)

    // ── Session summary (per-session, reset on startSession) ────────────────
    // Counts grades submitted this session. "Correct" = quality >= 2 (Good/Easy),
    // matching the review grade buttons. Elapsed is wall-clock seconds since the
    // session started. These drive the post-session summary screen.
    Q_PROPERTY(int sessionCorrect READ sessionCorrect NOTIFY sessionChanged)
    Q_PROPERTY(int sessionIncorrect READ sessionIncorrect NOTIFY sessionChanged)
    Q_PROPERTY(int sessionElapsedSeconds READ sessionElapsedSeconds NOTIFY sessionChanged)
    Q_PROPERTY(double sessionAccuracy READ sessionAccuracy NOTIFY sessionChanged)

public:
    ReviewViewModel(std::shared_ptr<Service::DeckService>  deckService,
                    std::shared_ptr<Service::EntryService> wordService,
                    QObject*                               parent = nullptr);

    bool active() const
    {
        return m_session.has_value();
    }
    bool    complete() const;
    int     totalCards() const;
    int     currentIndex() const;
    qint64  currentWordId() const;
    bool    currentIsLeech() const;
    QString currentWord() const;
    QString currentAnswer() const;
    bool    showingAnswer() const
    {
        return m_showingAnswer;
    }

    int sessionCorrect() const
    {
        return m_sessionCorrect;
    }
    int sessionIncorrect() const
    {
        return m_sessionIncorrect;
    }
    int sessionElapsedSeconds() const;
    double sessionAccuracy() const
    {
        const int graded = m_sessionCorrect + m_sessionIncorrect;
        return graded > 0 ? static_cast<double>(m_sessionCorrect) / graded : 0.0;
    }

public slots:
    void startSession(qint64 deckId);
    void stopSession();
    void revealAnswer();
    void submitQuality(int quality);

signals:
    void sessionChanged();
    void showingAnswerChanged();
    void errorOccurred(const QString& msg);

private:
    std::shared_ptr<Service::DeckService>  m_deckService;
    std::shared_ptr<Service::EntryService> m_entryService;

    std::optional<Service::ReviewSession_t> m_session;
    bool                                    m_showingAnswer = false;

    // Per-session summary counters (reset in startSession).
    int     m_sessionCorrect   = 0;
    int     m_sessionIncorrect = 0;
    qint64  m_sessionStartMs   = 0;
};
