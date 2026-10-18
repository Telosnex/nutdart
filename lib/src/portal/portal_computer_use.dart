import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

import '../computer.dart';
import '../nutdart_model.dart';
import 'portal_keys.dart';
import 'portal_transport.dart';
import 'xkb_layout.dart';
import 'pipewire_frames.dart';
import 'portal_frame.dart';

export 'portal_frame.dart';
export 'portal_keys.dart' show portalKeysym, parsePortalKeyCombo;

export 'portal_transport.dart' show PortalResponseException;

/// The portal name for [ComputerSessionEnd].
typedef PortalSessionEnd = ComputerSessionEnd;

/// The desktop cannot report screen locks (Inhibit monitor unavailable).
class PortalLockMonitorUnavailable implements Exception {
  final Object cause;
  const PortalLockMonitorUnavailable(this.cause);
  @override
  String toString() => 'Desktop portal cannot report screen locks: $cause';
}

/// A user-approved Linux remote desktop session.
/// Coordinates are local to the single shared monitor, in portal logical units.
/// Screenshots contain encoded PNG bytes, not the legacy API's raw bitmap.
/// No window enumeration or global pointer-position query exists in this API.
///
/// The session ends when the app stops it, the desktop revokes it, the screen
/// locks, or the user session ends. [ended] reports the reason. Keys and
/// buttons that are still pressed are released when the app stops a session.
///
/// As a [Computer]: [screenshot] returns the full stream frame as PNG;
/// [cursorPosition] returns the last position this client set, because the
/// portal cannot report the pointer; composite actions are built from button
/// and motion events.
class PortalComputerUse implements Computer {
  final PortalTransport _transport;

  /// When true, [start] fails unless the desktop provides an Inhibit monitor
  /// to report screen locks.
  final bool requireLockMonitor;
  String? _session;
  String? _monitor;
  StreamSubscription<void>? _closed;
  StreamSubscription<void>? _monitorClosed;
  bool _disposed = false;
  Future<void>? _closing;
  bool _starting = false;
  PortalSessionEnd? _startAbort;
  Future<void>? _ending;
  int? _streamNode;
  Size? _size;
  Object _identity = Object();
  Future<PortalFrameSource>? _frames;
  Future<void> _closingFrames = Future.value();
  final Future<PortalFrameSource> Function(int, int) _openFrames;
  final _heldKeysyms = <int>[];
  final _heldButtons = <int>[];
  Point? _lastSet;
  final _ended = StreamController<PortalSessionEnd>.broadcast();
  final Future<XkbKeysyms> Function() _activeLayout;

  PortalComputerUse({
    Duration consentTimeout = const Duration(minutes: 3),
    this.requireLockMonitor = true,
  }) : _transport = DBusPortalTransport(timeout: consentTimeout),
       _openFrames = PipeWireFrames.open,
       _activeLayout = activeGnomeKeysyms {
    if (!Platform.isLinux) {
      throw UnsupportedError('Desktop portals require Linux');
    }
  }

  /// Internal transport injection for tests.
  PortalComputerUse.withTransport(
    this._transport, {
    Future<PortalFrameSource> Function(int, int)? openFrames,
    this.requireLockMonitor = true,
    Future<XkbKeysyms> Function()? activeLayout,
  }) : _openFrames = openFrames ?? PipeWireFrames.open,
       _activeLayout = activeLayout ?? activeGnomeKeysyms;

  @override
  bool get isActive => _session != null && _streamNode != null && !_disposed;
  Size? get sharedSize => isActive ? _size : null;

  @override
  Size? get screenSize => sharedSize;

  /// Whether the desktop reports screen locks for the active session.
  bool get lockMonitored => isActive && _monitor != null;

  /// One event each time an active session ends.
  @override
  Stream<PortalSessionEnd> get ended => _ended.stream;

  void _checkOpen() {
    if (_disposed) throw StateError('Portal client is closed');
  }

