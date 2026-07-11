# Tenjin — Audit Roadmap (Platform Standards, Features, Legal)

Compiled 2026-07-06 from the platform-standards review (Apple / Google / Microsoft)
and the feature-parity + legal-compliance audit. Ordered by risk, then value.
Companion documents: `ROADMAP.md` (product), `SUBMISSION_CHECKLIST.md` (stores).

---

## 1. Store-submission blockers

### 1.1 Apple (App Store / Mac App Store)
- [x] **macOS daily-reminder backend.** macOS builds use the `_default`
      QTimer backend (dies with the app). Implement
      `NotificationService_macos.mm` — same `UNUserNotificationCenter` +
      `UNCalendarNotificationTrigger(repeats:YES)` code as iOS — and wire it in
      `ViewModels/CMakeLists.txt` (new `APPLE AND NOT IOS` branch). Small task;
      reviewers test advertised features.
- [x] **macOS notarization** (present, secret-gated: submit --wait + staple). `macos.yml` codesigns but never
      runs `xcrun notarytool submit` + `xcrun stapler staple`. Unnotarized
      builds are Gatekeeper-blocked outside the Mac App Store. Add a
      secret-gated notarize step after signing.
- [ ] **Qt LGPL-3 posture on iOS static builds (legal blocker — see §4.1).**
- [~] **VoiceOver coverage** — added to TagChip, Stepper, SearchBox, speaker button, relations handle. Remaining: raw MouseAreas across pages, StatsPage chart descriptions. Original note: only 6 QML files carried `Accessible.*`. Sweep all
      icon-only interactive elements (drag handles, span chips, close/back
      buttons, IconBtn) with `Accessible.role` + `Accessible.name`; add
      `Accessible.description` to StatsPage charts.
- [ ] **Dynamic Type ignored.** `Platform.uiScale` is width-tiered only; the
      user's OS font-size preference is not consumed. Either multiply `uiScale`
      by the OS font scale (`Qt.application.font.pixelSize` ratio against the
      13/14 px baseline) or record an explicit exemption decision here.
- [ ] **iPad check:** `UIDatePickerStyleWheels` inside a FormSheet renders
      small on iPad. Cosmetic; verify on device.

### 1.2 Google (Play)
- [x] **Android scheduled daily reminder (largest parity gap).**
      `NotificationService_android.cpp` has no `scheduleDailyNative`; the
      reminder only fires while the app runs. Implement
      `AlarmManager.setExactAndAllowWhileIdle` + `BroadcastReceiver` (extend
      `NotificationClient.java`) + manifest `<receiver>` +
      `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` permission (API 31+), or
      WorkManager for inexact delivery.
- [ ] **targetSdk 34.** Play has required 35 for updates since late 2025.
      Verify the current floor at submission time (post-knowledge-cutoff
      policy) and bump `QT_ANDROID_TARGET_SDK_VERSION`.
- [ ] **Native photo/media picker.** Android still falls back to the in-app
      Documents list. Implement `ACTION_PICK_IMAGES` (Photo Picker,
      permissionless, Play-preferred) + `ACTION_IMAGE_CAPTURE` for camera,
      mirroring the iOS `pickMediaNative` backend.
- [ ] **Auto-backup audit.** `allowBackup=true` with extraction rules present.
      Decide: is silent restore of the SRS database across devices safe
      (scheduling timestamps survive), or exclude the DB and rely on JSON
      export? Document the decision in `backup_rules.xml` comments.

### 1.3 Microsoft (Windows)
- [x] **VERSIONINFO resource** added to generated rc (FileVersion/ProductVersion/company). Original note: Confirm the generated `tenjin.rc` embeds
      `FILEVERSION`/`PRODUCTVERSION`/company strings (Explorer Properties is
      blank otherwise; SmartScreen reputation suffers). Extend
      `cmake/GenerateIcons.cmake` rc emission if absent.
- [x] **Windows code signing** present (secret-gated signtool). Original note: `windows.yml` produced unsigned NSIS installers →
      SmartScreen warnings. Add a secret-gated `signtool sign` step.
- [ ] **Scheduled toast notifications** unimplemented (QTimer path works while
      the app runs). Acceptable desktop limitation — record as known-issue in
      `TROUBLESHOOTING.md`; WinRT `ScheduledToastNotification` if ever needed.

---

## 2. Feature parity (vs Anki/AnkiDroid, Memrise, Quizlet class)

Priority-ordered by user impact ÷ effort:

1. [x] **TTS pronunciation playback** — `QTextToSpeech` (Qt Multimedia-adjacent
       module, all five targets). Cheap, high-visibility. Gate behind a
       `TTS_SUPPORT` CMake option like `MEDIA_SUPPORT`.
