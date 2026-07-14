#include <QtConcurrent>
#include <QFutureWatcher>
#include <DeckService/DeckService.h>
#include <EntryService/EntryService.h>
#include <ViewModels/DeckViewModel.h>

DeckViewModel::DeckViewModel(std::shared_ptr<Service::DeckService>  deckService,
                             std::shared_ptr<Service::EntryService> wordService,
                             QObject*                               parent)
    : QObject(parent), m_deckService(std::move(deckService)),
      m_entryService(std::move(wordService)), m_deckModel(std::make_unique<DeckListModel>(this))
{
    reloadDecks();
}

void DeckViewModel::reloadDecks()
{
    auto result = m_deckService->GetAllDecks();
    if (result)
        m_deckModel->setDecks(*result);
    else
        emit errorOccurred(QString::fromStdString(result.error()));
}

void DeckViewModel::selectDeck(qint64 deckId)
{
    auto result = m_deckService->GetDeck(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_selectedDeckId      = deckId;
    m_selectedDeckName    = QString::fromStdString(result->name);
    m_selectedDeckIsSmart = result->bIsSmart;
    emit selectedDeckChanged();
    reloadDeckWords();
    reloadTagFilters();
}

void DeckViewModel::clearSelection()
{
    m_selectedDeckId = -1;
    m_selectedDeckName.clear();
    m_selectedDeckIsSmart = false;
    m_deckWords.clear();
    m_tagFilters.clear();
    emit selectedDeckChanged();
    emit deckWordsChanged();
    emit tagFiltersChanged();
}

bool DeckViewModel::createDeck(const QString& name, bool isSmart, int filterMode)
{
    auto mode   = (filterMode == 1) ? Service::FilterMode_t::Or : Service::FilterMode_t::And;
    auto result = m_deckService->CreateDeck(name.toStdString(), isSmart, mode);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadDecks();
    return true;
}

bool DeckViewModel::createSmartDeck(const QString& name, int filterMode, const QVariantList& tagIds)
{
    auto mode   = (filterMode == 1) ? Service::FilterMode_t::Or : Service::FilterMode_t::And;
    auto result = m_deckService->CreateDeck(name.toStdString(), /*isSmart=*/true, mode);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    const Service::ID_t deckId = result->id;
    for (const QVariant& v : tagIds) {
        const qint64 tagId = v.toLongLong();
        auto         link  = m_deckService->AddTagFilter(deckId, tagId);
        if (!link)
            emit errorOccurred(QString::fromStdString(link.error()));
    }
    reloadDecks();
    return true;
}

QVariantMap DeckViewModel::deckStats(qint64 deckId)
{
    QVariantMap out;
    auto        result = m_deckService->GetDeckStats(deckId);
    if (!result) {
        out["total"]   = 0;
        out["due"]     = 0;
        out["nextDue"] = QString();
        return out;
    }
    out["total"]   = result->total;
    out["due"]     = result->due;
    out["nextDue"] = QString::fromStdString(result->nextDue);
    // Scheduler settings for the deck settings UI.
    if (auto deck = m_deckService->GetDeck(deckId)) {
        out["scheduler"]     = QString::fromStdString(deck->scheduler);
        out["fsrsRetention"] = deck->fsrsRetention;
    } else {
        out["scheduler"]     = QStringLiteral("sm2");
        out["fsrsRetention"] = 0.9;
    }
    return out;
}

QVariantMap DeckViewModel::globalStats()
{
    QVariantMap out;
    auto        result = m_deckService->GetGlobalStats();
    if (!result) {
        out["totalReviews"]      = 0;
        out["totalWords"]        = 0;
        out["dueToday"]          = 0;
        out["dueNext7Days"]      = 0;
        out["retention"]         = 0.0;
        out["currentStreakDays"] = 0;
        out["longestStreakDays"] = 0;
        out["reviewsToday"]      = 0;
        out["leechCount"]        = 0;
        out["daily"]             = QVariantList{};
        return out;
    }
    out["totalReviews"]      = result->totalReviews;
    out["totalWords"]        = result->totalWords;
    out["dueToday"]          = result->dueToday;
    out["dueNext7Days"]      = result->dueNext7Days;
    out["retention"]         = result->retention;
    out["currentStreakDays"] = result->currentStreakDays;
    out["longestStreakDays"] = result->longestStreakDays;
    out["reviewsToday"]      = result->reviewsToday;
    out["leechCount"]        = result->leechCount;
    out["firstReviewDate"]   = QString::fromStdString(result->firstReviewDate);
    QVariantList daily;
    for (const auto& d : result->daily) {
        QVariantMap m;
        m["date"]       = QString::fromStdString(d.date);
        m["count"]      = d.count;
        m["avgQuality"] = d.avgQuality;
        daily.append(m);
    }
    out["daily"] = daily;
    return out;
}

QVariantMap DeckViewModel::deckAnalytics(qint64 deckId)
{
    QVariantMap out;
    auto        result = m_deckService->GetDeckAnalytics(deckId);
    if (!result) {
        out["totalReviews"] = 0;
        out["retention"]    = 0.0;
        out["daily"]        = QVariantList{};
        return out;
    }
    out["totalReviews"] = result->totalReviews;
    out["retention"]    = result->retention;
    QVariantList daily;
    for (const auto& d : result->daily) {
        QVariantMap m;
        m["date"]       = QString::fromStdString(d.date);
        m["count"]      = d.count;
        m["avgQuality"] = d.avgQuality;
        daily.append(m);
    }
    out["daily"] = daily;
    return out;
}

QVariantList DeckViewModel::wordHistory(qint64 deckId, qint64 wordId)
{
    QVariantList out;
    auto         result = m_deckService->GetEntryHistory(deckId, wordId);
    if (!result)
        return out;
    for (const auto& e : *result) {
        QVariantMap m;
        m["reviewedAt"]   = QVariant::fromValue(e.reviewedAt);
        m["quality"]      = e.quality;
        m["easeFactor"]   = e.easeFactor;
        m["intervalDays"] = e.intervalDays;
        out.append(m);
    }
    return out;
}

bool DeckViewModel::deleteDeck(qint64 deckId)
{
    auto result = m_deckService->DeleteDeck(deckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        clearSelection();
    reloadDecks();
    return true;
}

bool DeckViewModel::setNewCardsPerDay(qint64 deckId, int perDay)
{
    auto result = m_deckService->SetNewCardsPerDay(static_cast<Service::ID_t>(deckId), perDay);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadDecks();
    return true;
}

bool DeckViewModel::setScheduler(qint64 deckId, const QString& scheduler, double retention)
{
    auto result = m_deckService->SetScheduler(static_cast<Service::ID_t>(deckId),
                                              scheduler.toStdString(), retention);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    reloadDecks();
    return true;
}

void DeckViewModel::optimizeDeck(qint64 deckId)
{
    emit optimizeStarted();

    // QSqlDatabase connections are bound to the thread that created them, so all
    // DB access stays on this (main) thread: read the review sequences here,
    // run ONLY the pure CPU-bound fit on a worker, then persist on completion
    // back on this thread.
    auto sequences = m_deckService->GetReviewSequencesFor(static_cast<Service::ID_t>(deckId));
    if (!sequences) {
        emit optimizeFinished(false, QString::fromStdString(sequences.error()));
        return;
    }

    auto* watcher = new QFutureWatcher<Fsrs::OptimizeResult>(this);
    connect(watcher, &QFutureWatcher<Fsrs::OptimizeResult>::finished, this,
            [this, watcher, deckId]() {
                const Fsrs::OptimizeResult r = watcher->result();
                QString msg;
                bool ok = r.optimized;
                if (!r.optimized) {
                    msg = tr("Not enough review history yet to optimize "
                             "(need ~400 reviews). Keeping default weights.");
                } else {
                    // Persist the fitted weights (main thread).
                    auto saved = m_deckService->SaveDeckWeights(
                        static_cast<Service::ID_t>(deckId), r.weights);
                    if (!saved) {
                        ok = false;
                        msg = QString::fromStdString(saved.error());
                    } else {
                        const double pct = r.initialLoss > 0.0
                            ? 100.0 * (r.initialLoss - r.finalLoss) / r.initialLoss
                            : 0.0;
                        msg = tr("Optimized from %1 reviews — prediction error down %2%.")
                                  .arg(r.reviewCount)
                                  .arg(QString::number(pct, 'f', 1));
                    }
                }
                emit optimizeFinished(ok, msg);
                if (ok)
                    reloadDecks();
                watcher->deleteLater();
            });

    // Move the sequences into the worker; only pure computation runs there.
    auto data = std::make_shared<std::vector<Fsrs::CardHistory>>(std::move(*sequences));
    watcher->setFuture(QtConcurrent::run([data]() {
        return Fsrs::optimize(*data);
    }));
}

bool DeckViewModel::addWordToDeck(qint64 deckId, qint64 wordId)
{
    auto result = m_deckService->AddEntryToDeck(deckId, wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        reloadDeckWords();
    return true;
}

bool DeckViewModel::removeWordFromDeck(qint64 deckId, qint64 wordId)
{
    auto result = m_deckService->RemoveEntryFromDeck(deckId, wordId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId)
        reloadDeckWords();
    return true;
}

bool DeckViewModel::addTagFilter(qint64 deckId, qint64 tagId)
{
    auto result = m_deckService->AddTagFilter(deckId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId) {
        reloadTagFilters();
        reloadDeckWords();
    }
    return true;
}

bool DeckViewModel::removeTagFilter(qint64 deckId, qint64 tagId)
{
    auto result = m_deckService->RemoveTagFilter(deckId, tagId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return false;
    }
    if (m_selectedDeckId == deckId) {
        reloadTagFilters();
        reloadDeckWords();
    }
    return true;
}

void DeckViewModel::reloadTagFilters()
{
    if (m_selectedDeckId < 0)
        return;
    auto result = m_deckService->GetTagFilters(m_selectedDeckId);
    if (!result)
        return;
    m_tagFilters.clear();
    for (const auto& t : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(t.id);
        m["name"] = QString::fromStdString(t.name);
        m_tagFilters.append(m);
    }
    emit tagFiltersChanged();
}

QVariantList DeckViewModel::allWords()
{
    auto result = m_entryService->GetAllEntries();
    if (!result)
        return {};
    QVariantList out;
    for (const auto& w : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(w.id);
        m["word"] = QString::fromStdString(w.word);
        out.append(m);
    }
    return out;
}

QVariantList DeckViewModel::allTags()
{
    auto result = m_entryService->GetAllTags();
    if (!result)
        return {};
    QVariantList out;
    for (const auto& t : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(t.id);
        m["name"] = QString::fromStdString(t.name);
        out.append(m);
    }
    return out;
}

void DeckViewModel::reloadDeckWords()
{
    if (m_selectedDeckId < 0)
        return;
    auto result = m_deckService->GetEntriesForDeck(m_selectedDeckId);
    if (!result) {
        emit errorOccurred(QString::fromStdString(result.error()));
        return;
    }
    m_deckWords.clear();
    for (const auto& w : *result) {
        QVariantMap m;
        m["id"]   = QVariant::fromValue(w.id);
        m["word"] = QString::fromStdString(w.word);
        m_deckWords.append(m);
    }
    emit deckWordsChanged();
}
