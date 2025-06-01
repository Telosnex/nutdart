// Desktop/FFI implementation of the Nutdart API.
// This file is only included when `dart.library.ffi` is available.  On
// platforms where the native shared library cannot be loaded (e.g. Android,
// iOS) the `_bindings` variable will be `null`, and all public methods will
// silently become no-ops.

import 'dart:ffi';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:ffi/ffi.dart' as ffi;
import 'package:nutdart/src/nutdart_model.dart';

import '../nutdart_bindings_generated.dart';

const String _libName = 'nutdart';

// Try to load the dynamic library.  If this fails we return `null` so the rest
// of the file can gracefully degrade into no-ops.
DynamicLibrary? _tryOpenDynamicLibrary() {
  try {
    if (Platform.isMacOS) {
      return DynamicLibrary.open('$_libName.framework/$_libName');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('$_libName.dll');
    }
    if (Platform.isLinux) {
      return DynamicLibrary.open('lib$_libName.so');
    }
    // Mobile or other platforms – not supported.
    return null;
  } on Object {
    // Any error while loading results in a null library.
    return null;
  }
}

// Load library and bindings lazily and safely
DynamicLibrary? _dylib;
NutdartBindings? _bindings;
bool _initialized = false;

void _tryInit() {
  if (_initialized) return;
  _initialized = true;
  try {
    _dylib = _tryOpenDynamicLibrary();
    if (_dylib != null) {
      _bindings = NutdartBindings(_dylib!);
    }
  } on Object {
    // Any error results in null bindings
    _dylib = null;
    _bindings = null;
  }
}

bool get _available {
  _tryInit();
  return _bindings != null;
}

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
    _tryInit();
    _bindings?.cu_mouse_move(x, y);
  }

  /// Move mouse to a Point
  static void moveToPoint(Point point) {
    moveTo(point.x, point.y);
  }

  /// Click mouse button at current position
  static void click([MouseButton button = MouseButton.left]) {
    _tryInit();
    _bindings?.cu_mouse_click(_mouseButtonValue(button));
  }

  /// Click mouse button at specified coordinates
  static void clickAt(int x, int y, [MouseButton button = MouseButton.left]) {
    moveTo(x, y);
    click(button);
  }

  /// Click mouse button at a Point
  static void clickAtPoint(Point point, [MouseButton button = MouseButton.left]) {
    clickAt(point.x, point.y, button);
  }

  /// Double-click mouse button
  static void doubleClick([MouseButton button = MouseButton.left]) {
    _tryInit();
    _bindings?.cu_mouse_double_click(_mouseButtonValue(button));
  }

  /// Double-click at specified coordinates
  static void doubleClickAt(int x, int y, [MouseButton button = MouseButton.left]) {
    moveTo(x, y);
    doubleClick(button);
  }

  /// Drag from one point to another
  static void drag(Point from, Point to, [MouseButton button = MouseButton.left]) {
    _tryInit();
    _bindings?.cu_mouse_drag(from.x, from.y, to.x, to.y, _mouseButtonValue(button));
  }

  /// Scroll mouse wheel
  static void scroll(int deltaX, int deltaY) {
    _tryInit();
    _bindings?.cu_mouse_scroll(deltaX, deltaY);
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
    _tryInit();
    if (_bindings == null) return const Point(0, 0);
    final pos = _bindings!.cu_mouse_get_position();
    return Point(pos.x, pos.y);
  }

  /// Press and hold mouse button
  static void press([MouseButton button = MouseButton.left]) {
    _tryInit();
    _bindings?.cu_mouse_toggle(1, _mouseButtonValue(button));
  }

  /// Release mouse button
  static void release([MouseButton button = MouseButton.left]) {
    _tryInit();
    _bindings?.cu_mouse_toggle(0, _mouseButtonValue(button));
  }
}

/// Keyboard operations
class Keyboard {
  Keyboard._();

  /// Tap a key
  static void tap(String key) {
    _tryInit();
    if (_bindings == null) return;
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings!.cu_keyboard_key_tap(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Tap a key with modifiers
  static void tapWithModifiers(String key, List<String> modifiers) {
    _tryInit();
    if (_bindings == null) return;
    final modifierString = modifiers.join(',');
    final keyPtr = key.toNativeUtf8();
    final flagsPtr = modifierString.toNativeUtf8();
    try {
      _bindings!.cu_keyboard_key_tap_with_flags(
          keyPtr.cast<Char>(), flagsPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
      ffi.malloc.free(flagsPtr);
    }
  }

  /// Type a string
  static void type(String text) {
    _tryInit();
    if (_bindings == null) return;
    final textPtr = text.toNativeUtf8();
    try {
      _bindings!.cu_keyboard_type_string(textPtr.cast<Char>());
    } finally {
      ffi.malloc.free(textPtr);
    }
  }

  /// Press and hold a key
  static void keyDown(String key) {
    _tryInit();
    if (_bindings == null) return;
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings!.cu_keyboard_key_down(keyPtr.cast<Char>());
    } finally {
      ffi.malloc.free(keyPtr);
    }
  }

  /// Release a key
  static void keyUp(String key) {
    _tryInit();
    if (_bindings == null) return;
    final keyPtr = key.toNativeUtf8();
    try {
      _bindings!.cu_keyboard_key_up(keyPtr.cast<Char>());
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
    _tryInit();
    if (_bindings == null) return const Size(0, 0);
    final size = _bindings!.cu_screen_get_size();
    return Size(size.width, size.height);
  }

  /// Capture entire screen
  static Uint8List? capture({int? maxSmallDimension, int? maxLargeDimension, int quality = 80}) {
    _tryInit();
    if (_bindings == null) return null;
    return _captureScreen(
      maxSmallDimension: maxSmallDimension,
      maxLargeDimension: maxLargeDimension,
      quality: quality,
    );
  }

  /// Capture region of screen
  static Uint8List? captureRegion(int x, int y, int width, int height,
      {int? maxSmallDimension, int? maxLargeDimension, int quality = 80}) {
    _tryInit();
    if (_bindings == null) return null;
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

  static Uint8List? _captureScreen({int? x, int? y, int? width, int? height, int? maxSmallDimension, int? maxLargeDimension, int quality = 80}) {
    if (_bindings == null) return null;

    // If resize parameters are provided, use the JPEG functions
    if (maxSmallDimension != null || maxLargeDimension != null) {
      final sizePtr = ffi.malloc<Int64>();
      try {
        Pointer<Uint8> jpegPtr;

        if (x != null && y != null && width != null && height != null) {
          jpegPtr = _bindings!.cu_screen_capture_region_jpeg(
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
          jpegPtr = _bindings!.cu_screen_capture_full_jpeg(
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

        _bindings!.cu_screen_free_jpeg(jpegPtr);

        return data;
      } finally {
        ffi.malloc.free(sizePtr);
      }
    }

    // Fallback to original bitmap method
    Pointer<CUBitmap> bitmapPtr;

    if (x != null && y != null && width != null && height != null) {
      bitmapPtr = _bindings!.cu_screen_capture_region(x, y, width, height);
    } else {
      bitmapPtr = _bindings!.cu_screen_capture_full();
    }

    if (bitmapPtr == nullptr) {
      return null;
    }

    final bitmap = bitmapPtr.ref;
    final dataSize = bitmap.bytewidth * bitmap.height;
    final data = Uint8List.fromList(bitmap.data.asTypedList(dataSize));

    _bindings!.cu_screen_free_capture(bitmapPtr);

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