2. [x] **CSV export** (+ keep JSON). Import exists for `.apkg`/JSON only;
       one-way import reads as lock-in. CSV export is a small
       `DatabaseManager_ImportExport.cpp` addition.
3. [x] **Automatic local backups (rotation added)** — rolling pre-import / pre-bulk-delete
       snapshots of the DB (the destructive `deleteAll*` ops already exist).
       Keep N=5 rotating copies under the app data dir.
4. [ ] **Review heatmap + streaks** — calendar heatmap on StatsPage from the
       existing review log; streak counter. Standard retention mechanic.
5. [ ] **Filtered/custom study** — cram-by-tag, study-ahead. The tag system
       makes this mostly a DeckService query + one page.
6. [ ] **Cloze deletions** — new content-block type; renderer masks the cloze
       span during review. Medium effort.
7. [ ] **Typed-answer review mode** — text field + diff highlight against the
       answer. Medium.
8. [ ] **FSRS scheduler (flagship)** — SM-2 is a generation behind; Anki
       defaults to FSRS. Port the open FSRS algorithm (permissively-licensed
       reference implementations exist) into `Service` beside SM-2 with a
       per-deck scheduler switch and parameter optimizer as a later phase.
       Largest single competitive item.
9. [ ] **`.apkg` export** — round-trip with Anki (import already works).
10. [ ] **Home-screen widgets** (due count) — large per-platform effort; defer.

---

## 3. Engineering debt / correctness backlog

- [x] **RTL** — root LayoutMirroring bound to locale direction; direction-aware chevrons; QGuiApplication::setLayoutDirection on load + language change. Needs Arabic screenshot verification (explicit `x:` positioned items do not mirror). Original note: Arabic ships in `TENJIN_UI_LANGUAGES` but no
      `LayoutMirroring` is set anywhere. Verify mirroring propagates from the
      locale or mirror explicitly at the root; test every panel in `ar`.
- [x] **Reduced motion** — was already implemented (per-platform OS probe + `effDuration*` tokens + in-app toggle); this pass tokenized 14 remaining hardcoded motion durations. Original note: gate `Behavior`/animations on a
      `Platform.reducedMotion` token sourced from the OS accessibility setting
      (Apple HIG item; Android/Windows equivalents exist).
- [ ] **Consent gating of network surfaces.** The COPPA gate stores
      `ConsentPending` for under-13, but when CloudService sync goes live it
      must check consent before any transmission; BugReportDialog payload
      contents must be documented in the privacy policy.
- [ ] **Device-verify queue:** native time picker (iOS wheel + Android
      dialog), PHPicker video fix (URL-lifetime copy), entry-page clip fixes
      under the new `uiScale` tiers, Relations tap-to-collapse, font subsets
      rendering (all locales, Arabic joining, CJK).
- [ ] **Deferred notification backends:** Windows WinRT toast, Linux is
      correct as QTimer (no persistent OS scheduler).

---

## 4. Legal & license compliance

Tenjin itself: **MIT** (`LICENSE`, © 2026 Tenjin Maintainers). Obligations
below are what Tenjin owes *others*.

### 4.1 Qt 6 — licensing  ⚠ HIGHEST LEGAL RISK (closed-source decision)

**Tenjin is planned to ship closed-source.** This makes a **Qt commercial
license mandatory for the iOS build**, and is the single hardest prerequisite
before any App Store release.

Reasoning:
- Qt is offered under LGPL-3.0 or a commercial license.
- On iOS, Apple prohibits user-supplied dynamic libraries in App Store apps, so
  Qt is **statically linked**.
- LGPL-3 §4(d) permits static linking only if the end user can relink the
  application against a modified Qt — satisfiable via application source
  availability **or** distributing object files. A closed-source App Store
  binary can do neither.
- Therefore closed-source + iOS + static Qt has **no LGPL-compliant path**; the
  commercial Qt license is the only option. This is the standard route every
  closed-source Qt mobile app takes.

Desktop (Linux/Windows/macOS) and Android can dynamically link Qt, where LGPL-3
§4 is satisfiable even closed-source (convey LGPL text, attribute Qt, allow
library replacement). But maintaining a mixed posture — LGPL desktop, commercial
iOS — is more fragile than buying one commercial license covering all targets.

**Actions:**
- [ ] **Procure a Qt commercial license before iOS submission** (blocks the
      entire Apple track; not resolvable in code).
- [ ] Under commercial Qt, the LGPL relinking provision no longer applies; the
      in-app licenses screen still must convey third-party attributions (OFL
      fonts, Material Symbols, miniz, flag-icons — §4.2–4.5).
- [ ] Do not use GPL-only Qt modules (none currently; keep the `find_package`
      list audited).
- [ ] Record the commercial-license obligation in `SUBMISSION_CHECKLIST.md`.

