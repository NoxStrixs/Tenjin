#include <ViewModels/ReviewViewModel.h>
#include <WordService/WordService.h>

#include <QRegularExpression>
#include <QStringList>

ReviewViewModel::ReviewViewModel(std::shared_ptr<Service::DeckService> deckService,
                                 std::shared_ptr<Service::WordService> wordService,
                                 QObject*                              parent)
    : QObject(parent), m_deckService(std::move(deckService)), m_wordService(std::move(wordService))
{
}

bool ReviewViewModel::complete() const
{
    return !m_session || m_deckService->IsComplete(*m_session);
}

int ReviewViewModel::totalCards() const
{
    return m_session ? static_cast<int>(m_session->queue.size()) : 0;
}

int ReviewViewModel::currentIndex() const
{
    return m_session ? m_session->currentIndex : 0;
}

qint64 ReviewViewModel::currentWordId() const
{
    if (!m_session)
        return -1;
    auto card = m_deckService->CurrentCard(*m_session);
    return card ? card->wordId : -1;
}

QString ReviewViewModel::currentWord() const
{
    qint64 wid = currentWordId();
    if (wid < 0)
        return {};
    // Walk all words to resolve name — acceptable for small-to-moderate sets
    auto words = m_wordService->GetAllWords();
    if (!words)
        return {};
    for (const auto& w : *words)
        if (w.id == wid)
            return QString::fromStdString(w.word);
    return {};
}

QString ReviewViewModel::currentAnswer() const
{
    qint64 wid = currentWordId();
    if (wid < 0)
        return {};
    auto blocks = m_wordService->GetContentForWord(wid);
    if (!blocks)
        return {};

    // Collect definition bodies. Each block's content is a full rich-text
    // document (with <html>/<body> and a CSS preamble). Joining several whole
    // documents into one Text breaks rendering after the first, so we extract
    // just the body fragment of each and build one numbered list.
    QStringList items;
    for (const auto& b : *blocks) {
        if (b.type != Service::ContentType_t::Definition || b.content.empty())
            continue;
        QString html = QString::fromStdString(b.content);

        // Pull out the <body>…</body> inner fragment if present.
        const int bodyOpen = html.indexOf("<body", Qt::CaseInsensitive);
        if (bodyOpen >= 0) {
            const int gt        = html.indexOf('>', bodyOpen);
            const int bodyClose = html.indexOf("</body>", Qt::CaseInsensitive);
            if (gt >= 0 && bodyClose > gt)
                html = html.mid(gt + 1, bodyClose - gt - 1);
        }
        // Drop any leftover <style>…</style> blocks.
        html.remove(QRegularExpression("<style.*?</style>",
                                       QRegularExpression::CaseInsensitiveOption |
                                           QRegularExpression::DotMatchesEverythingOption));
        // Unwrap block-level <p>…</p> so the text sits inline inside <li>
        // (nested block elements inside a list item render inconsistently and
        // can swallow following items in Qt's rich-text engine).
        html.replace(QRegularExpression("</?p[^>]*>", QRegularExpression::CaseInsensitiveOption),
                     QString());
        // Collapse any HTML comments (e.g. fragment markers).
        html.remove(
            QRegularExpression("<!--.*?-->", QRegularExpression::DotMatchesEverythingOption));
        html = html.trimmed();
        if (!html.isEmpty()) {
            // Prefix the part of speech in italics, e.g. "(noun) …".
            if (!b.pos.empty())
                html = QStringLiteral("<i>(") + QString::fromStdString(b.pos) +
                       QStringLiteral(")</i> ") + html;
            items << html;
        }
    }

    if (items.isEmpty())
        return {};

    // Build: "Definitions:" header + a numbered list.
    QString out = QStringLiteral("<b>Definitions:</b><br><ol>");
    for (const auto& it : items)
        out += QStringLiteral("<li>") + it + QStringLiteral("</li>");
    out += QStringLiteral("</ol>");
    return out;
}

void ReviewViewModel::startSession(qint64 deckId)
{
    auto result = m_deckService->StartSession(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_session       = std::move(*result);
    m_showingAnswer = false;
    emit sessionChanged();
    emit showingAnswerChanged();
}

void ReviewViewModel::stopSession()
{
    m_session.reset();
    m_showingAnswer = false;
    emit sessionChanged();
    emit showingAnswerChanged();
}

void ReviewViewModel::revealAnswer()
{
    m_showingAnswer = true;
    emit showingAnswerChanged();
}

void ReviewViewModel::submitQuality(int quality)
{
    if (!m_session || complete())
        return;
    auto result = m_deckService->SubmitCard(*m_session, quality);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_showingAnswer = false;
    emit sessionChanged();
    emit showingAnswerChanged();
}