  /// Request keyboard, pointer, and one monitor. Call from a user action.
  /// Throws if the user shares a screen without allowing remote interaction,
  /// if the screen locks before approval, or with
  /// [PortalLockMonitorUnavailable] when [requireLockMonitor] is set and the
  /// desktop cannot report locks.
  Future<void> start({String parentWindow = ''}) async {
    _checkOpen();
    if (_starting || _session != null) {
      throw StateError('A portal session is already open or starting');
    }
    _starting = true;
    _startAbort = null;
    try {
      await _ending;
      await _closeFrames();
      final identity = _identity = Object();
      await _startMonitor(identity);
      _checkStartAbort();
      final created = await _transport
          .request('RemoteDesktop', 'CreateSession', [], {
            'session_handle_token': DBusString(
              'nutdart_session_${DateTime.now().microsecondsSinceEpoch}',
            ),
          });
      final path = created['session_handle']!.asString();
      _session = path;
      _closed = _transport
          .closed(path)
          .listen(
            (_) => _desktopEnd(identity, PortalSessionEnd.revoked),
            onError: (Object _) =>
                _desktopEnd(identity, PortalSessionEnd.revoked),
            onDone: () => _desktopEnd(identity, PortalSessionEnd.revoked),
          );
      final session = DBusObjectPath(path);
      await _transport.request(
        'RemoteDesktop',
        'SelectDevices',
        [session],
        {'types': const DBusUint32(3)},
      );
      await _transport.request(
        'ScreenCast',
        'SelectSources',
        [session],
        {'types': const DBusUint32(1), 'multiple': const DBusBoolean(false)},
      );
      _checkStartAbort();
      final result = await _transport.request('RemoteDesktop', 'Start', [
        session,
        DBusString(parentWindow),
      ], {});
      final devices = result['devices']?.asUint32() ?? 0;
      if ((devices & 3) != 3) {
        throw StateError(
          'Enable remote interaction to grant keyboard and pointer access',
        );
      }
      final streams = result['streams']!.asArray().toList();
      if (streams.length != 1) throw StateError('Expected one shared monitor');
      final stream = streams.single.asStruct();
      final props = stream[1].asStringVariantDict();
      final size = props['size']?.asStruct();
      if (size == null || size.length != 2) {
        throw StateError('Portal did not provide monitor coordinates');
      }
      final width = size[0].asInt32(), height = size[1].asInt32();
      if (width <= 0 || height <= 0) {
        throw StateError('Invalid shared monitor size');
      }
      _checkStartAbort();
      if (_disposed || !identical(identity, _identity)) {
        throw StateError('Portal session was revoked');
      }
      _streamNode = stream[0].asUint32();
      _size = Size(width, height);
    } catch (_) {
      await _endSession(PortalSessionEnd.stopped);
      rethrow;
    } finally {
      _starting = false;
      _startAbort = null;
    }
  }

  void _checkStartAbort() {
    final reason = _startAbort;
    if (reason != null) {
      throw StateError('Portal session ended: ${reason.name}');
    }
  }

  Future<void> _startMonitor(Object identity) async {
    final String monitor;
    try {
      monitor = await _transport.createStateMonitor(
        (_, state) => _onState(identity, state),
      );
    } catch (error) {
      if (requireLockMonitor) throw PortalLockMonitorUnavailable(error);
      return;
    }
    if (!identical(identity, _identity)) {
      try {
        await _transport.closeSession(monitor);
      } catch (_) {}
      return;
    }
    _monitor = monitor;
    void lost() {
      if (requireLockMonitor) {
        _desktopEnd(identity, PortalSessionEnd.monitorLost);
      } else if (identical(identity, _identity)) {
        _monitor = null;
      }
    }

    _monitorClosed = _transport
        .closed(monitor)
        .listen((_) => lost(), onError: (Object _) => lost(), onDone: lost);
  }

  void _onState(Object identity, Map<String, DBusValue> state) {
    if (!identical(identity, _identity)) return;
    final phase = state['session-state']?.asUint32();
    if (phase == 2) {
      final monitor = _monitor;
      if (monitor != null) {
        unawaited(
          _transport.queryEndResponse(monitor).catchError((Object _) {}),
        );
      }
    }
    if (phase == 2 || phase == 3) {
      _desktopEnd(identity, PortalSessionEnd.sessionEnding);
    } else if (state['screensaver-active']?.asBoolean() == true) {
      _desktopEnd(identity, PortalSessionEnd.locked);
    }
  }

  void _desktopEnd(Object identity, PortalSessionEnd reason) {
    if (!identical(identity, _identity)) return;
    if (_starting) {
      _startAbort ??= reason;
      return;
    }
    unawaited(_endSession(reason));
  }

