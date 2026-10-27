import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart.dart';
// `Nutdart.isAvailable` exists only in the FFI build (not the web/stub export).
import 'package:nutdart/src/nutdart_real.dart' show Nutdart;

// Explicit opt-in only: these calls move/click/type on the real desktop and
// may request screen-recording/accessibility permissions. CI opts in on Xvfb.
final bool _automation =
    Platform.environment['NUTDART_AUTOMATION_TESTS'] == '1' &&
    Nutdart.isAvailable;
const _automationSkip = 'set NUTDART_AUTOMATION_TESTS=1 on an isolated desktop';

void main() {
  group('Nutdart basic tests', () {
    test('Screen.getSize returns valid dimensions', () {
      final size = Screen.getSize();
      // On unsupported platforms, this will return Size(0, 0)
      expect(size.width, greaterThanOrEqualTo(0));
      expect(size.height, greaterThanOrEqualTo(0));
    }, skip: _automation ? false : _automationSkip);

    test('Mouse.getPosition returns valid coordinates', () {
      final position = Mouse.getPosition();
      // On unsupported platforms, this will return Point(0, 0)
      expect(position.x, greaterThanOrEqualTo(0));
      expect(position.y, greaterThanOrEqualTo(0));
    }, skip: _automation ? false : _automationSkip);

    test('Point equality and hash', () {
      final p1 = Point(100, 200);
      final p2 = Point(100, 200);
      final p3 = Point(100, 201);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
      expect(p1.toString(), equals('Point(100, 200)'));
    });

    test('Size equality and hash', () {
      final s1 = Size(1920, 1080);
      final s2 = Size(1920, 1080);
      final s3 = Size(1920, 1081);

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
      expect(s1, isNot(equals(s3)));
      expect(s1.toString(), equals('Size(1920, 1080)'));
    });

    test('Color creation and conversion', () {
      final c1 = Color(255, 128, 64);
      final c2 = Color.fromHex(0xFF8040);

      expect(c1, equals(c2));
      expect(c1.r, equals(255));
      expect(c1.g, equals(128));
      expect(c1.b, equals(64));
      expect(c1.hex, equals(0xFF8040));
      expect(c1.toString(), equals('Color(255, 128, 64)'));
    });

    test('MouseButton enum values', () {
      expect(MouseButton.left.index, equals(0));
      expect(MouseButton.middle.index, equals(1));
      expect(MouseButton.right.index, equals(2));
    });

    test('Screen capture returns data or null', () {
      // This test just verifies the API works without crashing
      final data = Screen.capture(maxSmallDimension: 100, quality: 50);
      // On unsupported platforms, this will return null
      expect(data, anyOf(isNull, isA<Uint8List>()));
    }, skip: _automation ? false : _automationSkip);

    test('ComputerUse.sleep delays execution', () async {
      final start = DateTime.now();
      await ComputerUse.sleep(100);
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('ComputerUse.sleepDuration delays execution', () async {
      final start = DateTime.now();
      await ComputerUse.sleepDuration(Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });
  });

  group('Nutdart desktop automation', () {
    test('X11 moves the cursor and captures a real JPEG', () {
      final size = Screen.getSize();
      expect(size.width, greaterThan(100));
      expect(size.height, greaterThan(100));
      Mouse.moveTo(50, 60);
      expect(Mouse.getPosition(), const Point(50, 60));
      final jpeg = Screen.capture(maxSmallDimension: 100, quality: 50);
      expect(jpeg, isNotNull);
      expect(jpeg!.take(2), [0xff, 0xd8]);
    }, skip: !Platform.isLinux);

    test('Mouse operations do not throw', () {
      expect(() => Mouse.moveTo(100, 100), returnsNormally);
      expect(() => Mouse.moveToPoint(Point(100, 100)), returnsNormally);
      expect(() => Mouse.click(), returnsNormally);
      expect(() => Mouse.clickAt(100, 100), returnsNormally);
      expect(() => Mouse.doubleClick(), returnsNormally);
      expect(() => Mouse.drag(Point(0, 0), Point(100, 100)), returnsNormally);
      expect(() => Mouse.scroll(10, 10), returnsNormally);
      expect(() => Mouse.press(), returnsNormally);
      expect(() => Mouse.release(), returnsNormally);
    });

    test('Keyboard operations do not throw', () {
      expect(() => Keyboard.tap('a'), returnsNormally);
      expect(() => Keyboard.tapWithModifiers('a', ['cmd']), returnsNormally);
      expect(() => Keyboard.type('hello'), returnsNormally);
      expect(() => Keyboard.keyDown('shift'), returnsNormally);
      expect(() => Keyboard.keyUp('shift'), returnsNormally);
      expect(() => Keyboard.copy(), returnsNormally);
      expect(() => Keyboard.paste(), returnsNormally);
      expect(() => Keyboard.enter(), returnsNormally);
      expect(() => Keyboard.escape(), returnsNormally);
    });
  }, skip: _automation ? false : _automationSkip);
}
