import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart_portal.dart';
import 'package:nutdart/src/nutdart_model.dart';
import 'package:nutdart/src/portal/portal_transport.dart';
import 'package:nutdart/src/portal/pipewire_frames.dart';

const monitorPath = '/session/monitor';

class FakeTransport implements PortalTransport {
  final requests = <String>[];
  final inputs = <(String, List<DBusValue>)>[];
  final closedControllers = <String, StreamController<void>>{};
  int devices = 3;
  String? failAt;
  String? uri;
  int sessionsClosed = 0;
  int monitorsClosed = 0;
  int clientsClosed = 0;
  bool monitorFails = false;
  final initialStates = <Map<String, DBusValue>>[];
  final queryEnds = <String>[];
  void Function(String monitor, Map<String, DBusValue> state)? _onState;
  void Function(String method)? beforeReply;

  StreamController<void> closedFor(String path) => closedControllers
      .putIfAbsent(path, () => StreamController<void>.broadcast(sync: true));

  /// Closed signal source for the remote desktop session.
  StreamController<void> get events => closedFor('/session/test');

  void state(Map<String, DBusValue> values) => _onState!(monitorPath, values);

  @override
  Future<Map<String, DBusValue>> request(
    String interface,
    String method,
    List<DBusValue> arguments,
    Map<String, DBusValue> options,
  ) async {
    requests.add('$interface.$method');
    beforeReply?.call(method);
    if (method == failAt) throw PortalResponseException(method, 1);
    return switch (method) {
      'Screenshot' => {'uri': DBusString(uri!)},
      'CreateSession' => {'session_handle': const DBusString('/session/test')},
      'Start' => {
        'devices': DBusUint32(devices),
        'streams': DBusArray(DBusSignature('(ua{sv})'), [
          DBusStruct([
            const DBusUint32(73),
            DBusDict.stringVariant({
              'size': DBusStruct([const DBusInt32(1024), const DBusInt32(768)]),
            }),
          ]),
        ]),
      },
      _ => {},
    };
  }

  @override
  Future<int> openPipeWire(String session) async => -1;

  @override
  Future<void> notify(String method, List<DBusValue> arguments) async {
    inputs.add((method, arguments));
  }

  @override
  Stream<void> closed(String session) => closedFor(session).stream;
  @override
  Future<void> closeSession(String session) async {
    if (session == monitorPath) {
      monitorsClosed++;
    } else {
      sessionsClosed++;
    }
  }

  @override
  Future<String> createStateMonitor(
    void Function(String monitor, Map<String, DBusValue> state) onState,
  ) async {
    requests.add('Inhibit.CreateMonitor');
    if (monitorFails) throw StateError('No Inhibit portal');
    _onState = onState;
    for (final state in initialStates) {
      onState(monitorPath, state);
    }
    return monitorPath;
  }

  @override
  Future<void> queryEndResponse(String monitor) async {
    queryEnds.add(monitor);
  }

  @override
  Future<void> close() async {
    clientsClosed++;
    for (final controller in closedControllers.values) {
      await controller.close();
    }
  }
}

List<String> methods(FakeTransport transport) =>
    transport.inputs.map((input) => input.$1).toList();

/// Arguments after the session handle and options.
List<List<DBusValue>> inputArgs(FakeTransport transport) =>
    transport.inputs.map((input) => input.$2.sublist(2)).toList();

Uint8List pngHeader(int width, int height) {
  final bytes = Uint8List(33);
  bytes.setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
  final data = ByteData.sublistView(bytes);
  data.setUint32(8, 13);
  data.setUint32(12, 0x49484452);
  data.setUint32(16, width);
  data.setUint32(20, height);
  return bytes;
}

class FakeFrames implements PortalFrameSource {
  int closed = 0;
  Completer<Uint8List>? pending;
  bool? requestedFresh;
  bool stale = false;
  @override
  Future<CapturedPixels> capture({bool fresh = false}) async {
    requestedFresh = fresh;
    return CapturedPixels(
      pending == null ? pngHeader(2048, 1536) : await pending!.future,
      runningTimeNs: stale ? 99 : 101,
      boundaryNs: fresh ? 100 : null,
    );
  }

  @override
  Future<void> close() async {
    closed++;
  }
}

