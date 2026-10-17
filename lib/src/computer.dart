import 'dart:typed_data';

import 'nutdart_model.dart';

/// Why an active control session ended.
enum ComputerSessionEnd {
  /// The app stopped or closed the session.
  stopped,

  /// The desktop closed the session, for example from its sharing indicator.
  revoked,

  /// The screen saver or lock screen became active.
  locked,

  /// The user session is logging out or ending.
  sessionEnding,

  /// The desktop closed the lock monitor, so locks can no longer be detected.
  monitorLost,
}

/// An implementation cannot do the requested action. Return the message to
/// the caller; do not substitute a different action.
class ComputerActionUnsupported implements Exception {
  /// The interface method, for example `cursorPosition`.
  final String action;
  final String reason;
  const ComputerActionUnsupported(this.action, this.reason);
  @override
  String toString() => 'Unsupported computer action $action: $reason';
}

/// Encoded screenshot bytes.
class ComputerScreenshot {
  final Uint8List bytes;

  /// `image/jpeg` or `image/png`.
  final String mimeType;
  const ComputerScreenshot(this.bytes, this.mimeType);
}

/// A pointer position in [Computer] coordinates.
class CursorPosition {
  final Point point;

  /// True when the desktop cannot report the pointer, and [point] is the last
  /// position that this client set. The user can have moved the pointer since.
  final bool isLastSet;
  const CursorPosition(this.point, {required this.isLastSet});
}

/// Mouse, keyboard, and screen control of one desktop.
///
/// Coordinates are in the units of [screenSize]. Await each call before the
/// next one. Implementations:
/// - `NativeComputer`: the synchronous `Mouse`, `Keyboard`, and `Screen` API
///   (macOS, Windows, Linux X11). Always active.
/// - `PortalComputerUse` (`package:nutdart/nutdart_portal.dart`): a Linux
///   desktop portal session. Active only after the user approves it.
///
/// A method that an implementation cannot do throws
/// [ComputerActionUnsupported]. Methods on an inactive session throw
/// [StateError].
abstract interface class Computer {
  bool get isActive;

  /// One event each time an active session ends. Never fires for an
  /// implementation that is always active.
  Stream<ComputerSessionEnd> get ended;

  /// The coordinate space for input, or null when inactive.
  Size? get screenSize;

  /// Capture the screen. `NativeComputer` resizes within the limits and
  /// returns JPEG, or null if capture fails. `PortalComputerUse` ignores the
  /// limits and returns the full stream frame as PNG; the caller resizes it.
  Future<ComputerScreenshot?> screenshot({
    required int maxSmallDimension,
    required int maxLargeDimension,
    int quality = 80,
  });

  Future<void> moveTo(int x, int y);
  Future<void> press([MouseButton button = MouseButton.left]);
  Future<void> release([MouseButton button = MouseButton.left]);
  Future<void> click([MouseButton button = MouseButton.left]);
  Future<void> clickAt(int x, int y, [MouseButton button = MouseButton.left]);
  Future<void> doubleClick([MouseButton button = MouseButton.left]);
  Future<void> doubleClickAt(
    int x,
    int y, [
    MouseButton button = MouseButton.left,
  ]);
  Future<void> drag(
    Point from,
    Point to, [
    MouseButton button = MouseButton.left,
  ]);

  /// Positive [deltaY] scrolls up. Positive [deltaX] scrolls right.
  /// `NativeComputer` passes the values to the native scroll function.
  /// `PortalComputerUse` sends one wheel step per unit, at most 1000.
  Future<void> scroll(int deltaX, int deltaY);

  Future<CursorPosition> cursorPosition();

  /// Tap a named key, such as `return` or `a`.
  Future<void> tap(String key);

  /// Hold [modifiers] (`cmd`, `alt`, `control`, `shift`, `meta`, `win`),
  /// tap [key], then release the modifiers.
  Future<void> tapWithModifiers(String key, List<String> modifiers);
  Future<void> keyDown(String key);
  Future<void> keyUp(String key);
  Future<void> type(String text);
}