> Superseded: an earlier draft assumed open-source distribution would satisfy
> LGPL §4(d). That path is void under the closed-source decision.

### 4.2 Fonts — SIL OFL 1.1
Covers **Noto Sans VF, Noto Sans Arabic VF, Noto Sans CJK SC, JetBrains
Mono**. Obligations: include the OFL text (present:
`View/fonts/OFL.txt` — verify it ships in the resource bundle or the
attribution screen, not repo-only); do not sell the fonts standalone; renamed
subsets (`NotoSansTenjin*`) are explicitly permitted by OFL — the Reserved
Font Name clause applies only if RFNs are declared; Noto declares "Noto" as
RFN, so the internal *family name* of subsets should not begin with "Noto".
**Action:** rename the merged subsets' internal name table entries (e.g.
`TenjinSans`) in `GenerateFonts.cmake` via `fontTools` name-table edit —
current output keeps the "Noto Sans" internal name, which violates the RFN
clause for modified versions.

### 4.3 Material Symbols (icon font)
`View/fonts/README.md` records OFL-1.1; Google distributes Material
Symbols/Icons under **Apache-2.0**. **Action:** verify the actual license of
the vendored `variablefont/` artifact and correct the README; Apache-2.0
requires the license text + NOTICE preservation. Either license is
permissive — the obligation is accurate attribution text.

### 4.4 flag-icons (SVGs) — MIT
Include copyright + MIT text in attributions. No other obligation.

### 4.5 miniz — MIT
Vendored via `cmake/Miniz.cmake` for `.apkg` ZIP reading. Include its
copyright + MIT text.

### 4.6 SQLite (via Qt's QSQLITE driver) — public domain
No obligation; attribution optional courtesy.

### 4.7 fontTools, Pillow (build-time only, not distributed)
MIT / MIT-CMU. Not shipped in binaries — no in-app obligation; CI use is
compliant as-is.

### 4.8 Anki `.apkg` format
Reading the documented file format is not a license event; **no AGPL Anki
code may be ported** into `AnkiImporter.cpp` (must remain clean-room from
format documentation). Current importer is original code — keep it that way
and note it in the file header.

### 4.9 Required deliverable
- [ ] **In-app "Open-source licenses" screen** (Settings → About): full texts
      of the third-party components Tenjin bundles — OFL-1.1 (fonts),
      Apache-2.0 or OFL (Material Symbols, per §4.3), MIT (flag-icons, miniz),
      plus Tenjin's own notice. Under a **commercial Qt license** the LGPL-3
      relinking provision does not apply, so the Qt LGPL text is not required;
      include a Qt attribution line per the commercial-license terms.
      (If the project ever reverts to LGPL Qt, add the LGPL-3 text here.)
      Generate `docs/LICENSES.md` + a bundled resource the screen renders.
- [ ] **Subset font internal rename** (§4.2 RFN compliance) in
      `GenerateFonts.cmake`.
- [ ] **Privacy policy URL** in Settings must resolve to a hosted policy
      covering: local-only storage, bug-report payload contents, the future
      sync endpoint, children's data (COPPA), and contact for erasure
      requests. Required by both App Store Connect and Play Console at
      submission.

### 4.10 Privacy regimes (status)
- **COPPA:** age gate implemented (under-13 → `ConsentPending`); verify
  pending state blocks all network surfaces when sync ships.
- **GDPR/GDPR-K:** local-first design minimizes scope; `deleteAll*` + JSON
  export cover informal access/erasure. Real DSR handling required before
  cloud sync launches.
- **iOS PrivacyInfo.xcprivacy:** present (9 accessed-API entries). Re-audit
  whenever a new API category (file timestamp, UserDefaults, etc.) is added.

---

## 5. Suggested execution order

| # | Item | Size | Section |
|---|------|------|---------|
| 1 | OSS licenses screen + LICENSES.md + font RFN rename | S–M | 4.9 / 4.2 |
| 2 | Android AlarmManager daily reminder | M | 1.2 |
| 3 | macOS notification backend | S | 1.1 |
| 4 | Notarization (macOS) + signtool (Windows) CI | S | 1.1 / 1.3 |
| 5 | TTS + CSV export + auto-backup | S each | 2.1–2.3 |
| 6 | Accessibility sweep + RTL audit + reduced motion | M | 1.1 / 3 |
| 7 | Android Photo Picker backend | M | 1.2 |
| 8 | Heatmap/streaks, filtered study | M | 2.4–2.5 |
| 9 | Cloze + typed answer | M | 2.6–2.7 |
| 10 | FSRS scheduler | L | 2.8 |

Unverified items are marked as such above; store-policy floors (Play
targetSdk) and the Qt-LGPL-on-iOS position must be re-verified at submission
time — both are outside static-audit certainty.
