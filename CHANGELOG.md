## 0.2.0

### Breaking
* Requires Dart 3.10 / Flutter 3.38 or newer.
* macOS 12 or newer is required (was 10.14).
* The native library is now a Dart build-hook code asset, not a Flutter
  platform plugin (no Swift Package Manager, CocoaPods or plugin
  registration). On desktop, a missing or broken native library is now an
  error instead of silently turning every call into a no-op. Mobile and web
  behave as before.

### Added
* SHA-256-verified prebuilt desktop libraries via
  [Kiln](https://pub.dev/packages/kiln) for Windows, Linux and macOS
  (x64 and ARM64), with a source-build fallback. Choose with the
  `native_build` hook user-define: `auto` (default), `download` or `source`.
  See `native_artifacts/README.md`.

### Fixed
* Windows: window titles use the Unicode APIs (`GetWindowTextW`).
* Linux: the window-highlight code is now linked into the library.

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
