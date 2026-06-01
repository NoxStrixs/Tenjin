#pragma once

#include <DeckService/DeckService.h>
#include <WordService/WordService.h>

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
    Q_PROPERTY(bool showingAnswer READ showingAnswer NOTIFY showingAnswerChanged)

public:
    ReviewViewModel(std::shared_ptr<Service::DeckService> deckService,
                    std::shared_ptr<Service::WordService> wordService,
                    QObject*                              parent = nullptr);

    bool active() const
    {
        return m_session.has_value();
    }
    bool    complete() const;
    int     totalCards() const;
    int     currentIndex() const;
    qint64  currentWordId() const;
    QString currentWord() const;
    QString currentAnswer() const;
    bool    showingAnswer() const
    {
        return m_showingAnswer;
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
    std::shared_ptr<Service::DeckService> m_deckService;
    std::shared_ptr<Service::WordService> m_wordService;

    std::optional<Service::ReviewSession_t> m_session;
    bool                                    m_showingAnswer = false;
};
