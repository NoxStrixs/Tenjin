# Tenjin Roadmap & Backlog

Status: 🔴 not started · 🟡 partial/stubbed · 🟢 done

## Blocking
- 🔴 **Real build verification.** All changes through v6 are validated only for
  syntax balance, never compiled. Configure + build on a Qt 6.8 toolchain (or
  via CI) and fix what surfaces before further feature work.

## Notifications & reminders
- 🟡 **Local push notifications / review reminders.** Daily review reminder
  is now user-configurable (Settings ▸ Reminders: toggle + time), persisted,
  and scheduled via a self-rearming QTimer. Still needs the native delivery
  backend for BACKGROUND firing (QTimer only fires while the app runs):
    - iOS: `UNUserNotificationCenter` (request authorization, schedule
      `UNTimeIntervalNotificationTrigger`), declared in entitlements.
    - Android: `POST_NOTIFICATIONS` runtime permission (already in the
      manifest) + a notification channel + `AlarmManager`/`WorkManager` for
      scheduled delivery so reminders fire when the app is closed.
    - Settings UI: per-deck or global "remind me when cards are due" toggle,
      time-of-day picker, and a permission-request flow on first enable.
- 🔴 **Email reminders.** Scheduled email digests ("you have N cards due").
  Requires the cloud backend — the client cannot send email directly. Design:
    - User opts in and supplies/confirms an email in Settings.
    - Client registers a reminder schedule with the server (`POST /api/v1/reminders`).
    - Server sends the digest on schedule. Depends on the cloud endpoint
      (`TENJIN_CLOUD_URL`) being live and an email provider (e.g. Postmark/SES).
    - Must include an unsubscribe link and respect store privacy rules
      (declare email collection in the iOS privacy manifest + Play data safety).

## Features
- 🟢 **Study statistics dashboard.** Global stats page (streak, retention,
  due forecast, heatmap) via `GetGlobalStats`. Reachable from header / drawer /
  Ctrl+4. See FEATURES.md.
- 🟡 **Anki media import.** Text-field import done; `AnkiNote::mediaRefs` is
  populated. Remaining: extract numbered media files, map via the package's
  `media` JSON manifest, copy into the app media folder, rewrite
  `[sound:]`/`<img>` references.
- 🔴 **Home-screen widget.** "N cards due today." Native per platform
  (WidgetKit on iOS, Glance/RemoteViews on Android). Largest effort, least
  shared code.
- 🟡 **Cloud sync.** `CloudService` stubbed; sync button shows "Coming soon".
  Needs the backend + an offline-first sync protocol + subscription handling.
- 🔴 **Text-to-speech / audio pronunciation.** Low priority. Play audio for a
  word (TTS or attached audio block) during review.

## Polish (lower risk, self-contained)
- 🟢 Empty-state CTAs, What's-new sheet, iPad wide layout, icon font.
- 🔴 Loading skeletons wired to a real async source (currently the DB is
  synchronous; `SkeletonItem` is ready for the cloud path).
- 🔴 App Store review-prompt (`SKStoreReviewRequest`) at a natural moment
  (e.g. after a completed review streak).

## Testing & infra
- 🟡 Unit tests exist for Anki import + DB round-trip behind `TENJIN_BUILD_TESTS`,
  run in CI. Expand coverage as features land (review scheduling, search, decks).
