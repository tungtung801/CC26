# CC18LiquidGlass (RootHide arm64e & iOS 15/16 Fixed)

Reconstructed and patched Theos source for `com.seko.cc18liquidglass`, fixed for **RootHide (`arm64e`, A12+)** on **iOS 15.6.1** and **iOS 16.6.1**, ready to build via GitHub Actions.

## Root Causes Diagnosed & Fixed
1. **Rootless-only `arm64` + `minOS 16.0` (Blocked loading on RootHide A12 & crashed Settings on iOS 15.6.1):**
   - Original `.deb` shipped an `arm64`-only `CC18LiquidGlass.dylib` packaged for Rootless (`/var/jb`), and compiled both binaries with `minOS = 16.0.0`.
   - **Fix:** Updated root & Prefs `Makefile`s to support `THEOS_PACKAGE_SCHEME ?= roothide` (`ARCHS = arm64e` for RootHide, `arm64 arm64e` for Rootless), lowered deployment target to `TARGET := iphone:clang:latest:15.0`, and set `Architecture: iphoneos-arm` in `control` so Theos automatically rewrites it to `iphoneos-arm64e` (RootHide) or `iphoneos-arm64` (Rootless).
2. **Duplicate ObjC Class Collision & Double-Hooking `MTMaterialView` with `dylv.liquidass` (SafeMode):**
   - Original `.deb` compiled 4 unused files from `Shared/` (`LGFramework.m`, `LGGlassKit.x`, `LGLiveBackdropView.m`, `LGSharedSupport.m`) into `CC18LiquidGlass.dylib`, even though `Tweak.x` calls zero symbols from `Shared/`. When installed alongside `dylv.liquidass`, SpringBoard loaded duplicate copies of 8 ObjC classes (`LGLiveBackdropView`, etc.) and hooked `MTMaterialView` multiple times, causing SafeMode.
   - **Fix:** Excluded `Shared/` from `CC18LiquidGlass_FILES` in `Makefile` (kept in `Shared/` as reverse-engineered reference only) and removed the hard `dylv.liquidass` dependency from `control`. `%group DylvGhost` still cleanly hides `dylv.liquidass` layers if it is installed.
3. **`arm64e` PAC Pointer & Debug Dump Risks in `Tweak.x`:**
   - Stripped PAC bits (`ptrauth_strip`) before calling `dladdr()` on `method_getImplementation()` in `ScanConflicts()` on `arm64e`.
   - Moved `%hook C18ConnectivityView` into `%group C18Conn` (only initialized when the `C18` replica tweak is installed).
   - Guarded debug `DumpHorizontalModules()` behind `#ifdef CC18_DEBUG_DUMP` and wrapped `ProbeTile` KVC calls in `@try/@catch`.
4. **Settings Crash (`CC18LiquidGlassPrefs`):**
   - Moved `scanCrashLogsManual:` off the main thread onto a utility background queue with `@autoreleasepool` per file (previously read up to 40 × 4 MB crash logs synchronously on the main thread, triggering watchdog/OOM crashes in Settings).
   - Added `cc18SafePresent:` to guard `presentViewController:` against detached windows or overlapping alert presentations.

## Building via GitHub Actions
Push this repository to GitHub and trigger **Actions -> Build CC18LiquidGlass (.deb)**. It will produce two downloadable artifacts:
- `CC18LiquidGlass-roothide-arm64e` (for RootHide A12+ on iOS 15.6.1 / 16.6.1)
- `CC18LiquidGlass-rootless-arm64` (for Rootless)
