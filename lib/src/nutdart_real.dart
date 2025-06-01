import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;

import '../nutdart_bindings_generated.dart';

const String _libName = 'nutdart';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final NutdartBindings _bindings = NutdartBindings(_dylib);

// The Nutdart class can be used for any additional functionality
// For now, it's just a placeholder
class Nutdart {
  // Add any additional functionality here if needed
}

/// Represents a point on the screen
class Point {
  final int x;
  final int y;

  const Point(this.x, this.y);

  @override
  String toString() => 'Point($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

/// Represents screen size
class Size {
  final int width;
  final int height;

  const Size(this.width, this.height);

  @override
  String toString() => 'Size($width, $height)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Size &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

/// Represents a color
class Color {
  final int r;
  final int g;
  final int b;

  const Color(this.r, this.g, this.b);

  /// Create color from hex value
  Color.fromHex(int hex)
      : r = (hex >> 16) & 0xFF,
        g = (hex >> 8) & 0xFF,
        b = hex & 0xFF;

  /// Convert to hex value
  int get hex => (r << 16) | (g << 8) | b;

  @override
  String toString() => 'Color($r, $g, $b)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Color &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          g == other.g &&
          b == other.b;

  @override
  int get hashCode => r.hashCode ^ g.hashCode ^ b.hashCode;
}

/// Mouse button enumeration
enum MouseButton {
  left(CU_MOUSE_LEFT),
  middle(CU_MOUSE_MIDDLE),
  right(CU_MOUSE_RIGHT);

  const MouseButton(this.value);
  final int value;
}

/// Mouse operations
class Mouse {
  Mouse._();

  /// Move mouse to specified coordinates
  static void moveTo(int x, int y) {
    _bindings.cu_mouse_move(x, y);
  }

  /// Move mouse to a Point
  static void moveToPoint(Point point) {
    moveTo(point.x, point.y);
  }

  /// Click mouse button at current position
  static void click([MouseButton button = MouseButton.left]) {
    _bindings.cu_mouse_click(button.value);
  }

  /// Click mouse button at specified coordinates
  static void clickAt(int x, int y, [MouseButton button = MouseButton.left]) {
    moveTo(x, y);
    click(button);
  }

  /// Click mouse button at a Point
  static void clickAtPoint(Point point,
      [MouseButton button = MouseButton.left]) {
    clickAt(point.x, point.y, button);
  }

  /// Double-click mouse button
  static void doubleClick([MouseButton button = MouseButton.left]) {
    _bindings.cu_mouse_double_click(button.value);
  }

  /// Double-click at specified coordinates
  static void doubleClickAt(int x, int y,
      [MouseButton button = MouseButton.left]) {
    moveTo(x, y);
    doubleClick(button);
  }

  /// Drag from one point to another
  static void drag(Point from, Point to,
      [MouseButton button = MouseButton.left]) {
    _bindings.cu_mouse_drag(from.x, from.y, to.x, to.y, button.value);
  }

  /// Scroll mouse wheel
  static void scroll(int deltaX, int deltaY) {
    _bindings.cu_mouse_scroll(deltaX, deltaY);
  }

  /// Scroll vertically
  static void scrollVertical(int delta) {
    scroll(0, delta);
  }

  /// Scroll horizontally
  static void scrollHorizontal(int delta) {
    scroll(delta, 0);
  }

  /// Get current mouse position
  static Point getPosition() {
    final pos = _bindings.cu_mouse_get_position();
    return Point(pos.x, pos.y);
  }

  /// Press and hold mouse button
  static void press([MouseButton button = MouseButton.left]) {
    _bindings.cu_mouse_toggle(1, button.value);
  }

  /// Release mouse button
  static void release([MouseButton button = MouseButton.left]) {
    _bindings.cu_mouse_toggle(0, button.value);
  }
}

/// Keyboard operations
class Keyboard {
  Keyboard._();

