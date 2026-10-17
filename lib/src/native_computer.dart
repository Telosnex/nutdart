import 'dart:typed_data';

import 'computer.dart';
import 'nutdart_model.dart';
import 'nutdart_stub.dart' if (dart.library.ffi) 'nutdart_real.dart';

/// The native functions that [NativeComputer] calls. Tests replace them.
class NativeComputerCalls {
  final void Function(int x, int y) moveTo;
  final void Function(MouseButton button) press;
  final void Function(MouseButton button) release;
  final void Function(MouseButton button) click;
  final void Function(int x, int y, MouseButton button) clickAt;
  final void Function(MouseButton button) doubleClick;
  final void Function(int x, int y, MouseButton button) doubleClickAt;
  final void Function(Point from, Point to, MouseButton button) drag;
  final void Function(int deltaX, int deltaY) scroll;
  final Point Function() getPosition;
  final void Function(String key) tap;
  final void Function(String key, List<String> modifiers) tapWithModifiers;
  final void Function(String key) keyDown;
  final void Function(String key) keyUp;
  final void Function(String text) type;
  final Size Function() getSize;
  final Uint8List? Function({
    int? maxSmallDimension,
    int? maxLargeDimension,
    int quality,
  })
  capture;

  const NativeComputerCalls({
    required this.moveTo,
    required this.press,
    required this.release,
    required this.click,
    required this.clickAt,
    required this.doubleClick,
    required this.doubleClickAt,
    required this.drag,
    required this.scroll,
    required this.getPosition,
    required this.tap,
    required this.tapWithModifiers,
    required this.keyDown,
    required this.keyUp,
    required this.type,
    required this.getSize,
    required this.capture,
  });

  static const platform = NativeComputerCalls(
    moveTo: Mouse.moveTo,
    press: Mouse.press,
    release: Mouse.release,
    click: Mouse.click,
    clickAt: Mouse.clickAt,
    doubleClick: Mouse.doubleClick,
    doubleClickAt: Mouse.doubleClickAt,
    drag: Mouse.drag,
    scroll: Mouse.scroll,
    getPosition: Mouse.getPosition,
    tap: Keyboard.tap,
    tapWithModifiers: Keyboard.tapWithModifiers,
    keyDown: Keyboard.keyDown,
    keyUp: Keyboard.keyUp,
    type: Keyboard.type,
    getSize: Screen.getSize,
    capture: Screen.capture,
  );
}

/// [Computer] over the synchronous `Mouse`, `Keyboard`, and `Screen` API.
/// Each method calls one native function with the same arguments. Composite
/// actions use the native composite function; for example, a macOS
/// double-click sends one event with a click count of 2.
class NativeComputer implements Computer {
  final NativeComputerCalls _calls;

  const NativeComputer() : _calls = NativeComputerCalls.platform;

  /// Internal call injection for tests.
  const NativeComputer.withCalls(this._calls);

  @override
  bool get isActive => true;

  @override
  Stream<ComputerSessionEnd> get ended => const Stream.empty();

  @override
  Size get screenSize => _calls.getSize();

  @override
  Future<ComputerScreenshot?> screenshot({
    required int maxSmallDimension,
    required int maxLargeDimension,
    int quality = 80,
  }) async {
    final jpeg = _calls.capture(
      maxSmallDimension: maxSmallDimension,
      maxLargeDimension: maxLargeDimension,
      quality: quality,
    );
    return jpeg == null ? null : ComputerScreenshot(jpeg, 'image/jpeg');
  }

  @override
  Future<void> moveTo(int x, int y) async => _calls.moveTo(x, y);

  @override
  Future<void> press([MouseButton button = MouseButton.left]) async =>
      _calls.press(button);

  @override
  Future<void> release([MouseButton button = MouseButton.left]) async =>
      _calls.release(button);

  @override
  Future<void> click([MouseButton button = MouseButton.left]) async =>
      _calls.click(button);

  @override
  Future<void> clickAt(
    int x,
    int y, [
    MouseButton button = MouseButton.left,
  ]) async => _calls.clickAt(x, y, button);

  @override
  Future<void> doubleClick([MouseButton button = MouseButton.left]) async =>
      _calls.doubleClick(button);

  @override
  Future<void> doubleClickAt(
    int x,
    int y, [
    MouseButton button = MouseButton.left,
  ]) async => _calls.doubleClickAt(x, y, button);

  @override
  Future<void> drag(
    Point from,
    Point to, [
    MouseButton button = MouseButton.left,
  ]) async => _calls.drag(from, to, button);

  @override
  Future<void> scroll(int deltaX, int deltaY) async =>
      _calls.scroll(deltaX, deltaY);

  @override
  Future<CursorPosition> cursorPosition() async =>
      CursorPosition(_calls.getPosition(), isLastSet: false);

  @override
  Future<void> tap(String key) async => _calls.tap(key);

  @override
  Future<void> tapWithModifiers(String key, List<String> modifiers) async =>
      _calls.tapWithModifiers(key, modifiers);

  @override
  Future<void> keyDown(String key) async => _calls.keyDown(key);

  @override
  Future<void> keyUp(String key) async => _calls.keyUp(key);

  @override
  Future<void> type(String text) async => _calls.type(text);
}
