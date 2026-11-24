# CC18LiquidGlass (Reverse Engineered Source)

Complete reconstructed Theos project structure and Objective-C / Logos source code reverse engineered from `com.seko.cc18liquidglass_1.0.2-6+debug_iphoneos-arm64.deb`.

## Package Metadata
- **Package ID:** `com.seko.cc18liquidglass`
- **Version:** `1.0.2-6+debug`
- **Author / Maintainer:** Seko
- **Architecture:** `iphoneos-arm64` (tweak dylib), `arm64 + arm64e` (PreferenceBundle)
- **Target Scheme:** Rootless (`/var/jb`), minOS `16.0`, SDK `16.4`, ARC (`-fobjc-arc`)
- **Depends:** `mobilesubstrate`, `preferenceloader`, `firmware (>= 14.0)`, `dylv.liquidass (>= 0.1.2t+r2)`
- **Filter:** `com.apple.springboard`

## Project Structure
```text
CC18LiquidGlass/
├── Makefile                                  # Root Theos rootless Makefile
├── control                                   # Debian package control file
├── CC18LiquidGlass.plist                     # Substrate filter (SpringBoard)
├── Tweak.x                                   # Main Control Center Liquid Glass hooks & renderer
├── Shared/
│   ├── LGFramework.h / LGFramework.m         # LGAdjustableBlurView, LGSpecularHighlightView, LGButtonView, LGLiquidBlockerGesture
│   ├── LGGlassKit.h / LGGlassKit.x           # Material host routing, glass tracking & MTMaterialView hooks
│   ├── LGLiveBackdropView.h / .m             # Live backdrop renderer, CAFilter setup & CoreMotion highlights
│   └── LGSharedSupport.h / LGSharedSupport.m # Process/safe-mode checks, prefs cache, logging & image utils
└── CC18LiquidGlassPrefs/
    ├── Makefile                              # PreferenceBundle Makefile (arm64 + arm64e)
    ├── entry.plist                           # PreferenceLoader entry
    ├── CC18LiquidGlassRootListController.h   # Settings controller header
    ├── CC18LiquidGlassRootListController.m   # Settings UI, presets, JSON import/export, conflict & crash log checks
    └── Resources/
        ├── Info.plist                        # Bundle Info.plist
        └── Root.plist                        # PreferenceLoader specifiers
```

## Verification Summary
- **Mach-O Symbol Coverage:** 100% of non-compiler-generated functions, Objective-C classes/methods, and Logos hooks/groups matched across both `CC18LiquidGlass.dylib` (446 symbols) and `CC18LiquidGlassPrefs` (52 symbols).
- **Syntax & Structure Checks:** All `.plist` files validated via XML parser; all `.h`/`.m`/`.x` files verified for balanced delimiters, `%hook`/`%group`/`%end` blocks, `@interface`/`@implementation`/`@end` pairs, zero duplicate non-static C symbols, and 100% `Root.plist` action/key coverage.

## Building with Theos
```bash
export THEOS=/path/to/theos
make package THEOS_PACKAGE_SCHEME=rootless
```
