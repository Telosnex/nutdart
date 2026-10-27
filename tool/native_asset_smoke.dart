// An AOT app must resolve the bundled code asset too, not just flutter_tester.
// No desktop input, capture, permission requests or system-library search paths.
import 'dart:io';

import 'package:nutdart/src/nutdart_real.dart' show Nutdart;
import 'package:nutdart/nutdart_bindings_generated.dart' as bindings;

void main() {
  if (!Nutdart.isAvailable) throw StateError('Desktop code asset not loaded');
  if (bindings.addresses.cu_mouse_get_position.address == 0 ||
      bindings.addresses.cu_keyboard_key_tap.address == 0 ||
      bindings.addresses.cu_screen_capture_full_jpeg.address == 0) {
    throw StateError('Missing native API symbol');
  }
  bindings.cu_sleep_ms(0); // Safe to call without desktop permissions.
  stdout.writeln('nutdart AOT code asset loaded');
}
