#include <EntryService/EntryService.h>
#include <ViewModels/ReviewViewModel.h>

#include <QDateTime>
#include <QRegularExpression>
#include <QStringList>

ReviewViewModel::ReviewViewModel(std::shared_ptr<Service::DeckService>  deckService,
                                 std::shared_ptr<Service::EntryService> wordService,
                                 QObject*                               parent)
    : QObject(parent), m_deckService(std::move(deckService)), m_entryService(std::move(wordService))
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

bool ReviewViewModel::currentIsLeech() const
{
    if (!m_session)
        return false;
    auto card = m_deckService->CurrentCard(*m_session);
    return card ? card->isLeech : false;
}

QString ReviewViewModel::currentWord() const
{
    qint64 wid = currentWordId();
    if (wid < 0)
        return {};
    // Walk all words to resolve name
    auto words = m_entryService->GetAllEntries();
    if (!words)
        return {};
    for (const auto& w : *words)
        if (w.id == wid)
            return QString::fromStdString(w.word);
    return {};
}

QString ReviewViewModel::currentClozeText() const
{
    const qint64 wid = currentWordId();
    if (wid < 0)
        return {};
    auto blocks = m_entryService->GetContentForEntry(wid);
    if (!blocks)
        return {};
    for (const auto& b : *blocks) {
        if (b.type == Service::ContentType_t::Cloze && !b.content.empty())
            return QString::fromStdString(b.content);
    }
    return {};
}

bool ReviewViewModel::currentHasCloze() const
{
    return !currentClozeText().isEmpty();
}

int ReviewViewModel::currentClozeOrdinal() const
{
    if (!m_session || m_session->queue.empty())
        return 0;
    const int idx = m_session->currentIndex;
    if (idx < 0 || idx >= static_cast<int>(m_session->queue.size()))
        return 0;
    return m_session->queue[static_cast<size_t>(idx)].clozeOrdinal;
}

QString ReviewViewModel::currentAnswer() const
{
    qint64 wid = currentWordId();
    if (wid < 0)
        return {};
    auto blocks = m_entryService->GetContentForEntry(wid);
    if (!blocks)
        return {};

    // Collect definition bodies.
    // We extract just the body fragment of each and build one numbered list.
    QStringList items;
    for (const auto& b : *blocks) {
        if (b.type != Service::ContentType_t::Definition || b.content.empty())
            continue;
        QString html = QString::fromStdString(b.content);

        // Pull out the <body>…</body> inner fragment if present.
        const qsizetype bodyOpen = html.indexOf("<body", Qt::CaseInsensitive);
        if (bodyOpen >= 0) {
            const qsizetype gt        = html.indexOf('>', bodyOpen);
            const qsizetype bodyClose = html.indexOf("</body>", Qt::CaseInsensitive);
            if (gt >= 0 && bodyClose > gt)
                html = html.mid(gt + 1, bodyClose - gt - 1);
        }
        // Drop any leftover <style>…</style> blocks.
        html.remove(QRegularExpression("<style.*?</style>",
                                       QRegularExpression::CaseInsensitiveOption |
                                           QRegularExpression::DotMatchesEverythingOption));
        // Unwrap block-level <p>…</p> so the text sits inline inside <li>
        html.replace(QRegularExpression("</?p[^>]*>", QRegularExpression::CaseInsensitiveOption),
                     QString());
        // Collapse any HTML comments
        html.remove(
            QRegularExpression("<!--.*?-->", QRegularExpression::DotMatchesEverythingOption));
        html = html.trimmed();
        if (!html.isEmpty()) {
            // Prefix the part of speech in italics
            if (!b.pos.empty())
                html = QStringLiteral("<i>(") + QString::fromStdString(b.pos) +
                       QStringLiteral(")</i> ") + html;
            items << html;
        }
    }

    if (items.isEmpty())
        return {};

    // Build: "Definitions:" header and a numbered list.
    QString out = QStringLiteral("<b>Definitions:</b><br><ol>");
    for (const auto& it : items)
        out += QStringLiteral("<li>") + it + QStringLiteral("</li>");
    out += QStringLiteral("</ol>");
    return out;
}

void ReviewViewModel::startFilteredSession(int mode, const QVariantList& tagIds,
                                           const QString& language, qint64 deckId,
                                           int aheadDays, int limit)
{
    Service::StudyFilter_t filter;
    filter.mode      = static_cast<Service::StudyMode_t>(mode);
    filter.language  = language.toStdString();
    filter.deckId    = deckId;
    filter.aheadDays = aheadDays > 0 ? aheadDays : 3;
    filter.limit     = limit > 0 ? limit : 100;
    for (const QVariant& v : tagIds)
        filter.tagIds.push_back(v.toLongLong());

    auto result = m_deckService->StartFilteredSession(filter);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_session          = std::move(*result);
    m_showingAnswer    = false;
    m_sessionCorrect   = 0;
    m_sessionIncorrect = 0;
    m_sessionStartMs   = QDateTime::currentMSecsSinceEpoch();
    emit sessionChanged();
    emit showingAnswerChanged();
}

namespace {

// Normalize for forgiving comparison: NFD-decompose, drop combining marks
// (accents), casefold, and strip surrounding whitespace/punctuation. "Café" and
// "cafe " both become "cafe".
QString normalizeAnswer(const QString& in)
{
    QString s = in.normalized(QString::NormalizationForm_D);
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c.category() == QChar::Mark_NonSpacing) continue; // combining accents
        if (c.isLetterOrNumber() || c.isSpace()) out.append(c.toCaseFolded());
        // punctuation dropped
    }
    return out.simplified(); // collapse internal whitespace + trim
}

} // namespace

QString ReviewViewModel::normalizedWord() const
{
    return normalizeAnswer(currentWord());
}

bool ReviewViewModel::checkTypedAnswer(const QString& typed) const
{
    const QString a = normalizeAnswer(typed);
    const QString b = normalizeAnswer(currentWord());
    return !b.isEmpty() && a == b;
}

void ReviewViewModel::startSession(qint64 deckId)
{
    auto result = m_deckService->StartSession(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_session          = std::move(*result);
    m_showingAnswer    = false;
    m_sessionCorrect   = 0;
    m_sessionIncorrect = 0;
    m_sessionStartMs   = QDateTime::currentMSecsSinceEpoch();
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
    // Track session accuracy. Quality >= 2 (Good/Easy) counts as correct,
    // matching the review grade buttons (0 Forgot, 1 Hard, 2 Good, 3 Easy).
    if (quality >= 2)
        ++m_sessionCorrect;
    else
        ++m_sessionIncorrect;
    m_showingAnswer = false;
    emit sessionChanged();
    emit showingAnswerChanged();
}

int ReviewViewModel::sessionElapsedSeconds() const
{
    if (m_sessionStartMs == 0)
        return 0;
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    return static_cast<int>((nowMs - m_sessionStartMs) / 1000);
}
