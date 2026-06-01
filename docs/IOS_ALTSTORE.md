# iOS build → AltStore sideload

This batch makes the iOS build sideload-ready. The original build produced a
valid unsigned `.ipa`, but three things would have made it look broken or
behave wrong once on the device. All three are now fixed.

## What was wrong, and what changed

1. **No app icon.** There was no asset catalog and no `CFBundleIconName`, so the
   home-screen icon would be blank/white and some sideload validators warn.
   → Added `App/ios/Assets.xcassets/AppIcon.appiconset/` with a real 1024×1024
   icon (the 天 glyph — "Tenjin"), wired into the bundle via CMake and
   `CFBundleIconName`/`ASSETCATALOG_COMPILER_APPICON_NAME`. The icon is RGB with
   no alpha channel, as iOS requires (an icon with alpha is rejected).

2. **Export/import files were unreachable.** Tenjin's cross-device sync writes a
   JSON file, but on iOS the app sandbox hides it from the user.
   → Added `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` +
   a `CFBundleDocumentTypes` entry for `public.json`. Now the app's Documents
   folder shows up in the Files app and Finder file sharing, and Tenjin appears
   as an "Open in" target for `.json` files.

3. **`CFBundleVersion` was a dotted semver (`0.1.0`).** AltStore/Apple expect the
   build number to be a monotonically increasing integer, and re-installing a
   build whose number didn't change is rejected.
   → `CFBundleVersion` is now a real build number (`TENJIN_BUILD_NUMBER`,
   default 1), while `CFBundleShortVersionString` keeps the human `0.1.0`. CI
   passes `${{ github.run_number }}` so every build is distinct.

Also added `ITSAppUsesNonExemptEncryption=false` so no export-compliance prompt
appears on each sideload/upload.

## Files

Replace:
- `App/CMakeLists.txt`
- `App/ios/Info.plist`
- `.github/workflows/ios.yml`

Add:
- `App/ios/Assets.xcassets/Contents.json`
- `App/ios/Assets.xcassets/AppIcon.appiconset/Contents.json`
- `App/ios/Assets.xcassets/AppIcon.appiconset/icon-1024.png`

(The DB path was already correct — `AppDataLocation` + `mkpath`, which resolves
to a writable sandbox dir on iOS. No change needed there.)

## How to sideload (the actual flow)

**Via CI, no Mac needed:**
1. Push to `main` (or run the workflow manually). Download the
   `tenjin-ios-unsigned-ipa` artifact.
2. AltStore: hold Option (macOS) / Shift (Windows) when clicking the AltServer
   tray icon → "Sideload .ipa…" → pick the artifact → sign in with your free
   Apple ID. It re-signs and installs. (Or Sideloadly: drag the ipa in, enter
   Apple ID, Start.)
3. On the iPhone: Settings → General → VPN & Device Management → trust your
   Apple ID. Launch Tenjin.

Free Apple ID: the app runs 7 days, then AltStore auto-refreshes it in the
background (keep AltStore installed); Sideloadly is manual re-sign. Free
accounts also cap you at 3 sideloaded apps.

**Via Xcode on a Mac (1-year if paid, simplest signing):**
`./tools/ios-configure.sh` → open `build-ios/Tenjin.xcodeproj` → set your team
in Signing & Capabilities → Run with the phone selected. Pass
`-DAPPLE_TEAM_ID=XXXXXXXXXX` to enable automatic signing from CMake directly.

## Bundle-id note

The bundle id is `app.tenjin.Tenjin`. With a **free** Apple ID, the id you sign
with must be unique to your account — if a sideload fails with a provisioning
error, change it to something like `com.<yourname>.tenjin` in both
`App/ios/Info.plist` (`CFBundleIdentifier`) and `App/CMakeLists.txt`
(`PRODUCT_BUNDLE_IDENTIFIER` + `MACOSX_BUNDLE_GUI_IDENTIFIER`). AltStore appends
its own suffix automatically, so this is usually only an issue with raw Xcode.

## Optional: one-tap export to a reachable folder

`exportData(fileUrl)` already accepts any path/URL from a FileDialog, which now
works against the Files app. If you also want a no-dialog "Export" button, add a
helper that targets the file-sharing-visible Documents dir:

```cpp
// AppViewModel.h  (public, with the other Q_INVOKABLEs)
Q_INVOKABLE QString defaultExportPath() const;

// AppViewModel.cpp
#include <QDateTime>
QString AppViewModel::defaultExportPath() const
{
    const QString dir =
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QDir().mkpath(dir);
    const QString stamp =
        QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss");
    return dir + "/tenjin-" + stamp + ".json";
}
```

Then in QML: `appVM.exportData(appVM.defaultExportPath())`. On iOS that file
lands in the Files-app-visible Documents folder; on desktop it goes to
~/Documents. (Uses `DocumentsLocation`, not `AppDataLocation`, precisely because
the former is what `UIFileSharingEnabled` exposes.)
