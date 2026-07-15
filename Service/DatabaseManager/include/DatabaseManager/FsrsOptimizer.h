#pragma once

#include <DatabaseManager/Fsrs.h>

#include <array>
#include <cmath>
#include <cstdint>
#include <vector>

// FSRS weight optimizer. Fits the 19 FSRS-5 weights to a user's actual review
// history by minimizing log-loss (binary cross-entropy) between the model's
// predicted recall probability and the observed pass/fail at each review.
//
// Derivative-free: coordinate descent with a shrinking step per weight. No ML
// library, no gradients — self-contained and unit-testable like Fsrs.h. This
// won't match the reference PyTorch optimizer's last decimal, but reliably
// improves on the default weights when a deck has enough history.
namespace Fsrs {

// One logged review of one card, in chronological order within a card's
// sequence. `elapsedDays` is days since that card's previous review (0 for the
// first). `grade` is FSRS 1..4. `passed` is grade >= 2.
struct ReviewEvent {
    double elapsedDays = 0.0;
    int    grade       = 3;
    bool   passed      = true;
};

// A single card's full review history, oldest first.
using CardHistory = std::vector<ReviewEvent>;

struct OptimizeResult {
    std::array<double, 19> weights     = kDefaultWeights;
    double                 initialLoss = 0.0;   // log-loss with default weights
    double                 finalLoss   = 0.0;   // log-loss with fitted weights
    int                    reviewCount = 0;     // total events considered
    bool                   optimized   = false; // false if below the min-review guard
};

namespace detail {

// Clamp a probability away from 0/1 so log() is finite.
inline double clampProb(double p)
{
    constexpr double eps = 1e-6;
    return (std::min)(1.0 - eps, (std::max)(eps, p));
}

// Compute mean log-loss of the given weights over all card histories. For each
// review we predict retrievability from the running memory state (using the
// SAME schedule() math the scheduler uses) and score it against pass/fail.
inline double logLoss(const std::array<double, 19>& w, const std::vector<CardHistory>& data)
{
    Params p;
    p.w = w;

    double totalLoss = 0.0;
    long   count     = 0;

    for (const CardHistory& hist : data) {
        State st{}; // stability 0 => new card
        for (const ReviewEvent& ev : hist) {
            if (st.stability > 0.0) {
                // Predict recall probability BEFORE seeing the outcome.
                const double r = clampProb(retrievability(ev.elapsedDays, st.stability));
                const double y = ev.passed ? 1.0 : 0.0;
                totalLoss += -(y * std::log(r) + (1.0 - y) * std::log(1.0 - r));
                ++count;
            }
            // Advance the memory state with the actual grade.
            const Schedule s = schedule(p, st, ev.elapsedDays, ev.grade);
            st               = s.state;
        }
    }
    return count > 0 ? totalLoss / static_cast<double>(count) : 0.0;
}

} // namespace detail

// Fit weights to `data`. Decks with fewer than `minReviews` scored events keep
// the default weights (returns optimized=false) — fitting on too little history
// overfits and can be worse than defaults.
inline OptimizeResult optimize(const std::vector<CardHistory>& data, int minReviews = 400)
{
    OptimizeResult out;

    // Count scored events (those with a prior state, i.e. not a card's first).
    int scored = 0;
    for (const CardHistory& h : data)
        scored += h.empty() ? 0 : static_cast<int>(h.size()) - 1;
    out.reviewCount = scored;

    out.initialLoss = detail::logLoss(kDefaultWeights, data);
    out.finalLoss   = out.initialLoss;
    out.weights     = kDefaultWeights;

    if (scored < minReviews)
        return out; // guard: not enough history, keep defaults

    // Coordinate descent: for each weight, try +/- step; keep improvements.
    // Shrink the step and repeat. Bounds keep weights physically sensible.
    std::array<double, 19> w        = kDefaultWeights;
    double                 bestLoss = out.initialLoss;

    // Per-weight lower/upper bounds (loose but prevent degenerate values).
    constexpr std::array<double, 19> lo = {0.01,
                                           0.01,
                                           0.01,
                                           0.01,
                                           1.0,
                                           0.001,
                                           0.001,
                                           0.0,
                                           0.0,
                                           0.0,
                                           0.01,
                                           0.01,
                                           0.001,
                                           0.001,
                                           0.01,
                                           0.0,
                                           1.0,
                                           0.0,
                                           0.0};
    constexpr std::array<double, 19> hi = {100.0,
                                           100.0,
                                           100.0,
                                           100.0,
                                           10.0,
                                           4.0,
                                           4.0,
                                           0.75,
                                           4.5,
                                           0.8,
                                           3.5,
                                           5.0,
                                           0.25,
                                           0.9,
                                           4.0,
                                           1.0,
                                           6.0,
                                           2.0,
                                           2.0};

    double step = 0.5;
    for (int iter = 0; iter < 60 && step > 1e-3; ++iter) {
        bool improved = false;
        for (size_t i = 0; i < w.size(); ++i) {
            const double original = w[i];
            const double span     = hi[i] - lo[i];
            const double delta    = step * span * 0.1;

            for (const double cand : {original + delta, original - delta}) {
                const double clamped = (std::min)(hi[i], (std::max)(lo[i], cand));
                if (clamped == original)
                    continue;
                w[i]              = clamped;
                const double loss = detail::logLoss(w, data);
                if (loss < bestLoss) {
                    bestLoss = loss;
                    improved = true;
                    break; // keep this improvement, move to next weight
                }
                w[i] = original; // revert
            }
        }
        if (!improved)
            step *= 0.5; // no coordinate improved -> refine the step
    }

    out.weights   = w;
    out.finalLoss = bestLoss;
    out.optimized = bestLoss < out.initialLoss;
    return out;
}

} // namespace Fsrs