  /// One still image. Consent can be separate from remote-control consent.
  /// The desktop-owned screenshot file is not deleted by this client.
  /// Computer use should call [captureFrame] instead.
  Future<Uint8List> capture({String parentWindow = ''}) async {
    _checkOpen();
    final result = await _transport.request(
      'Screenshot',
      'Screenshot',
      [DBusString(parentWindow)],
      {'interactive': const DBusBoolean(false)},
    );
    final uri = Uri.parse(result['uri']!.asString());
    if (uri.scheme != 'file' ||
        (uri.host.isNotEmpty && uri.host != 'localhost')) {
      throw StateError('Portal returned a non-local screenshot URI');
    }
    return File.fromUri(uri).readAsBytes();
  }

  /// Capture PNG pixels from the same monitor used for pointer input.
  /// Opens the stream lazily. The caller must await captures and input in order.
  /// With [fresh], discard samples timestamped before this capture's native
  /// boundary. This does not prove that an application processed earlier input.
  /// A static desktop can time out. Await input first and verify the image.
  Future<PortalFrame> captureFrame({bool fresh = false}) async {
    if (!isActive) throw StateError('No approved remote desktop session');
    final identity = _identity, session = _session!, node = _streamNode!;
    final size = _size!;
    final opening = _frames ??= () async {
      final fd = await _transport.openPipeWire(session);
      return _openFrames(fd, node);
    }();
    try {
      final source = await opening;
      if (!isActive || !identical(identity, _identity)) {
        throw StateError('Portal session was revoked');
      }
      final pixels = await source.capture(fresh: fresh);
      if (!isActive || !identical(identity, _identity)) {
        throw StateError('Portal session was revoked');
      }
      if (fresh &&
          (pixels.runningTimeNs == null ||
              pixels.boundaryNs == null ||
              pixels.runningTimeNs! <= pixels.boundaryNs!)) {
        throw StateError('Frame does not satisfy the fresh capture boundary');
      }
      return PortalFrame.fromPng(
        pixels.png,
        size,
        identity,
        runningTimeNs: pixels.runningTimeNs,
        boundaryNs: pixels.boundaryNs,
      );
    } catch (_) {
      if (identical(_frames, opening)) await _closeFrames();
      rethrow;
    }
  }

  /// Move to a pixel in an original or resized (not cropped) stream frame.
  Future<void> moveToFrame(
    PortalFrame frame,
    double x,
    double y, {
    Size? imageSize,
  }) {
    if (!isActive || !identical(frame.sessionIdentity, _identity)) {
      throw StateError('Frame belongs to an inactive or different session');
    }
    final point = frame.logicalPoint(x, y, imageSize: imageSize);
    _lastSet = Point(point.x.round(), point.y.round());
    return _input('NotifyPointerMotionAbsolute', [
      DBusUint32(_streamNode!),
      DBusDouble(point.x),
      DBusDouble(point.y),
    ]);
  }

  Future<void> _closeFrames() {
    final opening = _frames;
    _frames = null;
    if (opening != null) {
      _closingFrames = _closingFrames.then((_) async {
        try {
          await (await opening).close();
        } catch (_) {}
      });
    }
    return _closingFrames;
  }

  Future<void> _input(String method, List<DBusValue> values) {
    if (!isActive) throw StateError('No approved remote desktop session');
    return _transport.notify(method, [
      DBusObjectPath(_session!),
      DBusDict.stringVariant({}),
      ...values,
    ]);
  }

  @override
  Future<void> moveTo(int x, int y) {
    if (!isActive) throw StateError('No approved remote desktop session');
    final size = _size!;
    if (x < 0 || y < 0 || x >= size.width || y >= size.height) {
      throw RangeError('Pointer coordinates are outside the shared monitor');
    }
    _lastSet = Point(x, y);
    return _input('NotifyPointerMotionAbsolute', [
      DBusUint32(_streamNode!),
      DBusDouble(x.toDouble()),
      DBusDouble(y.toDouble()),
    ]);
  }

  Future<void> button(MouseButton button, {required bool pressed}) async {
    final code = switch (button) {
      MouseButton.left => 0x110,
      MouseButton.right => 0x111,
      MouseButton.middle => 0x112,
    };
    await _input('NotifyPointerButton', [
      DBusInt32(code),
      DBusUint32(pressed ? 1 : 0),
    ]);
    _heldButtons.remove(code);
    if (pressed) _heldButtons.add(code);
  }

  @override
  Future<void> click([MouseButton mouseButton = MouseButton.left]) async {
    await button(mouseButton, pressed: true);
    await button(mouseButton, pressed: false);
  }

