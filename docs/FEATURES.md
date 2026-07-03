# Tenjin Features & Architecture

A reference for how the major features are wired, layer by layer. The codebase
follows strict separation: C++ does data/logic, QML does presentation only.

## Layers
```
QML (View/)            presentation, interaction
  ↓ context properties + Q_INVOKABLE
ViewModels/            Qt models, QVariant marshalling, no SQL
  ↓ shared_ptr services
Service/               EntryService, DeckService — thin pass-through
  ↓
DatabaseManager/       all SQL, schema, migrations
```

## Statistics dashboard
- **Data:** `DatabaseManager::GetGlobalStats()` aggregates `review_log` and
  `review` across every deck into `GlobalStats_t` — daily counts, retention,
  due-today / due-7-day forecast, current and longest streaks, words, reviews
  today.
- **Flow:** `GetGlobalStats` → `DeckService::GetGlobalStats` →
  `DeckViewModel::globalStats()` (returns a `QVariantMap`) → `StatsPage.qml`.
- **UI:** `StatsPage` (nav page 6) shows a headline metric strip and reuses the
  existing `AnalyticsPanel` in `embedded: true` mode (reports `implicitHeight`,
  no internal scroll) for charts and the activity heatmap.
- **Entry points:** header sparkle icon, mobile drawer, `Ctrl/Cmd+4`.

## Reminders (local push)
- **Settings:** `NotificationService` exposes `reminderEnabled`,
  `reminderHour`, `reminderMinute` (persisted via QSettings), plus
  `setReminderBody()` for the dynamic due-count message.
- **Scheduling:** a single-shot `QTimer` re-arms itself each day at the chosen
  time (`rescheduleDaily` / `nextDailyEpochMs`). On fire it calls
  `deliverLocalPush`.
- **Delivery:** the default `deliverLocalPush` surfaces an in-app toast. iOS and
  Android native translation units should override it (and `requestPermission`)
  to post a real OS notification that fires while backgrounded — see ROADMAP.
- **UI:** Settings ▸ Reminders — a toggle + hour/minute spinners.
- **Limitation:** because delivery is currently a `QTimer`, reminders only fire
  while the app is running. The native backends (UNUserNotificationCenter /
  AlarmManager) are required for background delivery and are tracked in ROADMAP.

## Anki import (from v6)
- `AnkiImporter::ParseApkg` (miniz + Qt SQL) → `DatabaseManager::ImportFromAnki`
  → `EntryService` → `AppViewModel::importAnki` → import pickers.
- Text fields only for now; `AnkiNote::mediaRefs` is populated for a future
  media pass.

## Notifications, cloud, haptics
- `NotificationService` — toasts, alerts, ad-hoc + daily reminders.
- `CloudService` — news, bug reports, sync (stubbed; single endpoint).
- `HapticsService` — no-op default with a platform hook.

## Icons & theming
- `TenjinIcons` singleton maps every glyph to Material Symbols (bundled at
  `qrc:/tenjin/fonts/`). Never set `font.bold` on an icon Text — the variable
  font has no bold axis and DirectWrite spams warnings.
- `Platform` singleton holds all color/spacing tokens and `useWideLayout`
  (width-aware desktop/mobile switch for iPad split-view).
