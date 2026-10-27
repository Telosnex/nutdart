// Desktop FFI implementation. The build hook supplies the native code asset;
// mobile retains its unsupported/no-op behavior. Web uses nutdart_stub.dart.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:nutdart/src/nutdart_model.dart';

import '../nutdart_bindings_generated.dart' show CUBitmap;
import '../nutdart_bindings_generated.dart' as bindings;

// Resolve through the code asset, never a framework name or the loader's
// search path. A broken desktop installation must fail, not silently no-op.
final bool _available =
    (Platform.isMacOS || Platform.isWindows || Platform.isLinux) &&
    bindings.addresses.cu_screen_get_size != nullptr;

// The Nutdart class can be used for any additional functionality
// For now, it's just a placeholder.
class Nutdart {
  const Nutdart();
  static bool get isAvailable => _available;
}

// Helper to get the native value for a mouse button
int _mouseButtonValue(MouseButton button) {
  switch (button) {
    case MouseButton.left:
      return 1; // CU_MOUSE_LEFT
    case MouseButton.middle:
      return 2; // CU_MOUSE_MIDDLE
    case MouseButton.right:
      return 3; // CU_MOUSE_RIGHT
  }
}

/// Mouse operations
class Mouse {
  Mouse._();

  /// Move mouse to specified coordinates
  static void moveTo(int x, int y) {
    if (_available) bindings.cu_mouse_move(x, y);
  }

  /// Move mouse to a Point
  static void moveToPoint(Point point) {
    moveTo(point.x, point.y);
  }

  /// Click mouse button at current position
  static void click([MouseButton button = MouseButton.left]) {
    if (_available) bindings.cu_mouse_click(_mouseButtonValue(button));
  }

  /// Click mouse button at specified coordinates
  static void clickAt(int x, int y, [MouseButton button = MouseButton.left]) {
    moveTo(x, y);
    click(button);
  }

  /// Click mouse button at a Point
  static void clickAtPoint(
    Point point, [
    MouseButton button = MouseButton.left,
  ]) {
    clickAt(point.x, point.y, button);
  }

  /// Double-click mouse button
  static void doubleClick([MouseButton button = MouseButton.left]) {
    if (_available) bindings.cu_mouse_double_click(_mouseButtonValue(button));
  }

  /// Double-click at specified coordinates
  static void doubleClickAt(
    int x,
    int y, [
    MouseButton button = MouseButton.left,
  ]) {
    moveTo(x, y);
    doubleClick(button);
  }

  /// Drag from one point to another
  static void drag(
    Point from,
    Point to, [
    MouseButton button = MouseButton.left,
  ]) {
    if (_available) {
      bindings.cu_mouse_drag(
        from.x,
        from.y,
        to.x,
        to.y,
        _mouseButtonValue(button),
      );
    }
  }

  /// Scroll mouse wheel
  static void scroll(int deltaX, int deltaY) {
    if (_available) bindings.cu_mouse_scroll(deltaX, deltaY);
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
    if (!_available) return const Point(0, 0);
    final pos = bindings.cu_mouse_get_position();
    return Point(pos.x, pos.y);
  }

  /// Press and hold mouse button
  static void press([MouseButton button = MouseButton.left]) {
    if (_available) bindings.cu_mouse_toggle(1, _mouseButtonValue(button));
  }

  /// Release mouse button
  static void release([MouseButton button = MouseButton.left]) {
    if (_available) bindings.cu_mouse_toggle(0, _mouseButtonValue(button));
  }
}

/// Keyboard operations
class Keyboard {
  Keyboard._();

