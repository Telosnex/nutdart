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
| Linux    | ✅ Full | ⚠️ X11 only, Wayland doesn't have sufficient APIs |
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

- **macOS/iOS**: Uses Xcode and CocoaPods
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