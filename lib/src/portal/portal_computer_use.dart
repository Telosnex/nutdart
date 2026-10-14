import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';

import '../nutdart_model.dart';
import 'portal_transport.dart';
import 'pipewire_frames.dart';
import 'portal_frame.dart';

export 'portal_frame.dart';

export 'portal_transport.dart' show PortalResponseException;

/// A user-approved Linux remote desktop session.
/// Coordinates are local to the single shared monitor, in portal logical units.
/// Screenshots contain encoded PNG bytes, not the legacy API's raw bitmap.
/// No window enumeration or global pointer-position query exists in this API.
class PortalComputerUse {
  final PortalTransport _transport;
  String? _session;
  StreamSubscription<void>? _closed;
  bool _disposed = false;
  Future<void>? _closing;
  bool _starting = false;
  int? _streamNode;
  Size? _size;
  Object _identity = Object();
  Future<PortalFrameSource>? _frames;
  Future<void> _closingFrames = Future.value();
  final Future<PortalFrameSource> Function(int, int) _openFrames;

  PortalComputerUse({Duration consentTimeout = const Duration(minutes: 3)})
    : _transport = DBusPortalTransport(timeout: consentTimeout),
      _openFrames = PipeWireFrames.open {
    if (!Platform.isLinux) {
      throw UnsupportedError('Desktop portals require Linux');
    }
  }

  /// Internal transport injection for tests.
  PortalComputerUse.withTransport(
    this._transport, {
    Future<PortalFrameSource> Function(int, int)? openFrames,
  }) : _openFrames = openFrames ?? PipeWireFrames.open;

  bool get isActive => _session != null && _streamNode != null && !_disposed;
  Size? get sharedSize => isActive ? _size : null;

  void _checkOpen() {
    if (_disposed) throw StateError('Portal client is closed');
  }

  /// Request keyboard, pointer, and one monitor. Call from a user action.
  /// Throws if the user shares a screen without allowing remote interaction.
  Future<void> start({String parentWindow = ''}) async {
    _checkOpen();
    if (_starting || _session != null) {
      throw StateError('A portal session is already open or starting');
    }
    _starting = true;
    try {
      await _closeFrames();
      _identity = Object();
      await _closed?.cancel();
      _closed = null;
      final created = await _transport
          .request('RemoteDesktop', 'CreateSession', [], {
            'session_handle_token': DBusString(
              'nutdart_session_${DateTime.now().microsecondsSinceEpoch}',
            ),
          });
      final path = created['session_handle']!.asString();
      _session = path;
      void revoked() {
        if (_session == path) {
          _session = null;
          _streamNode = null;
          _size = null;
          unawaited(_closeFrames());
        }
      }

      _closed = _transport
          .closed(path)
          .listen(
            (_) => revoked(),
            onError: (Object _) => revoked(),
            onDone: revoked,
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
      if (_session != path || _disposed) {
        throw StateError('Portal session was revoked');
      }
      _streamNode = stream[0].asUint32();
      _size = Size(width, height);
    } catch (_) {
      await _endSession();
      rethrow;
    } finally {
      _starting = false;
    }
  }

  /// One still image. Consent can be separate from remote-control consent.
  /// The desktop-owned screenshot file is not deleted by this client.
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

  Future<void> moveTo(int x, int y) {
    if (!isActive) throw StateError('No approved remote desktop session');
    final size = _size!;
    if (x < 0 || y < 0 || x >= size.width || y >= size.height) {
      throw RangeError('Pointer coordinates are outside the shared monitor');
    }
    return _input('NotifyPointerMotionAbsolute', [
      DBusUint32(_streamNode!),
      DBusDouble(x.toDouble()),
      DBusDouble(y.toDouble()),
    ]);
  }

  Future<void> button(MouseButton button, {required bool pressed}) =>
      _input('NotifyPointerButton', [
        DBusInt32(switch (button) {
          MouseButton.left => 0x110,
          MouseButton.right => 0x111,
          MouseButton.middle => 0x112,
        }),
        DBusUint32(pressed ? 1 : 0),
      ]);

  Future<void> click([MouseButton mouseButton = MouseButton.left]) async {
    await button(mouseButton, pressed: true);
    await button(mouseButton, pressed: false);
  }

  /// Send an XKB keysym. State 1 presses the key. State 0 releases it.
  Future<void> keysym(int value, {required bool pressed}) {
    if (value < 0 || value > 0x1fffffff) {
      throw RangeError.value(value, 'keysym');
    }
    return _input('NotifyKeyboardKeysym', [
      DBusInt32(value),
      DBusUint32(pressed ? 1 : 0),
    ]);
  }

  Future<void> tapKeysym(int value) async {
    await keysym(value, pressed: true);
    await keysym(value, pressed: false);
  }

  /// Send text as keysyms. This is not clipboard paste or an input-method API.
  Future<void> type(String text) async {
    for (final rune in text.runes) {
      final value = switch (rune) {
        10 => 0xff0d, // Return
        9 => 0xff09, // Tab
        < 0x20 => throw ArgumentError('Unsupported control character'),
        <= 0xff => rune,
        _ => 0x01000000 | rune,
      };
      await tapKeysym(value);
    }
  }

  Future<void> _endSession() async {
    final path = _session;
    _session = null;
    _streamNode = null;
    _size = null;
    await _closeFrames();
    await _closed?.cancel();
    _closed = null;
    if (path != null) {
      try {
        await _transport.closeSession(path);
      } catch (_) {}
    }
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
    await _endSession();
    await _transport.close();
  }
}
