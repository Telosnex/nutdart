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
