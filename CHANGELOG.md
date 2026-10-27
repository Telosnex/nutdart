## Unreleased

* Replace Flutter platform-plugin/SPM builds with a Dart build hook and Kiln:
  verified desktop prebuilts, source-key matching and a source-build fallback.
* Use generated `@Native` code-asset bindings instead of framework/DLL-name
  loading. Broken desktop installations now fail instead of silently no-oping.
* Require Dart 3.10 / Flutter 3.38; macOS native builds target macOS 12+.
* Add shared Telosnex Kiln release/check workflows, SHA-pinned actions and
  Renovate. Test all six desktop targets, web JS/Wasm and GNOME portal flows.
* Assert native asset loading in tests; make physical mouse/keyboard/capture
  tests opt-in and run them only on an isolated X11 desktop in CI.
* Fix standalone macOS CMake ARC flags and CoreMedia/CoreVideo linkage.

## 0.1.0

### Breaking
* Linux: synchronous screen capture on Wayland now returns null; it no
  longer runs `grim`/ImageMagick. Use `PortalComputerUse`
  (`package:nutdart/nutdart_portal.dart`) for Wayland capture.
* iOS/macOS: migrated to Swift Package Manager; CocoaPods podspecs removed.

### Added
* `Computer`, an async interface for pointer, keyboard, text, scroll, cursor
  position, screenshot, screen size, and session end. Implemented by
  `NativeComputer` and `PortalComputerUse`.
* Linux XDG desktop portal backend (`nutdart_portal`) for Wayland: pointer,
  keys, text, scrolling, named keys, and session end on lock.
  `typeOnActiveLayout` checks GNOME's active keyboard layout first.
* `nutdart_portal` compiles for web.

### Fixed
* macOS: fix stack memory corruption in `keyCodeForChar` on 64-bit
  (#1, thanks @PekingSpades).
* Linux: screen size and capture don't crash without an X display.

## 0.0.1

* Initial release.
