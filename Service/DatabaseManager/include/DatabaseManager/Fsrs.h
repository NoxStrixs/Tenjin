#pragma once

#include <algorithm>
#include <array>
#include <cmath>

// FSRS-5 (Free Spaced Repetition Scheduler) — a pure implementation of the
// memory model that computes, from a card's current memory state and a grade,
// the next stability/difficulty and the interval to schedule.
//
// This is intentionally dependency-free (no Qt, no DB) so it can be unit-tested
// in isolation. DatabaseManager owns the persistence; this owns only the math.
//
// Grades follow FSRS convention: 1 = Again, 2 = Hard, 3 = Good, 4 = Easy.
// (Tenjin's 0..3 UI grades are mapped to 1..4 by the caller.)
namespace Fsrs {

// The 19 default parameters (weights) for FSRS-5, as published by the FSRS
// project. These schedule with sensible defaults; a future optimizer can fit
// per-user weights from review history and replace these.
inline constexpr std::array<double, 19> kDefaultWeights = {0.40255,
                                                           1.18385,
                                                           3.173,
                                                           15.69105,
                                                           7.1949,
                                                           0.5345,
                                                           1.4604,
                                                           0.0046,
                                                           1.54575,
                                                           0.1192,
                                                           1.01925,
                                                           1.9395,
                                                           0.11,
                                                           0.29605,
                                                           2.2698,
                                                           0.2315,
                                                           2.9898,
                                                           0.51655,
                                                           0.6621};

// Memory state of a card. New cards have stability == 0 (uninitialized).
struct State {
    double stability  = 0.0; // days; expected interval at target retention
    double difficulty = 0.0; // 1..10
};

struct Params {
    std::array<double, 19> w                = kDefaultWeights;
    double                 requestRetention = 0.90;    // desired probability of recall at review
    double                 maximumInterval  = 36500.0; // cap (days) ~ 100 years
};

// Clamp difficulty to the valid 1..10 range.
inline double clampDifficulty(double d)
{
    return std::clamp(d, 1.0, 10.0);
}

// Initial stability for a brand-new card given the first grade (w0..w3).
inline double initialStability(const Params& p, int grade)
{
    const int g = std::clamp(grade, 1, 4);
    return (std::max)(0.1, p.w[static_cast<size_t>(g - 1)]);
}

// Initial difficulty for a new card given the first grade.
inline double initialDifficulty(const Params& p, int grade)
{
    const int g = std::clamp(grade, 1, 4);
    // D0(g) = w4 - e^{w5 * (g - 1)} + 1   (FSRS-5)
    const double d = p.w[4] - std::exp(p.w[5] * (g - 1)) + 1.0;
    return clampDifficulty(d);
}

// Interval (days) that yields `requestRetention` recall probability for the
// given stability. FSRS-5 forgetting curve: R(t) = (1 + FACTOR * t/S)^DECAY.
inline int intervalForStability(const Params& p, double stability)
{
    constexpr double kDecay  = -0.5;
    const double     kFactor = std::pow(0.9, 1.0 / kDecay) - 1.0;
    double interval = (stability / kFactor) * (std::pow(p.requestRetention, 1.0 / kDecay) - 1.0);
    interval        = std::clamp(interval, 1.0, p.maximumInterval);
    return static_cast<int>(std::round(interval));
}

// Retrievability at elapsed days t for stability S (probability of recall now).
inline double retrievability(double elapsedDays, double stability)
{
    if (stability <= 0.0)
        return 0.0;
    constexpr double kDecay  = -0.5;
    const double     kFactor = std::pow(0.9, 1.0 / kDecay) - 1.0;
    return std::pow(1.0 + kFactor * elapsedDays / stability, kDecay);
}

// Next difficulty after a review (mean-reversion toward an easy anchor).
inline double nextDifficulty(const Params& p, double difficulty, int grade)
{
    const int g = std::clamp(grade, 1, 4);
    // Linear damping delta then mean-reversion to D0(Easy=4).
    const double deltaD   = -p.w[6] * (g - 3);
    const double dPrime   = difficulty + deltaD * ((10.0 - difficulty) / 9.0);
    const double d0Easy   = p.w[4] - std::exp(p.w[5] * (4 - 1)) + 1.0;
    const double reverted = p.w[7] * d0Easy + (1.0 - p.w[7]) * dPrime;
    return clampDifficulty(reverted);
}

// Stability after a successful recall (grade >= 2).
inline double
nextStabilityRecall(const Params& p, double difficulty, double stability, double retr, int grade)
{
    const double hardPenalty = (grade == 2) ? p.w[15] : 1.0;
    const double easyBonus   = (grade == 4) ? p.w[16] : 1.0;
    const double inc = std::exp(p.w[8]) * (11.0 - difficulty) * std::pow(stability, -p.w[9]) *
                       (std::exp(p.w[10] * (1.0 - retr)) - 1.0) * hardPenalty * easyBonus;
    return stability * (1.0 + inc);
}

// Stability after a lapse (grade == 1 Again) — the post-lapse stability.
inline double nextStabilityForget(const Params& p, double difficulty, double stability, double retr)
{
    const double sMin = p.w[11] * std::pow(difficulty, -p.w[12]) *
                        (std::pow(stability + 1.0, p.w[13]) - 1.0) *
                        std::exp(p.w[14] * (1.0 - retr));
    // Post-lapse stability is capped at the pre-lapse value.
    return (std::min)(sMin, stability);
}

// Result of scheduling: the new state and the interval (days) to next review.
struct Schedule {
    State state;
    int   intervalDays = 1;
    bool  lapsed       = false; // true when grade was Again
};

// Schedule a review. `elapsedDays` is days since the last review (0 for a
// brand-new card). `grade` is 1..4. Returns the updated memory state and the
// interval to the next review.
inline Schedule schedule(const Params& p, const State& current, double elapsedDays, int grade)
{
    const int g = std::clamp(grade, 1, 4);
    Schedule  out;

    if (current.stability <= 0.0) {
        // Brand-new card: seed from the first grade.
        out.state.stability  = initialStability(p, g);
        out.state.difficulty = initialDifficulty(p, g);
        out.lapsed           = (g == 1);
        out.intervalDays     = intervalForStability(p, out.state.stability);
        return out;
    }

    const double retr    = retrievability(elapsedDays, current.stability);
    out.state.difficulty = nextDifficulty(p, current.difficulty, g);

    if (g == 1) {
        out.state.stability = nextStabilityForget(p, current.difficulty, current.stability, retr);
        out.lapsed          = true;
    } else {
        out.state.stability =
            nextStabilityRecall(p, current.difficulty, current.stability, retr, g);
    }

    out.state.stability = (std::max)(0.1, out.state.stability);
    out.intervalDays    = intervalForStability(p, out.state.stability);
    return out;
}

} // namespace Fsrs
