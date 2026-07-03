# App Store & Play Store Submission Checklist

Status legend: ✅ done in code · ⚠️ needs your action · ⏳ before each release

## iOS (App Store)

### In the repo (✅ done)
- ✅ `App/ios/PrivacyInfo.xcprivacy` — privacy manifest (required since 2024)
- ✅ `App/ios/Tenjin.entitlements` — entitlements file
- ✅ `App/ios/Info.plist.in` — usage strings, file sharing, document types, category
- ✅ App icon: opaque 1024×1024 PNG (no alpha, no rounded corners)
- ✅ `Q_IMPORT_PLUGIN(QSQLiteDriverPlugin)` — prevents launch crash on device
- ✅ Accessibility roles/names on interactive elements (VoiceOver)
- ✅ Keyboard shortcuts (iPad with hardware keyboard)
- ✅ In-app data deletion (Settings ▸ Danger zone)

### You must provide (⚠️)
- ⚠️ Apple Developer account + Team ID (set `APPLE_TEAM_ID` in CMake for signing)
- ⚠️ Privacy policy hosted at https://tenjin.app/privacy (URL is referenced in-app)
- ⚠️ Terms of service at https://tenjin.app/terms
- ⚠️ Support URL at https://tenjin.app/support
- ⚠️ Screenshots: 6.9" + 6.5" iPhone, 13" iPad (3-10 each) — see store/ios/metadata.md
- ⚠️ App Store Connect listing (name, subtitle, description, keywords)
- ⚠️ Age rating questionnaire (expected: 4+)
- ⚠️ Export compliance: ITSAppUsesNonExemptEncryption=false is set (no prompt)

### Each release (⏳)
- ⏳ Bump version in `.env` (TENJIN_APP_VERSION) and pass TENJIN_BUILD_NUMBER
- ⏳ Test on a physical device — verify no launch crash, fonts render, icons show
- ⏳ Verify crash-free: Apple rejects >2% crash rate

## Android (Play Store)

### In the repo (✅ done)
- ✅ `App/android/AndroidManifest.xml` — permissions, activity, FileProvider
- ✅ `App/android/res/xml/backup_rules.xml` + `data_extraction_rules.xml`
- ✅ App icons: all mipmap densities (mdpi → xxxhdpi)
- ✅ targetSdkVersion 34, minSdkVersion 26 (meets Play requirements)
- ✅ Scoped storage only (no broad storage permissions)
- ✅ In-app data deletion

### You must provide (⚠️)
- ⚠️ Google Play Console account + signing key (upload key via Play App Signing)
- ⚠️ Data safety form (see store/android/metadata.md — declares crash diagnostics)
- ⚠️ Privacy policy URL
- ⚠️ Feature graphic 1024×500, phone + tablet screenshots
- ⚠️ Content rating (IARC questionnaire — expected: Everyone)
- ⚠️ 512×512 PNG icon for the listing (with alpha allowed)

### Each release (⏳)
- ⏳ Bump versionCode (TENJIN_BUILD_NUMBER must increase every upload)
- ⏳ Build an AAB (Android App Bundle), not just APK, for Play distribution
- ⏳ Test on a physical device

## Both platforms — before first submission
- ⚠️ Host privacy policy + terms + support pages (referenced from Settings)
- ⚠️ Decide on the cloud endpoint (TENJIN_CLOUD_URL) — leave empty to ship
      fully offline; sync shows "Coming soon" and bug reports save locally
- ⏳ Run the full test suite on physical devices for both platforms
- ⏳ Verify the icon font (MaterialSymbolsOutlined.ttf) is bundled — it
      auto-downloads at configure time via cmake/IconFont.cmake

## Automated tests

Run locally:
```
cmake -S . -B build -DTENJIN_BUILD_TESTS=ON -DSANITIZERS="asan,ubsan"
cmake --build build --target tenjin_tests
ctest --test-dir build --output-on-failure
```

CI runs these on every push and PR via `.github/workflows/tests.yml`
(Linux, ASan + UBSan, offscreen Qt platform).

Coverage:
- `test_anki_importer.cpp` — builds a minimal `.apkg` in-memory, verifies
  field/tag/deck extraction and that malformed files are rejected
- `test_database_roundtrip.cpp` — entry CRUD, tag lifecycle, and a full
  export → import round-trip with count verification

These are a foundation, not exhaustive coverage. Expand as features land.