  @override
  Future<void> press([MouseButton mouseButton = MouseButton.left]) =>
      button(mouseButton, pressed: true);

  @override
  Future<void> release([MouseButton mouseButton = MouseButton.left]) =>
      button(mouseButton, pressed: false);

  @override
  Future<void> clickAt(
    int x,
    int y, [
    MouseButton mouseButton = MouseButton.left,
  ]) async {
    await moveTo(x, y);
    await click(mouseButton);
  }

  /// Two clicks. The desktop decides whether they form a double-click.
  @override
  Future<void> doubleClick([MouseButton mouseButton = MouseButton.left]) async {
    await click(mouseButton);
    await click(mouseButton);
  }

  @override
  Future<void> doubleClickAt(
    int x,
    int y, [
    MouseButton mouseButton = MouseButton.left,
  ]) async {
    await moveTo(x, y);
    await doubleClick(mouseButton);
  }

  /// Button down at [from], motion to [to], button up. Both points are
  /// checked before any input. The button is released if the motion fails.
  @override
  Future<void> drag(
    Point from,
    Point to, [
    MouseButton mouseButton = MouseButton.left,
  ]) async {
    if (!isActive) throw StateError('No approved remote desktop session');
    final size = _size!;
    for (final p in [from, to]) {
      if (p.x < 0 || p.y < 0 || p.x >= size.width || p.y >= size.height) {
        throw RangeError('Pointer coordinates are outside the shared monitor');
      }
    }
    await moveTo(from.x, from.y);
    await press(mouseButton);
    try {
      await moveTo(to.x, to.y);
    } finally {
      // An ended session releases held buttons itself.
      if (isActive) await release(mouseButton);
    }
  }

  /// The last position that this client set in this session. The portal
  /// cannot report the pointer, so [CursorPosition.isLastSet] is true.
  @override
  Future<CursorPosition> cursorPosition() async {
    if (!isActive) throw StateError('No approved remote desktop session');
    final point = _lastSet;
    if (point == null) {
      throw const ComputerActionUnsupported(
        'cursorPosition',
        'the desktop portal cannot report the pointer, and this session has '
            'not moved it yet',
      );
    }
    return CursorPosition(point, isLastSet: true);
  }

  /// [Computer] scroll: positive [deltaY] scrolls up, positive [deltaX]
  /// scrolls right. One wheel step per unit. See [scrollSteps].
  @override
  Future<void> scroll(int deltaX, int deltaY) =>
      scrollSteps(vertical: -deltaY, horizontal: deltaX);

  /// Scroll by wheel steps at the current pointer position.
  /// Positive [vertical] scrolls down. Positive [horizontal] scrolls right.
  /// Each value must be in -1000..1000.
  Future<void> scrollSteps({int vertical = 0, int horizontal = 0}) async {
    for (final steps in [vertical, horizontal]) {
      if (steps < -1000 || steps > 1000) {
        throw RangeError.range(steps, -1000, 1000, 'steps');
      }
    }
    if (!isActive) throw StateError('No approved remote desktop session');
    // Mutter rejects zero steps, so skip an unused axis.
    if (vertical != 0) {
      await _input('NotifyPointerAxisDiscrete', [
        const DBusUint32(0),
        DBusInt32(vertical),
      ]);
    }
    if (horizontal != 0) {
      await _input('NotifyPointerAxisDiscrete', [
        const DBusUint32(1),
        DBusInt32(horizontal),
      ]);
    }
  }

  /// Send an XKB keysym. State 1 presses the key. State 0 releases it.
  Future<void> keysym(int value, {required bool pressed}) async {
    if (value < 0 || value > 0x1fffffff) {
      throw RangeError.value(value, 'keysym');
    }
    await _input('NotifyKeyboardKeysym', [
      DBusInt32(value),
      DBusUint32(pressed ? 1 : 0),
    ]);
    _heldKeysyms.remove(value);
    if (pressed) _heldKeysyms.add(value);
  }

  Future<void> tapKeysym(int value) async {
    await keysym(value, pressed: true);
    await keysym(value, pressed: false);
  }

  /// Press or release a named key. See [portalKeysym] for names.
  Future<void> key(String name, {required bool pressed}) =>
      keysym(portalKeysym(name), pressed: pressed);

  /// Press a key combination such as `ctrl+shift+n`, then release it in
  /// reverse order. Unknown names throw before any key is pressed.
  Future<void> tapKeys(String combo) => _tapKeysyms(parsePortalKeyCombo(combo));

