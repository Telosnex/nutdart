import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import 'package:nutdart/nutdart_portal.dart';

import 'png_pixels.dart';

/// Controlled GNOME/GTK4 test. Shows its own fullscreen red/green button.
/// Aborts before input if the selected monitor does not show the test surface.
/// No terminal input, package installation, or native build occurs.
///
/// `--target-stdin` reads the test window's state from stdin instead of
/// starting it. A sandboxed probe (Flatpak or Snap) uses this: the GTK4
/// window runs on the host, and only the portal client is in the sandbox.
///   portal_test_target | flatpak run com.telosnex.PortalProbe --target-stdin
Future<void> main(List<String> arguments) async {
  final target = arguments.contains('--target-stdin')
      ? await TestTarget.fromStdin()
      : await TestTarget.start();
  final portal = PortalComputerUse(consentTimeout: const Duration(minutes: 10));
  Directory? control;
  try {
    stdout.writeln(
      'Approve sharing the monitor with the red test window and allow remote interaction.',
    );
    await portal.start();
    if (arguments.contains('--serve')) {
      control = await Directory.systemTemp.createTemp('nutdart-loop-control-');
      stdout.writeln(
        'CONTROL ${control.path} — session stays open for fixed probe commands, up to 30 minutes.',
      );
      await runKeepingSession(portal, target);
      final deadline = Stopwatch()..start();
      final request = File('${control.path}/request.json');
      while (portal.isActive &&
          deadline.elapsed < const Duration(minutes: 30)) {
        if (!await request.exists()) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          continue;
        }
        final data =
            jsonDecode(await request.readAsString()) as Map<String, dynamic>;
        await request.delete();
        final command = data['command'];
        if (command == 'close') break;
        final Map<String, Object?> result;
        if (command == 'run') {
          final hold = data['holdMs'] as int? ?? 0;
          if (![0, 25, 100].contains(hold)) {
            throw ArgumentError('Unsupported probe key duration');
          }
          result = await runKeepingSession(
            portal,
            target,
            holdMilliseconds: hold,
          );
        } else if (command == 'state') {
          result = {
            'active': portal.isActive,
            'targetActive': target.isActive,
            'nativeActive': target._active,
            'stateAgeMs':
                target.watch.elapsedMilliseconds - target._lastStateMs,
            'buttonFocused': target.buttonHasFocus,
            'activations': target.clicks,
            'keys': target.keyEvents,
          };
        } else {
          result = {'error': 'Unknown fixed probe command'};
        }
        final response = File('${control.path}/response.tmp');
        await response.writeAsString(jsonEncode(result));
        await response.rename('${control.path}/response.json');
      }
    } else {
      await runLoop(portal, target);
    }
  } finally {
    try {
      await portal.close();
    } finally {
      await target.close();
      await control?.delete(recursive: true);
    }
    stdout.writeln('Portal and test window closed.');
  }
}

Future<Map<String, Object?>> runKeepingSession(
  PortalComputerUse portal,
  TestTarget target, {
  int holdMilliseconds = 0,
}) async {
  try {
    await runLoop(portal, target, holdMilliseconds: holdMilliseconds);
    return {'passed': true, 'holdMs': holdMilliseconds};
  } catch (error, stack) {
    stdout.writeln(
      'FAILED: $error\n$stack\nSession retained; no further input until a run command.',
    );
    return {
      'passed': false,
      'error': error.toString(),
      'keys': target.keyEvents,
    };
  }
}

