import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nutdart/nutdart_bindings_generated.dart' as bindings;
import 'package:nutdart/src/nutdart_real.dart' show Nutdart;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Flutter bundles and resolves the desktop code asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Text('Native asset smoke')),
    );
    expect(Nutdart.isAvailable, isTrue);
    expect(bindings.addresses.cu_mouse_move.address, isNonZero);
    expect(bindings.addresses.cu_keyboard_key_tap.address, isNonZero);
    expect(bindings.addresses.cu_screen_capture_full_jpeg.address, isNonZero);
    // No typing, clicking or capture: CI must not require desktop permissions.
    bindings.cu_sleep_ms(0);
    expect(find.text('Native asset smoke'), findsOneWidget);
  });
}
