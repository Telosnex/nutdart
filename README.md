# nutdart

A powerful Flutter FFI plugin built on libnut-core for **desktop automation** that provides comprehensive mouse control, keyboard automation, and screen capture capabilities across Windows, macOS, and Linux platforms.

Developed by [Telosnex](https://telosnex.com) for integrating with Anthropic's Claude LLM computer use tool.

## 🚀 Features

### 🖱️ Mouse Control
- **Cursor Movement**: Move mouse to precise coordinates or points
- **Clicking**: Left, middle, and right-click with single or double-click support
- **Dragging**: Drag operations between any two points
- **Scrolling**: Horizontal and vertical scrolling with custom deltas
- **Press & Hold**: Independent mouse button press and release control
- **Position Tracking**: Get current mouse cursor position

### ⌨️ Keyboard Automation
- **Key Tapping**: Send individual key presses with full key name support
- **Modifier Keys**: Support for Cmd/Ctrl, Alt, Shift, Meta, and Fn combinations
- **String Typing**: Type complete strings.
- **Key States**: Hold keys down and release them independently
- **Built-in Shortcuts**: Pre-built methods for common operations (copy, paste, save, etc.)
- **Navigation Keys**: Arrow keys, Enter, Escape, Tab, Backspace, Delete, and more

### 📸 Screen Capture
- **Full Screen**: Capture entire desktop with optional JPEG compression
- **Region Capture**: Capture specific rectangular areas
- **Smart Resizing**: Automatic image resizing with max dimension constraints
- **JPEG Compression**: Configurable quality settings (0-100)
- **Memory Efficient**: Direct JPEG encoding without intermediate bitmap storage

### 🎯 Cross-Platform Support
- **macOS**: Native ScreenCaptureKit integration for optimal performance
- **Windows**: Windows API-based implementation with full feature support
- **Linux**: X11-based implementation for comprehensive desktop control
- **Graceful Degradation**: Stub implementations for unsupported platforms (web, mobile)

## 📦 Installation

Add `nutdart` to your `pubspec.yaml` file:

```yaml
dependencies:
  nutdart: ^0.0.1
```

Then run:
```bash
flutter pub get
```

## 🔧 Usage

### Basic Mouse Control

```dart
import 'package:nutdart/nutdart.dart';

// Move mouse to specific coordinates
Mouse.moveTo(500, 300);

// Click at current position
Mouse.click(); // Left click by default
Mouse.click(MouseButton.right); // Right click

// Click at specific coordinates
Mouse.clickAt(100, 200);

// Double-click
Mouse.doubleClick();

// Drag from one point to another
Mouse.drag(Point(100, 100), Point(300, 300));

// Scroll
Mouse.scrollVertical(-3); // Scroll up
Mouse.scrollHorizontal(2); // Scroll right

// Get current mouse position
Point position = Mouse.getPosition();
print('Mouse is at: ${position.x}, ${position.y}');
```

### Keyboard Automation

```dart
// Type a string
Keyboard.type("Hello, World!");

// Tap individual keys
Keyboard.tap("enter");
Keyboard.tap("escape");
Keyboard.tab();

// Use modifier keys
Keyboard.tapWithModifiers("c", ["cmd"]); // Cmd+C
Keyboard.tapWithModifiers("z", ["cmd", "shift"]); // Cmd+Shift+Z

// Built-in shortcuts
Keyboard.copy();
Keyboard.paste();
Keyboard.save();
Keyboard.selectAll();

// Navigation
Keyboard.arrowUp();
Keyboard.arrowDown();
Keyboard.enter();
Keyboard.backspace();

// Hold and release keys
Keyboard.keyDown("shift");
Keyboard.tap("a"); // Types "A" while shift is held
Keyboard.keyUp("shift");
```

### Screen Capture

```dart
// Get screen dimensions
Size screenSize = Screen.getSize();
print('Screen: ${screenSize.width}x${screenSize.height}');

// Capture full screen
Uint8List? screenshot = Screen.capture();

// Capture with JPEG compression and resizing
Uint8List? compressed = Screen.capture(
  maxSmallDimension: 800,  // Resize smaller dimension to max 800px
  quality: 85,             // JPEG quality (0-100)
);

// Capture specific region
Uint8List? region = Screen.captureRegion(
  100, 100,     // x, y
  800, 600,     // width, height
  quality: 90,
);

// Save screenshot to file
if (screenshot != null) {
  File('screenshot.jpg').writeAsBytesSync(screenshot);
}
```

### Complete Example

```dart
import 'package:nutdart/nutdart.dart';
import 'dart:io';

void automateTask() async {
  // Get screen center
  final screenSize = Screen.getSize();
  final center = Point(screenSize.width ~/ 2, screenSize.height ~/ 2);
  
  // Move to center and click
  Mouse.moveToPoint(center);
  Mouse.click();
  
  // Type some text
  Keyboard.type("Automated with nutdart!");
  
  // Select all and copy
  Keyboard.selectAll();
  await ComputerUse.sleep(100); // Brief pause
  Keyboard.copy();
  
  // Take a screenshot
  final screenshot = Screen.capture(maxSmallDimension: 1200, quality: 90);
  if (screenshot != null) {
    File('automation_result.jpg').writeAsBytesSync(screenshot);
    print('Screenshot saved!');
  }
}
```

## 🔒 Platform Availability

This plugin is designed exclusively for **desktop platforms**:

| Platform | Support | Notes |
|----------|---------|-------|
| macOS    | ✅ Full | Uses ScreenCaptureKit |
| Windows  | ✅ Full | Uses Win32 API |
| Linux    | X11 + portal prototype | Synchronous API uses X11. Wayland uses the separate asynchronous portal API. |
| Web      | ⚠️ Stub | Compiles but functions are no-ops |
| Android  | ⚠️ Stub | Compiles but functions are no-ops |
| iOS      | ⚠️ Stub | Compiles but functions are no-ops |

## Architecture

- **FFI**: Direct communication with native C libraries for maximum performance
- **Graceful Degradation**: Automatic fallback to no-op stubs on unsupported environments (web, mobile)
- **Screen Capture**: JPEG compression happens in native code for maximum efficiency

## 🔧 Developming on the plugin

### Building Native Code

The plugin automatically builds native libraries for each platform:

- **macOS/iOS**: Uses Xcode and Swift Package Manager (iOS is a stub)
- **Windows**: Uses CMake and MSVC
- **Linux**: Uses CMake and GCC
- **Android**: Uses Gradle and NDK (stub only)

#### Regenerating FFI Bindings

```bash
dart run ffigen --config ffigen.yaml
```

### Running Example

```bash
cd example
flutter run
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests, report bugs, or suggest new features.

## 🙏 Acknowledgments

Wouldn't be possible without nut.js, its C libraries are the core
of the plugin. libnut-core has been upgraded to support the most recent macOS API required for screen capture, ScreenCaptureKit.

## Linux portal prototype

`PortalComputerUse` uses desktop portals on Linux. The existing synchronous API remains unchanged.
GNOME or another backend with RemoteDesktop support must run in the user session.

```dart
import 'package:nutdart/nutdart_portal.dart';

final portal = PortalComputerUse();
try {
  await portal.start(); // User action: approve sharing and remote interaction.
  final size = portal.sharedSize!;
  await portal.moveTo(size.width ~/ 2, size.height ~/ 2);
  final frame = await portal.captureFrame();
  await portal.moveToFrame(frame, frame.pixelSize.width / 2, frame.pixelSize.height / 2);
  final png = frame.png;
} finally {
  await portal.close();
}
```

Each input call returns a Future. Await calls in order.
Pointer coordinates are logical coordinates within the selected monitor.
Screenshot bytes are encoded PNG. Screenshot consent is separate from remote-control consent.
Use `captureFrame()` for computer use. It reads the approved PipeWire stream and
returns a `PortalFrame` with PNG bytes, pixel dimensions, and logical dimensions.
`moveToFrame(frame, x, y)` maps image pixels to that stream's pointer coordinates.
For a resized image, pass `imageSize: Size(width, height)`; import `Size` from
`package:nutdart/nutdart.dart`. Cropped or rotated images require caller-side mapping.
Frames from a revoked or previous session cannot be used for pointer input.
Restart the session after changing monitor resolution, scale, or orientation.

The separate `capture()` method uses the Screenshot portal. Its image may cover
a different area and has no input-coordinate mapping.

The prototype supports pointer buttons, absolute motion, keysyms, and text input.
It rejects input after session revocation or missing input consent.
PipeWire capture requires 64-bit Linux and the GStreamer runtime libraries
`libgstreamer-1.0`, `libgstapp-1.0`, and `libglib-2.0`, plus the `pipewire`,
`videoconvert`, `png`, and `appsink` plugins. A sandbox must include these runtimes.
The client opens the stream lazily and encodes frames to PNG in native worker threads.
It keeps one queued frame and does not write stream images to disk.
By default, a capture returns the next available sample, including a queued sample.
`captureFrame(fresh: true)` rejects samples with timestamps at or before its native capture boundary.
The boundary starts when the native worker handles the request, after earlier queued captures.
The returned frame exposes `runningTimeNs` and `boundaryNs` for diagnostics.
These timestamps use pipeline running time, not wall time.

For an input-and-observe loop, await input, request a fresh frame, and verify the visible result.
A fresh timestamp does not prove that the application processed an input event.
The client does not use keepalive images to satisfy a fresh capture.
A static desktop can time out because no new frame exists.
Native waits run off the UI isolate. Frame waits time out after ten seconds.

The prototype still uses portal input methods rather than libei.
It has no restore-token persistence, image resizing, scrolling, window control, or global pointer query.

For a consent, stream-capture, and pointer smoke test, run
`dart run dev/portal_probe.dart` in the Linux desktop session.
This probe captures three frames, maps their centers to pointer coordinates,
and closes the session. It does not click or type.

GNOME Wayland on Ubuntu ARM64 has passed the live smoke test at 1× scale.
Scaled-image coordinate mapping has unit tests. KDE, mixed-DPI monitors, libei,
and execution inside Flatpak remain untested.

### Controlled validation probes

Run `dart run dev/portal_native_probe.dart` on Linux for native lifecycle checks.
It uses local sockets and synthetic video. It does not request desktop access.
The probe checks descriptor transfer, stale-frame rejection, concurrent close, and end of stream.
The Ubuntu ARM64 run passed 25 transfer/pipeline cycles with no descriptor growth (10 → 10).

Run `dart run dev/portal_loop_probe.dart` in a Linux desktop session with GTK4.
Share the monitor with its red fullscreen button. Enable remote interaction.
The probe aborts before input if the image does not show the test surface.
It alternates five clicks and five Space presses on that button.
Each action requires a fresh frame with the expected pixels and a matching target activation count.
The button label updates continuously so the compositor produces real frames on a static desktop.
The fixture runs in a child process with a thread-bound GTK loop and software rendering.
The controller checks focus before each input and aborts on unexpected target activations.
Manual clicks made before automation starts form a baseline, not a test result.
By default, the probe closes its window and session after success or failure.
With `--serve`, it retains the approved session for retries, for up to 30 minutes.
The log shows a private `CONTROL` directory in `/tmp`.
The command helper uses that directory and the same desktop user:

```sh
dart run dev/portal_loop_command.dart <CONTROL-directory> state
dart run dev/portal_loop_command.dart <CONTROL-directory> run --wait-focus
dart run dev/portal_loop_command.dart <CONTROL-directory> close
```

A retry does not request new consent. The `close` command releases consent and closes the fixture.
The desktop sharing controls can revoke the session at any time.
The client does not store restore tokens or change desktop permission settings.

The Ubuntu GNOME run passed all ten actions: five clicks and five Space presses.
Each Space press produced its matching key press and release in the fixture.
Each action produced the expected pixels in a frame newer than the capture boundary.
Observed input-to-verification times were 81–236 ms.
Retries reused one approved session. The client closed the session and fixture after the batch.
The live portal process held 52 descriptors before and after the retries and successful batch.
Focus-loss checks also passed: the probe stopped before sending further input.