void main() {
  late FakeTransport transport;
  late PortalComputerUse portal;
  setUp(() {
    transport = FakeTransport();
    portal = PortalComputerUse.withTransport(transport);
  });
  tearDown(() async {
    await portal.close();
  });

  test('fresh captures enforce and expose the timestamp boundary', () async {
    final frames = FakeFrames();
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) async => frames,
    );
    await portal.start();
    final frame = await portal.captureFrame(fresh: true);
    expect(frames.requestedFresh, isTrue);
    expect(frame.runningTimeNs, greaterThan(frame.boundaryNs!));
    frames.stale = true;
    await expectLater(portal.captureFrame(fresh: true), throwsStateError);
    expect(frames.closed, 1);
  });

  test('concurrent close waits for pending frame and cleanup', () async {
    final frames = FakeFrames()..pending = Completer<Uint8List>();
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) async => frames,
    );
    await portal.start();
    final capture = portal.captureFrame();
    final assertion = expectLater(capture, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final first = portal.close(), second = portal.close();
    expect(identical(first, second), isTrue);
    frames.pending!.complete(pngHeader(2048, 1536));
    await assertion;
    await first;
    await second;
    expect(frames.closed, 1);
    expect(transport.clientsClosed, 1);
  });

  test('close during stream opening closes the eventual source', () async {
    final opening = Completer<PortalFrameSource>();
    final frames = FakeFrames();
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) => opening.future,
    );
    await portal.start();
    final capture = portal.captureFrame();
    final assertion = expectLater(capture, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    final closing = portal.close();
    opening.complete(frames);
    await assertion;
    await closing;
    expect(frames.closed, 1);
  });

  test('stream is lazy, reused, and closed with client', () async {
    final frames = FakeFrames();
    var opened = 0;
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (fd, node) async {
        expect(node, 73);
        opened++;
        return frames;
      },
    );
    await portal.start();
    expect(opened, 0);
    final frame = await portal.captureFrame();
    await portal.captureFrame();
    expect(opened, 1);
    expect(frame.pixelSize, const Size(2048, 1536));
    await portal.moveToFrame(frame, 1024, 768);
    expect(transport.inputs.single.$2.sublist(2), [
      const DBusUint32(73),
      const DBusDouble(512),
      const DBusDouble(384),
    ]);
    await portal.close();
    expect(frames.closed, 1);
  });

  test('revocation during capture discards the frame', () async {
    final frames = FakeFrames()..pending = Completer<Uint8List>();
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) async => frames,
    );
    await portal.start();
    final capturing = portal.captureFrame();
    final assertion = expectLater(capturing, throwsStateError);
    await Future<void>.delayed(Duration.zero);
    transport.events.add(null);
    frames.pending!.complete(pngHeader(2048, 1536));
    await assertion;
    await portal.close(); // Includes cleanup already started by revocation.
    expect(frames.closed, 1);
  });

  test('frame cannot control a later session', () async {
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) async => FakeFrames(),
    );
    await portal.start();
    final frame = await portal.captureFrame();
    transport.events.add(null);
    await portal.start();
    expect(() => portal.moveToFrame(frame, 0, 0), throwsStateError);
  });

  test('failed stream opening can be retried', () async {
    var attempts = 0;
    portal = PortalComputerUse.withTransport(
      transport,
      openFrames: (_, _) async {
        if (++attempts == 1) throw StateError('No plugin');
        return FakeFrames();
      },
    );
    await portal.start();
    await expectLater(portal.captureFrame(), throwsStateError);
    expect((await portal.captureFrame()).pixelSize, const Size(2048, 1536));
  });

  test(
    'pixel mapping handles scaled images and fractional logical coordinates',
    () {
      final frame = PortalFrame.fromPng(
        pngHeader(2048, 1536),
        const Size(1024, 768),
        Object(),
      );
      expect(frame.logicalPoint(1, 1), (x: 0.5, y: 0.5));
      expect(frame.logicalPoint(256, 192, imageSize: const Size(512, 384)), (
        x: 512.0,
        y: 384.0,
      ));
      expect(frame.logicalPoint(2047, 1535), (x: 1023.5, y: 767.5));
      expect(() => frame.logicalPoint(2048, 0), throwsRangeError);
      expect(() => frame.logicalPoint(double.nan, 0), throwsRangeError);
      expect(
        () => frame.logicalPoint(0, 0, imageSize: const Size(0, 1)),
        throwsRangeError,
      );
      expect(
        () => PortalFrame.fromPng(Uint8List(33), const Size(1, 1), Object()),
        throwsFormatException,
      );
      expect(
        () => PortalFrame.fromPng(pngHeader(0, 1), const Size(1, 1), Object()),
        throwsFormatException,
      );
    },
  );

  test('requests one monitor and both input devices', () async {
    await portal.start();
    expect(portal.isActive, isTrue);
    expect(portal.sharedSize, const Size(1024, 768));
    expect(transport.requests, [
      'Inhibit.CreateMonitor',
      'RemoteDesktop.CreateSession',
      'RemoteDesktop.SelectDevices',
      'ScreenCast.SelectSources',
      'RemoteDesktop.Start',
    ]);
    await expectLater(portal.start(), throwsStateError);
  });

  test('screen sharing without remote interaction closes session', () async {
    transport.devices = 0;
    await expectLater(portal.start(), throwsStateError);
    expect(portal.isActive, isFalse);
    expect(transport.sessionsClosed, 1);
    expect(() => portal.moveTo(0, 0), throwsStateError);
  });

  test('cancelled Start closes session and permits retry', () async {
    transport.failAt = 'Start';
    await expectLater(portal.start(), throwsA(isA<PortalResponseException>()));
    expect(transport.sessionsClosed, 1);
    transport.failAt = null;
    await portal.start();
    expect(portal.isActive, isTrue);
  });

  test('revocation disables further input', () async {
    await portal.start();
    transport.events.add(null);
    expect(portal.isActive, isFalse);
    expect(portal.sharedSize, isNull);
    expect(() => portal.keysym(97, pressed: true), throwsStateError);
  });

  test('absolute pointer uses stream node and logical coordinates', () async {
    await portal.start();
    await portal.moveTo(512, 384);
    final (method, args) = transport.inputs.single;
    expect(method, 'NotifyPointerMotionAbsolute');
    expect(args[0], DBusObjectPath('/session/test'));
    expect(args.sublist(2), [
      const DBusUint32(73),
      const DBusDouble(512),
      const DBusDouble(384),
    ]);
    expect(() => portal.moveTo(1024, 0), throwsRangeError);
    expect(() => portal.moveTo(-1, 0), throwsRangeError);
  });

  test('click maps Linux button codes and release', () async {
    await portal.start();
    await portal.click(MouseButton.right);
    expect(transport.inputs.map((i) => i.$2.sublist(2)).toList(), [
      [const DBusInt32(0x111), const DBusUint32(1)],
      [const DBusInt32(0x111), const DBusUint32(0)],
    ]);
  });

  test('text sends paired ASCII, Unicode, and Return keysyms', () async {
    await portal.start();
    await portal.type('a😀\n');
    expect(transport.inputs.map((i) => i.$2[2].asInt32()).toList(), [
      97,
      97,
      0x0101f600,
      0x0101f600,
      0xff0d,
      0xff0d,
    ]);
    expect(transport.inputs.map((i) => i.$2[3].asUint32()).toList(), [
      1,
      0,
      1,
      0,
      1,
      0,
    ]);
  });

  test('screenshot reads portal file without removing it', () async {
    final directory = await Directory.systemTemp.createTemp('nutdart-test-');
    try {
      final file = File('${directory.path}/shot.png');
      await file.writeAsBytes([137, 80, 78, 71]);
      transport.uri = file.uri.toString();
      expect(await portal.capture(), [137, 80, 78, 71]);
      expect(await file.exists(), isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('screenshot rejects remote URI', () async {
    transport.uri = 'https://example.com/shot.png';
    await expectLater(portal.capture(), throwsStateError);
  });

  group('scroll', () {
    test('sends discrete steps per axis and skips zero axes', () async {
      await portal.start();
      await portal.scroll(vertical: 3);
      await portal.scroll(horizontal: -2);
      await portal.scroll(vertical: -1, horizontal: 4);
      await portal.scroll();
      expect(methods(transport), everyElement('NotifyPointerAxisDiscrete'));
      expect(inputArgs(transport), [
        [const DBusUint32(0), const DBusInt32(3)],
        [const DBusUint32(1), const DBusInt32(-2)],
        [const DBusUint32(0), const DBusInt32(-1)],
        [const DBusUint32(1), const DBusInt32(4)],
      ]);
    });

    test('rejects out-of-range steps and inactive sessions', () async {
      await expectLater(portal.scroll(vertical: 1), throwsStateError);
      await portal.start();
      await expectLater(portal.scroll(vertical: 1001), throwsRangeError);
      await expectLater(portal.scroll(horizontal: -1001), throwsRangeError);
      expect(transport.inputs, isEmpty);
    });
  });

  group('key names', () {
    test('map names, aliases, and characters to keysyms', () {
      expect(portalKeysym('Return'), 0xff0d);
      expect(portalKeysym('enter'), 0xff0d);
      expect(portalKeysym('Escape'), 0xff1b);
      expect(portalKeysym('esc'), 0xff1b);
      expect(portalKeysym('BackSpace'), 0xff08);
      expect(portalKeysym('Page_Up'), 0xff55);
      expect(portalKeysym('pagedown'), 0xff56);
      expect(portalKeysym('Left'), 0xff51);
      expect(portalKeysym('F1'), 0xffbe);
      expect(portalKeysym('f12'), 0xffc9);
      expect(portalKeysym('F24'), 0xffd5);
      expect(portalKeysym('ctrl'), 0xffe3);
      expect(portalKeysym('Control_L'), 0xffe3);
      expect(portalKeysym('shift'), 0xffe1);
      expect(portalKeysym('alt'), 0xffe9);
      for (final name in ['cmd', 'super', 'meta', 'win', 'Super_L']) {
        expect(portalKeysym(name), 0xffeb, reason: name);
      }
      expect(portalKeysym('a'), 0x61);
      expect(portalKeysym('A'), 0x41);
      expect(portalKeysym(' '), 0x20);
      expect(portalKeysym('é'), 0xe9);
      expect(portalKeysym('€'), 0x010020ac);
      expect(portalKeysym('XF86AudioMute'), 0x1008ff12);
    });

    test('reject unknown names', () {
      for (final name in ['', 'F25', 'f0', 'hyper', 'ctrlx', '\u0001']) {
        expect(() => portalKeysym(name), throwsArgumentError, reason: name);
      }
      expect(() => portalKeysym('\x7f'), throwsArgumentError);
    });

    test('parse combinations including the plus key', () {
      expect(parsePortalKeyCombo('ctrl+shift+n'), [0xffe3, 0xffe1, 0x6e]);
      expect(parsePortalKeyCombo('cmd+c'), [0xffeb, 0x63]);
      expect(parsePortalKeyCombo('ctrl++'), [0xffe3, 0x2b]);
      expect(parsePortalKeyCombo('+'), [0x2b]);
      expect(parsePortalKeyCombo(' ctrl + a '), [0xffe3, 0x61]);
      for (final combo in ['', 'ctrl+', '+a', 'ctrl++a', 'ctrl+bogus']) {
        expect(
          () => parsePortalKeyCombo(combo),
          throwsArgumentError,
          reason: combo,
        );
      }
    });

    test('tapKeys presses in order and releases in reverse', () async {
      await portal.start();
      await portal.tapKeys('ctrl+shift+n');
      expect(methods(transport), everyElement('NotifyKeyboardKeysym'));
      expect(inputArgs(transport), [
        [const DBusInt32(0xffe3), const DBusUint32(1)],
        [const DBusInt32(0xffe1), const DBusUint32(1)],
        [const DBusInt32(0x6e), const DBusUint32(1)],
        [const DBusInt32(0x6e), const DBusUint32(0)],
        [const DBusInt32(0xffe1), const DBusUint32(0)],
        [const DBusInt32(0xffe3), const DBusUint32(0)],
      ]);
    });

    test('unknown names and invalid text send nothing', () async {
      await portal.start();
      expect(() => portal.tapKeys('ctrl+bogus'), throwsArgumentError);
      expect(() => portal.key('bogus', pressed: true), throwsArgumentError);
      await expectLater(portal.type('a\uD800'), throwsArgumentError);
      expect(transport.inputs, isEmpty);
    });
  });

  group('session end', () {
    test('screen lock ends control and reports it', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      await portal.start();
      expect(portal.lockMonitored, isTrue);
      transport.state({'screensaver-active': const DBusBoolean(false)});
      expect(portal.isActive, isTrue);
      transport.state({'screensaver-active': const DBusBoolean(true)});
      expect(portal.isActive, isFalse);
      expect(() => portal.moveTo(0, 0), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(ended, [PortalSessionEnd.locked]);
      expect(transport.sessionsClosed, 1);
      expect(transport.monitorsClosed, 1);
    });

    test('a locked screen at start fails before remote desktop', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      transport.initialStates.add({
        'screensaver-active': const DBusBoolean(true),
      });
      await expectLater(portal.start(), throwsStateError);
      expect(transport.requests, ['Inhibit.CreateMonitor']);
      expect(transport.monitorsClosed, 1);
      expect(portal.isActive, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(ended, isEmpty);
    });

    test('a lock during the consent dialog fails start', () async {
      transport.beforeReply = (method) {
        if (method == 'Start') {
          transport.state({'screensaver-active': const DBusBoolean(true)});
        }
      };
      await expectLater(portal.start(), throwsStateError);
      expect(portal.isActive, isFalse);
      expect(transport.sessionsClosed, 1);
      transport.beforeReply = null;
      await portal.start();
      expect(portal.isActive, isTrue);
    });

    test('revocation during start fails start', () async {
      transport.beforeReply = (method) {
        if (method == 'Start') transport.events.add(null);
      };
      await expectLater(portal.start(), throwsStateError);
      expect(portal.isActive, isFalse);
    });

    test('query end acknowledges and ends control', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      await portal.start();
      transport.state({'session-state': const DBusUint32(2)});
      expect(portal.isActive, isFalse);
      expect(transport.queryEnds, [monitorPath]);
      await Future<void>.delayed(Duration.zero);
      expect(ended, [PortalSessionEnd.sessionEnding]);
    });

    test('lost lock monitor ends control', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      await portal.start();
      transport.closedFor(monitorPath).add(null);
      expect(portal.isActive, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(ended, [PortalSessionEnd.monitorLost]);
    });

    test('missing lock monitor blocks start by default', () async {
      transport.monitorFails = true;
      await expectLater(
        portal.start(),
        throwsA(isA<PortalLockMonitorUnavailable>()),
      );
      expect(transport.requests, ['Inhibit.CreateMonitor']);
    });

    test('missing lock monitor is allowed when not required', () async {
      transport.monitorFails = true;
      portal = PortalComputerUse.withTransport(
        transport,
        requireLockMonitor: false,
      );
      await portal.start();
      expect(portal.isActive, isTrue);
      expect(portal.lockMonitored, isFalse);
    });

    test('stop releases held input and permits a new start', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      await portal.start();
      await portal.key('ctrl', pressed: true);
      await portal.key('shift', pressed: true);
      await portal.button(MouseButton.left, pressed: true);
      transport.inputs.clear();
      await portal.stop();
      expect(inputArgs(transport), [
        [const DBusInt32(0x110), const DBusUint32(0)],
        [const DBusInt32(0xffe1), const DBusUint32(0)],
        [const DBusInt32(0xffe3), const DBusUint32(0)],
      ]);
      expect(transport.sessionsClosed, 1);
      expect(transport.monitorsClosed, 1);
      await Future<void>.delayed(Duration.zero);
      expect(ended, [PortalSessionEnd.stopped]);
      await portal.start();
      expect(portal.isActive, isTrue);
    });

    test('released input is not released again on stop', () async {
      await portal.start();
      await portal.tapKeys('ctrl+a');
      await portal.click();
      transport.inputs.clear();
      await portal.stop();
      expect(transport.inputs, isEmpty);
    });

    test('revocation sends no release to the closed session', () async {
      final ended = <PortalSessionEnd>[];
      portal.ended.listen(ended.add);
      await portal.start();
      await portal.key('ctrl', pressed: true);
      transport.inputs.clear();
      transport.events.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(transport.inputs, isEmpty);
      expect(ended, [PortalSessionEnd.revoked]);
    });

    test('close releases held input', () async {
      await portal.start();
      await portal.key('alt', pressed: true);
      transport.inputs.clear();
      await portal.close();
      expect(inputArgs(transport), [
        [const DBusInt32(0xffe9), const DBusUint32(0)],
      ]);
    });
  });

  test('close is idempotent and prevents new requests', () async {
    await portal.start();
    await portal.close();
    await portal.close();
    expect(transport.sessionsClosed, 1);
    expect(transport.clientsClosed, 1);
    await expectLater(portal.start(), throwsStateError);
    await expectLater(portal.capture(), throwsStateError);
  });
}