  @override
  Future<void> tap(String key) => tapKeysym(portalKeysym(key));

  /// Unknown names throw before any key is pressed.
  @override
  Future<void> tapWithModifiers(String key, List<String> modifiers) {
    if (key.isEmpty) throw ArgumentError('Key cannot be empty');
    return _tapKeysyms([...modifiers.map(portalKeysym), portalKeysym(key)]);
  }

  @override
  Future<void> keyDown(String key) => this.key(key, pressed: true);

  @override
  Future<void> keyUp(String key) => this.key(key, pressed: false);

  /// Full stream frame as PNG. The size limits do not apply; the caller
  /// resizes. Throws [StateError] when the session is inactive.
  @override
  Future<ComputerScreenshot?> screenshot({
    required int maxSmallDimension,
    required int maxLargeDimension,
    int quality = 80,
  }) async => ComputerScreenshot((await captureFrame()).png, 'image/png');

  Future<void> _tapKeysyms(List<int> keysyms) async {
    final pressed = <int>[];
    try {
      for (final value in keysyms) {
        await keysym(value, pressed: true);
        pressed.add(value);
      }
    } finally {
      // An ended session releases held keys itself.
      for (final value in pressed.reversed) {
        if (!isActive) break;
        await keysym(value, pressed: false);
      }
    }
  }

  /// Send text as keysyms. This is not clipboard paste or an input-method API.
  @override
  Future<void> type(String text) async {
    final keysyms = text.runes.map(keysymForRune).toList();
    for (final value in keysyms) {
      await tapKeysym(value);
    }
  }

  /// [type] for GNOME. Mutter drops any keysym that is not on the active
  /// layout, and the portal call still succeeds. This checks every
  /// character against the active layout first and sends nothing if any
  /// is missing ([ComputerActionUnsupported] names them).
  Future<void> typeOnActiveLayout(String text) async {
    if (!isActive) throw StateError('No approved remote desktop session');
    final keysyms = resolveTypeKeysyms(text, await _activeLayout());
    for (final value in keysyms) {
      await tapKeysym(value);
    }
  }

  /// End the control session and keep the client for a later [start].
  Future<void> stop() {
    if (_starting) {
      return Future.error(StateError('Wait for start() before stopping'));
    }
    return _endSession(PortalSessionEnd.stopped);
  }

  Future<void> _endSession(PortalSessionEnd reason) =>
      _ending ??= _doEnd(reason).whenComplete(() => _ending = null);

  Future<void> _doEnd(PortalSessionEnd reason) async {
    // Clear state before the first await so that no new input is accepted.
    final wasActive = _session != null && _streamNode != null;
    final path = _session, monitor = _monitor;
    final keys = [..._heldKeysyms], buttons = [..._heldButtons];
    _session = null;
    _monitor = null;
    _streamNode = null;
    _size = null;
    _identity = Object();
    _heldKeysyms.clear();
    _heldButtons.clear();
    _lastSet = null;
    final closed = _closed, monitorClosed = _monitorClosed;
    _closed = null;
    _monitorClosed = null;
    if (path != null && reason != PortalSessionEnd.revoked) {
      for (final (method, values) in [
        for (final code in buttons.reversed)
          ('NotifyPointerButton', [DBusInt32(code), const DBusUint32(0)]),
        for (final value in keys.reversed)
          ('NotifyKeyboardKeysym', [DBusInt32(value), const DBusUint32(0)]),
      ]) {
        try {
          await _transport.notify(method, [
            DBusObjectPath(path),
            DBusDict.stringVariant({}),
            ...values,
          ]);
        } catch (_) {}
      }
    }
    await _closeFrames();
    await closed?.cancel();
    await monitorClosed?.cancel();
    for (final handle in [path, monitor]) {
      if (handle == null) continue;
      try {
        await _transport.closeSession(handle);
      } catch (_) {}
    }
    if (wasActive && !_ended.isClosed) _ended.add(reason);
  }

  /// Release consent and close the bus connection. Safe to call more than once.
  Future<void> close() {
    if (_starting) {
      return Future.error(
        StateError('Wait for start() before closing the client'),
      );
    }
    return _closing ??= _close();
  }

  Future<void> _close() async {
    if (_disposed) return;
    _disposed = true;
    await _endSession(PortalSessionEnd.stopped);
    await _transport.close();
    await _ended.close();
  }
}
