import 'dart:io';

import 'package:nutdart/nutdart_portal.dart';

/// Run in a Linux desktop session: dart run dev/portal_probe.dart
/// Requests consent, captures a PNG, and moves the pointer to screen center.
/// No clicks, keystrokes, package installs, or build commands occur.
Future<void> main() async {
  final portal = PortalComputerUse();
  try {
    final watch = Stopwatch()..start();
    final png = await portal.capture();
    stdout.writeln(
      'Screenshot: ${png.length} bytes in ${watch.elapsedMilliseconds} ms',
    );
    await portal.start();
    for (var i = 0; i < 3; i++) {
      watch.reset();
      final frame = await portal.captureFrame();
      stdout.writeln(
        'PipeWire frame $i: ${frame.pixelSize}, ${frame.png.length} bytes in ${watch.elapsedMilliseconds} ms; logical ${frame.logicalSize}',
      );
      await portal.moveToFrame(
        frame,
        frame.pixelSize.width / 2,
        frame.pixelSize.height / 2,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final size = portal.sharedSize!;
    stdout.writeln('Remote control approved: $size');
    await portal.moveTo(size.width ~/ 2, size.height ~/ 2);
    stdout.writeln('Pointer moved to shared-monitor center');
  } finally {
    await portal.close();
    stdout.writeln('Portal client closed');
  }
}