  /// Tap a key
  static void tap(String key) {
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings.cu_keyboard_key_tap(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Tap a key with modifiers
  static void tapWithModifiers(String key, List<String> modifiers) {
    final modifierString = modifiers.join(',');
    final keyPtr = key.toNativeUtf8();
    final flagsPtr = modifierString.toNativeUtf8();
    try {
      _bindings.cu_keyboard_key_tap_with_flags(
          keyPtr.cast<Char>(), flagsPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
      ffi.malloc.free(flagsPtr);
    }
  }

  /// Type a string
  static void type(String text) {
    final textPtr = text.toNativeUtf8();
    try {
      _bindings.cu_keyboard_type_string(textPtr.cast<Char>());
    } finally {
      ffi.malloc.free(textPtr);
    }
  }

  /// Press and hold a key
  static void keyDown(String key) {
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings.cu_keyboard_key_down(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Release a key
  static void keyUp(String key) {
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings.cu_keyboard_key_up(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Common key combinations
  static void copy() =>
      tapWithModifiers('c', ['cmd']); // or 'ctrl' on Windows/Linux
  static void paste() => tapWithModifiers('v', ['cmd']);
  static void cut() => tapWithModifiers('x', ['cmd']);
  static void selectAll() => tapWithModifiers('a', ['cmd']);
  static void undo() => tapWithModifiers('z', ['cmd']);
  static void redo() => tapWithModifiers('z', ['cmd', 'shift']);
  static void save() => tapWithModifiers('s', ['cmd']);

  /// Navigation keys
  static void enter() => tap('return');
  static void escape() => tap('escape');
  static void tab() => tap('tab');
  static void space() => tap('space');
  static void backspace() => tap('backspace');
  static void delete() => tap('delete');

  /// Arrow keys
  static void arrowUp() => tap('up');
  static void arrowDown() => tap('down');
  static void arrowLeft() => tap('left');
  static void arrowRight() => tap('right');
}

/// Screen operations
class Screen {
  Screen._();

  /// Get screen size
  static Size getSize() {
    final size = _bindings.cu_screen_get_size();
    return Size(size.width, size.height);
  }

  /// Capture entire screen
  ///
  /// [maxSmallDimension] - Maximum size for the smaller dimension (width or height)
  /// [maxLargeDimension] - Maximum size for the larger dimension (width or height)
  /// [quality] - JPEG quality (0-100), defaults to 80
  static Uint8List? capture({
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality = 80,
  }) {
    return _captureScreen(
      maxSmallDimension: maxSmallDimension,
      maxLargeDimension: maxLargeDimension,
      quality: quality,
    );
  }

  /// Capture region of screen
  ///
  /// [maxSmallDimension] - Maximum size for the smaller dimension (width or height)
  /// [maxLargeDimension] - Maximum size for the larger dimension (width or height)
  /// [quality] - JPEG quality (0-100), defaults to 80
  static Uint8List? captureRegion(
    int x,
    int y,
    int width,
    int height, {
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality = 80,
  }) {
    return _captureScreen(
      x: x,
      y: y,
      width: width,
      height: height,
      maxSmallDimension: maxSmallDimension,
      maxLargeDimension: maxLargeDimension,
      quality: quality,
    );
  }

  static Uint8List? _captureScreen({
    int? x,
    int? y,
    int? width,
    int? height,
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality = 80,
  }) {
    // If resize parameters are provided, use the JPEG functions
    if (maxSmallDimension != null || maxLargeDimension != null) {
      final sizePtr = ffi.malloc<Int64>();
      try {
        Pointer<Uint8> jpegPtr;

        if (x != null && y != null && width != null && height != null) {
          jpegPtr = _bindings.cu_screen_capture_region_jpeg(
            x,
            y,
            width,
            height,
            maxSmallDimension ?? -1,
            maxLargeDimension ?? -1,
            quality,
            sizePtr,
          );
        } else {
          jpegPtr = _bindings.cu_screen_capture_full_jpeg(
            maxSmallDimension ?? -1,
            maxLargeDimension ?? -1,
            quality,
            sizePtr,
          );
        }

        if (jpegPtr == nullptr) {
          return null;
        }

        final jpegSize = sizePtr.value;
        final data = Uint8List.fromList(jpegPtr.asTypedList(jpegSize));

        _bindings.cu_screen_free_jpeg(jpegPtr);

        return data;
      } finally {
        ffi.malloc.free(sizePtr);
      }
    }

    // Fallback to original bitmap method
    Pointer<CUBitmap> bitmapPtr;

    if (x != null && y != null && width != null && height != null) {
      bitmapPtr = _bindings.cu_screen_capture_region(x, y, width, height);
    } else {
      bitmapPtr = _bindings.cu_screen_capture_full();
    }

    if (bitmapPtr == nullptr) {
      return null;
    }

    final bitmap = bitmapPtr.ref;
    final dataSize = bitmap.bytewidth * bitmap.height;
    final data = Uint8List.fromList(bitmap.data.asTypedList(dataSize));

    _bindings.cu_screen_free_capture(bitmapPtr);

    return data;
  }
}

/// Utility functions
class ComputerUse {
  ComputerUse._();

  /// Sleep for specified milliseconds (non-blocking)
  static Future<void> sleep(int milliseconds) async {
    await Future.delayed(Duration(milliseconds: milliseconds));
  }

  /// Sleep for specified duration (non-blocking)
  static Future<void> sleepDuration(Duration duration) async {
    await Future.delayed(duration);
  }
}