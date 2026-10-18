@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart.dart' as nutdart;
import 'package:nutdart/nutdart_portal.dart' as portal;
import 'package:nutdart/src/portal/pipewire_frames.dart';
import 'package:nutdart/src/portal/xkb_layout.dart';

// Compiling this file for the browser is the main check: both public
// libraries must build without dart:ffi, which web lacks.
void main() {
  test('native mouse API is a no-op', () {
    expect(nutdart.Mouse.getPosition(), const nutdart.Point(0, 0));
  });

  test('portal FFI pieces fail clearly instead of breaking the build', () {
    expect(
      () => compileXkbLayout(const portal.XkbLayout('us')),
      throwsUnsupportedError,
    );
    expect(PipeWireFrames.testPattern(), throwsUnsupportedError);
  });

  test('portal pure-Dart helpers still work', () {
    expect(portal.parsePortalKeyCombo('ctrl+c'), isNotEmpty);
  });
}
