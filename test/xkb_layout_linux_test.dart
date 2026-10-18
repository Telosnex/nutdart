import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart_portal.dart';
import 'package:nutdart/src/portal/xkb_layout.dart' show compileXkbLayout;

void main() {
  test('real us and gr layouts with libxkbcommon', () {
    final us = compileXkbLayout(const XkbLayout('us'));
    expect(resolveTypeKeysyms('Hello, world!\n', us), isNotEmpty);
    expect(
      () => resolveTypeKeysyms('aé', us),
      throwsA(isA<ComputerActionUnsupported>()),
    );
    final gr = compileXkbLayout(const XkbLayout('gr'));
    // Ω is Greek_OMEGA (0x7d9) on gr, not the Unicode keysym.
    expect(resolveTypeKeysyms('Ω', gr), [0x7d9]);
    final de = compileXkbLayout(const XkbLayout('de', variant: 'nodeadkeys'));
    expect(resolveTypeKeysyms('äÖß', de), [0xe4, 0xd6, 0xdf]);
  }, skip: !Platform.isLinux);
}