Future<void> runLoop(
  PortalComputerUse portal,
  TestTarget target, {
  int holdMilliseconds = 0,
}) async {
  await target.waitUntilActive();
  var frame = await portal.captureFrame(fresh: true);
  for (
    var retry = 0;
    retry < 10 && !hasColor(frame, target.clicks.isOdd);
    retry++
  ) {
    frame = await portal.captureFrame(fresh: true);
  }
  expectColor(frame, target.clicks.isOdd); // Fail closed before any input.
  final baseline = target.clicks;
  stdout.writeln(
    'Test surface verified; baseline $baseline activations; key hold $holdMilliseconds ms.',
  );
  for (var i = 0; i < 10; i++) {
    final expectedGreen = (baseline + i + 1).isOdd;
    final watch = Stopwatch()..start();
    final keysBefore = target.keyEvents.length;
    if (target.clicks != baseline + i) {
      throw StateError('Unexpected target activation; no further input sent');
    }
    if (!target.isActive || (i.isOdd && !target.buttonHasFocus)) {
      throw StateError('Test target lost focus; no further input sent');
    }
    if (i.isEven) {
      await portal.moveToFrame(
        frame,
        frame.pixelSize.width / 4,
        frame.pixelSize.height / 4,
      );
      await portal.click();
    } else if (holdMilliseconds == 0) {
      await portal.tapKeysym(0x20);
    } else {
      await portal.keysym(0x20, pressed: true);
      try {
        await Future<void>.delayed(Duration(milliseconds: holdMilliseconds));
      } finally {
        await portal.keysym(0x20, pressed: false);
      }
    }
    var verified = false;
    // Bound observation by elapsed time, not number of compositor frames.
    while (watch.elapsed < const Duration(seconds: 3)) {
      frame = await portal.captureFrame(fresh: true);
      if (hasColor(frame, expectedGreen) && target.clicks == baseline + i + 1) {
        if (i.isOdd) {
          final keys = target.keyEvents
              .skip(keysBefore)
              .map((event) => event.split(' ').sublist(1, 3).join(' '))
              .toList();
          if (keys.length != 2 || keys[0] != 'DOWN 32' || keys[1] != 'UP 32') {
            throw StateError(
              'Space activation lacks its exact press/release pair: $keys',
            );
          }
        }
        verified = true;
        break;
      }
    }
    if (!verified) {
      throw StateError(
        'Input $i did not change the test surface after ${watch.elapsedMilliseconds} ms; '
        'activations=${target.clicks}, keys=${target.keyEvents.skip(keysBefore).toList()}',
      );
    }
    stdout.writeln(
      'PASS ${i.isEven ? "click" : "Space"} $i: ${expectedGreen ? "green" : "red"}, '
      '${watch.elapsedMilliseconds} ms, frame=${frame.runningTimeNs}, boundary=${frame.boundaryNs}',
    );
  }
  stdout.writeln(
    'PASS: 10 input → fresh frame → pixel checks; ${target.clicks - baseline} automated target activations.',
  );
}

bool hasColor(PortalFrame frame, bool green) {
  final pixels = PngPixels(frame.png);
  final (r, g, b) = pixels.at(pixels.width ~/ 4, pixels.height ~/ 4);
  return green
      ? r < 5 && g > 170 && g < 190 && b < 5
      : r > 170 && r < 190 && g < 5 && b < 5;
}

void expectColor(PortalFrame frame, bool green) {
  if (!hasColor(frame, green)) {
    throw StateError(
      'Shared monitor does not show the controlled test surface; no input sent',
    );
  }
}

class TestTarget {
  /// Null when the window's state comes from stdin. The window then exits
  /// on SIGPIPE when this process ends.
  final Process? process;
  final Stopwatch watch = Stopwatch()..start();
  late final StreamSubscription<String> states;
  StreamSubscription<List<int>>? errors;
  final ready = Completer<void>();
  int clicks = 0;
  final keyEvents = <String>[];
  int _lastStateMs = -1000;
  bool _active = false, _focused = false;
  TestTarget._(this.process, Stream<List<int>> output) {
    states = output
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final fields = line.split(' ');
          if (fields.first == 'KEY') {
            keyEvents.add(line);
            stdout.writeln(line);
            return;
          }
          if (fields.length != 4 || fields.first != 'STATE') {
            return;
          }
          clicks = int.parse(fields[1]);
          _active = fields[2] == '1';
          _focused = fields[3] == '1';
          _lastStateMs = watch.elapsedMilliseconds;
          if (!ready.isCompleted) {
            ready.complete();
          }
        });
    final process = this.process;
    if (process == null) return;
    errors = process.stderr.listen(stderr.add);
    unawaited(
      process.exitCode.then((code) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('Test target exited with code $code'));
        }
      }),
    );
  }
  static Future<TestTarget> start() async {
    final packages = await Isolate.packageConfig;
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        if (packages != null) '--packages=${packages.toFilePath()}',
        Platform.script.resolve('portal_test_target.dart').toFilePath(),
      ],
      environment: {'GSK_RENDERER': 'cairo'},
    );
    return _waitReady(TestTarget._(process, process.stdout));
  }

  static Future<TestTarget> fromStdin() =>
      _waitReady(TestTarget._(null, stdin));

  static Future<TestTarget> _waitReady(TestTarget target) async {
    try {
      await target.ready.future.timeout(const Duration(seconds: 10));
      return target;
    } catch (_) {
      await target.close();
      rethrow;
    }
  }

  bool get isActive =>
      _active && watch.elapsedMilliseconds - _lastStateMs < 250;
  bool get buttonHasFocus => isActive && _focused;
  Future<void> waitUntilActive() async {
    for (var i = 0; i < 60; i++) {
      if (isActive) return;
      await Future<void>.delayed(const Duration(milliseconds: 33));
    }
    throw StateError('Test target did not regain focus after consent');
  }

  Future<void> close() async {
    final process = this.process;
    if (process == null) {
      await states.cancel();
      return;
    }
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode;
    }
    await states.cancel();
    await errors?.cancel();
  }
}
