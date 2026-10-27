import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart_bindings_generated.dart' as bindings;
import 'package:nutdart/src/nutdart_real.dart' show Nutdart;

void main() {
  test('the code asset loads and exposes every public native symbol', () {
    expect(Nutdart.isAvailable, isTrue);
    final addresses = [
      bindings.addresses.cu_mouse_move.address,
      bindings.addresses.cu_mouse_click.address,
      bindings.addresses.cu_mouse_double_click.address,
      bindings.addresses.cu_mouse_drag.address,
      bindings.addresses.cu_mouse_scroll.address,
      bindings.addresses.cu_mouse_get_position.address,
      bindings.addresses.cu_mouse_toggle.address,
      bindings.addresses.cu_keyboard_key_tap.address,
      bindings.addresses.cu_keyboard_key_tap_with_flags.address,
      bindings.addresses.cu_keyboard_type_string.address,
      bindings.addresses.cu_keyboard_key_down.address,
      bindings.addresses.cu_keyboard_key_up.address,
      bindings.addresses.cu_screen_get_size.address,
      bindings.addresses.cu_screen_capture_region.address,
      bindings.addresses.cu_screen_capture_full.address,
      bindings.addresses.cu_screen_free_capture.address,
      bindings.addresses.cu_screen_capture_region_jpeg.address,
      bindings.addresses.cu_screen_capture_full_jpeg.address,
      bindings.addresses.cu_screen_free_jpeg.address,
      bindings.addresses.cu_sleep_ms.address,
    ];
    expect(addresses, hasLength(20));
    expect(addresses, everyElement(isNonZero));
  }, skip: !(Platform.isLinux || Platform.isMacOS || Platform.isWindows));
}