  /// Tap a key
  static void tap(String key) {
    if (!_available) return;
    final keyPtr = key.toNativeUtf8();
    try {
      bindings.cu_keyboard_key_tap(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Tap a key with modifiers
  ///
  /// Valid modifiers: "cmd", "alt", "control", "shift", "meta", "fn"
  /// The C library expects comma-separated modifiers and handles main thread dispatch internally.
  static void tapWithModifiers(String key, List<String> modifiers) {
    if (!_available) {
      throw StateError('Nutdart bindings not available');
    }

    if (key.isEmpty) {
      throw ArgumentError('Key cannot be empty');
    }

    // If no modifiers, just use regular tap
    if (modifiers.isEmpty) {
      tap(key);
      return;
    }

    // Validate modifiers
    const validModifiers = {
      'cmd',
      'alt',
      'control',
      'shift',
      'meta',
      'fn',
      'win',
    };
    for (final modifier in modifiers) {
      if (!validModifiers.contains(modifier.toLowerCase())) {
        throw ArgumentError(
          'Invalid modifier: $modifier. Valid modifiers: ${validModifiers.join(", ")}',
        );
      }
    }

    // The C library parseKeyFlags function expects comma-separated modifiers
    final modifierString = modifiers.join(',');

    final keyPtr = key.toNativeUtf8();
    final flagsPtr = modifierString.toNativeUtf8();
    try {
      bindings.cu_keyboard_key_tap_with_flags(
        keyPtr.cast<Char>(),
        flagsPtr.cast<Char>(),
      );
    } finally {
      ffi.malloc.free(keyPtr);
      ffi.malloc.free(flagsPtr);
    }
  }

  /// Type a string
  static void type(String text) {
    if (!_available) return;
    final textPtr = text.toNativeUtf8();
    try {
      bindings.cu_keyboard_type_string(textPtr.cast<Char>());
    } finally {
      ffi.malloc.free(textPtr);
    }
  }

  /// Press and hold a key
  static void keyDown(String key) {
    if (!_available) return;
    final keyPtr = key.toNativeUtf8();
    try {
      bindings.cu_keyboard_key_down(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Release a key
  static void keyUp(String key) {
    if (!_available) return;
    final keyPtr = key.toNativeUtf8();
    try {
      bindings.cu_keyboard_key_up(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Common key combinations
  static void copy() => tapWithModifiers('c', ['cmd']);
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
    if (!_available) return const Size(0, 0);
    final size = bindings.cu_screen_get_size();
    return Size(size.width, size.height);
  }

  /// Capture entire screen
  static Uint8List? capture({
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality = 80,
  }) {
    if (!_available) return null;
    return _captureScreen(
      maxSmallDimension: maxSmallDimension,
      maxLargeDimension: maxLargeDimension,
      quality: quality,
    );
  }

  /// Capture region of screen
  static Uint8List? captureRegion(
    int x,
    int y,
    int width,
    int height, {
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality = 80,
  }) {
    if (!_available) return null;
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
    if (!_available) return null;

    // If resize parameters are provided, use the JPEG functions
    if (maxSmallDimension != null || maxLargeDimension != null) {
      final sizePtr = ffi.malloc<Int64>();
      try {
        Pointer<Uint8> jpegPtr;

        if (x != null && y != null && width != null && height != null) {
          jpegPtr = bindings.cu_screen_capture_region_jpeg(
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
          jpegPtr = bindings.cu_screen_capture_full_jpeg(
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

        bindings.cu_screen_free_jpeg(jpegPtr);

        return data;
      } finally {
        ffi.malloc.free(sizePtr);
      }
    }

    // Fallback to original bitmap method
    Pointer<CUBitmap> bitmapPtr;

    if (x != null && y != null && width != null && height != null) {
      bitmapPtr = bindings.cu_screen_capture_region(x, y, width, height);
    } else {
      bitmapPtr = bindings.cu_screen_capture_full();
    }

    if (bitmapPtr == nullptr) {
      return null;
    }

    final bitmap = bitmapPtr.ref;
    final dataSize = bitmap.bytewidth * bitmap.height;
    final data = Uint8List.fromList(bitmap.data.asTypedList(dataSize));

    bindings.cu_screen_free_capture(bitmapPtr);

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
