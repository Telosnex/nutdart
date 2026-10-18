// GNOME portal probe for CI. Run by tool/ci/gnome/run.sh, not directly.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nutdart/nutdart_portal.dart';

var _failed = false;
final _clock = Stopwatch()..start();
void _log(String s) => stdout.writeln('[${_clock.elapsedMilliseconds}] $s');
void _check(bool ok, String what) {
  stdout.writeln('${ok ? 'PASS' : 'FAIL'} $what');
  if (!ok) _failed = true;
}

Future<void> main() async {
  final scenario = Platform.environment['SCENARIO']!;
  final portal = PortalComputerUse(consentTimeout: const Duration(minutes: 2));
  try {
    switch (scenario) {
      case 'type':
        await _type(portal);
      case 'no-interaction':
        await _refusedStart(
          portal,
          (e) => e is StateError && '$e'.contains('remote interaction'),
        );
      case 'deny':
        await _refusedStart(
          portal,
          (e) => e is PortalResponseException && e.code == 1,
        );
      default:
        throw ArgumentError(scenario);
    }
  } catch (e, s) {
    _check(false, 'unexpected $e\n$s');
  } finally {
    await portal.close();
  }
  exit(_failed ? 1 : 0);
}

/// I1: no consent, no session. Nothing can be typed afterwards.
Future<void> _refusedStart(
  PortalComputerUse portal,
  bool Function(Object) expected,
) async {
  Object? error;
  try {
    await portal.start();
  } catch (e) {
    error = e;
  }
  _log('start error: $error');
  _check(error != null && expected(error), 'start refused as expected');
  _check(!portal.isActive, 'no active session');
  try {
    await portal.typeOnActiveLayout('x');
    _check(false, 'type after refusal throws');
  } on StateError {
    _check(true, 'type after refusal throws');
  }
}

Future<void> _type(PortalComputerUse portal) async {
  // Open the target only after consent: run.sh keeps focusing it, which
  // would pull focus away from the dialog.
  await portal.start();
  _log('started');
  final target = await Process.start('python3', [
    Platform.environment['TARGET']!,
  ]);
  var active = false;
  var text = '';
  target.stderr
      .transform(utf8.decoder)
      .listen((e) => stderr.write('target: $e'));
  target.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    l,
  ) {
    if (l.startsWith('TEXT:')) {
      text = jsonDecode(l.substring(5)) as String;
    } else {
      if (l.startsWith('ACTIVE ')) active = l == 'ACTIVE True';
      _log('target $l');
    }
  });
  Future<void> settle() => Future<void>.delayed(const Duration(seconds: 1));
  try {
    for (var i = 0; i < 300 && !active; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _check(active, 'target window active');

    // Starts with a shifted character: the first-key drop showed there.
    const first = 'Hello';
    await portal.typeOnActiveLayout(first);
    await settle();
    _check(
      text == first,
      'typed ${jsonEncode(first)} (got ${jsonEncode(text)})',
    );

    const more = ', World! 123 #@';
    await portal.typeOnActiveLayout(more);
    await settle();
    _check(
      text == first + more,
      'typed ${jsonEncode(more)} (got ${jsonEncode(text)})',
    );

    final before = text;
    Object? error;
    try {
      await portal.typeOnActiveLayout('xyé日z');
    } catch (e) {
      error = e;
    }
    await settle();
    _check(
      error is ComputerActionUnsupported,
      'missing characters refused ($error)',
    );
    _check(text == before, 'nothing sent on refusal (got ${jsonEncode(text)})');

    // I2: after Stop, input is refused and nothing reaches the window.
    await portal.stop();
    try {
      await portal.typeOnActiveLayout('q');
      _check(false, 'type after stop throws');
    } on StateError {
      _check(true, 'type after stop throws');
    }
    await settle();
    _check(text == before, 'nothing typed after stop');
  } finally {
    target.kill();
  }
}
