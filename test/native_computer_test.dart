import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutdart/nutdart.dart';
import 'package:nutdart/src/native_computer.dart';

/// Records each native call with its arguments.
NativeComputerCalls recording(List<(String, List<Object?>)> log) =>
    NativeComputerCalls(
      moveTo: (x, y) => log.add(('moveTo', [x, y])),
      press: (b) => log.add(('press', [b])),
      release: (b) => log.add(('release', [b])),
      click: (b) => log.add(('click', [b])),
      clickAt: (x, y, b) => log.add(('clickAt', [x, y, b])),
      doubleClick: (b) => log.add(('doubleClick', [b])),
      doubleClickAt: (x, y, b) => log.add(('doubleClickAt', [x, y, b])),
      drag: (f, t, b) => log.add(('drag', [f, t, b])),
      scroll: (dx, dy) => log.add(('scroll', [dx, dy])),
      getPosition: () => const Point(7, 9),
      tap: (k) => log.add(('tap', [k])),
      tapWithModifiers: (k, m) => log.add(('tapWithModifiers', [k, m])),
      keyDown: (k) => log.add(('keyDown', [k])),
      keyUp: (k) => log.add(('keyUp', [k])),
      type: (t) => log.add(('type', [t])),
      getSize: () => const Size(1440, 900),
      capture: ({maxSmallDimension, maxLargeDimension, quality = 80}) {
        log.add(('capture', [maxSmallDimension, maxLargeDimension, quality]));
        return Uint8List.fromList([0xff, 0xd8]);
      },
    );

/// Records hold lists, which compare by identity; compare printed forms.
void expectCalls(
  List<(String, List<Object?>)> actual,
  List<(String, List<Object?>)> expected,
) => expect(
  actual.map((c) => '${c.$1} ${c.$2}').toList(),
  expected.map((c) => '${c.$1} ${c.$2}').toList(),
);

void main() {
  test('each method makes one native call with the same arguments', () async {
    final log = <(String, List<Object?>)>[];
    final Computer computer = NativeComputer.withCalls(recording(log));
    await computer.moveTo(1, 2);
    await computer.press();
    await computer.release(MouseButton.right);
    await computer.click(MouseButton.middle);
    await computer.clickAt(3, 4, MouseButton.right);
    await computer.doubleClick();
    await computer.doubleClickAt(5, 6);
    await computer.drag(const Point(1, 1), const Point(2, 2));
    await computer.scroll(-1, 3);
    await computer.tap('return');
    await computer.tapWithModifiers('c', ['cmd', 'shift']);
    await computer.keyDown('shift');
    await computer.keyUp('shift');
    await computer.type('héllo');
    expectCalls(log, [
      ('moveTo', [1, 2]),
      ('press', [MouseButton.left]),
      ('release', [MouseButton.right]),
      ('click', [MouseButton.middle]),
      ('clickAt', [3, 4, MouseButton.right]),
      ('doubleClick', [MouseButton.left]),
      ('doubleClickAt', [5, 6, MouseButton.left]),
      ('drag', [const Point(1, 1), const Point(2, 2), MouseButton.left]),
      ('scroll', [-1, 3]),
      ('tap', ['return']),
      (
        'tapWithModifiers',
        [
          'c',
          ['cmd', 'shift'],
        ],
      ),
      ('keyDown', ['shift']),
      ('keyUp', ['shift']),
      ('type', ['héllo']),
    ]);
  });

  test('screen, cursor, and screenshot pass through', () async {
    final log = <(String, List<Object?>)>[];
    final computer = NativeComputer.withCalls(recording(log));
    expect(computer.isActive, isTrue);
    expect(computer.screenSize, const Size(1440, 900));
    final cursor = await computer.cursorPosition();
    expect((cursor.point, cursor.isLastSet), (const Point(7, 9), false));
    final shot = await computer.screenshot(
      maxSmallDimension: 800,
      maxLargeDimension: 1280,
      quality: 100,
    );
    expect(shot!.mimeType, 'image/jpeg');
    expect(shot.bytes, [0xff, 0xd8]);
    expectCalls(log, [
      ('capture', [800, 1280, 100]),
    ]);
    expect(await computer.ended.isEmpty, isTrue);
  });

  test('a failed capture returns null', () async {
    final calls = recording([]);
    final computer = NativeComputer.withCalls(
      NativeComputerCalls(
        moveTo: calls.moveTo,
        press: calls.press,
        release: calls.release,
        click: calls.click,
        clickAt: calls.clickAt,
        doubleClick: calls.doubleClick,
        doubleClickAt: calls.doubleClickAt,
        drag: calls.drag,
        scroll: calls.scroll,
        getPosition: calls.getPosition,
        tap: calls.tap,
        tapWithModifiers: calls.tapWithModifiers,
        keyDown: calls.keyDown,
        keyUp: calls.keyUp,
        type: calls.type,
        getSize: calls.getSize,
        capture: ({maxSmallDimension, maxLargeDimension, quality = 80}) => null,
      ),
    );
    expect(
      await computer.screenshot(maxSmallDimension: 1, maxLargeDimension: 1),
      isNull,
    );
  });

  test('native errors surface from the returned future', () async {
    final calls = recording([]);
    final computer = NativeComputer.withCalls(
      NativeComputerCalls(
        moveTo: calls.moveTo,
        press: calls.press,
        release: calls.release,
        click: calls.click,
        clickAt: calls.clickAt,
        doubleClick: calls.doubleClick,
        doubleClickAt: calls.doubleClickAt,
        drag: calls.drag,
        scroll: calls.scroll,
        getPosition: calls.getPosition,
        tap: calls.tap,
        tapWithModifiers: (k, m) => throw ArgumentError('Invalid modifier'),
        keyDown: calls.keyDown,
        keyUp: calls.keyUp,
        type: calls.type,
        getSize: calls.getSize,
        capture: calls.capture,
      ),
    );
    await expectLater(
      computer.tapWithModifiers('a', ['hyper']),
      throwsArgumentError,
    );
  });

  test('the platform calls are the static API functions', () {
    const platform = NativeComputerCalls.platform;
    expect(platform.moveTo, same(Mouse.moveTo));
    expect(platform.click, same(Mouse.click));
    expect(platform.clickAt, same(Mouse.clickAt));
    expect(platform.doubleClick, same(Mouse.doubleClick));
    expect(platform.doubleClickAt, same(Mouse.doubleClickAt));
    expect(platform.drag, same(Mouse.drag));
    expect(platform.scroll, same(Mouse.scroll));
    expect(platform.press, same(Mouse.press));
    expect(platform.release, same(Mouse.release));
    expect(platform.getPosition, same(Mouse.getPosition));
    expect(platform.tap, same(Keyboard.tap));
    expect(platform.tapWithModifiers, same(Keyboard.tapWithModifiers));
    expect(platform.keyDown, same(Keyboard.keyDown));
    expect(platform.keyUp, same(Keyboard.keyUp));
    expect(platform.type, same(Keyboard.type));
    expect(platform.getSize, same(Screen.getSize));
    expect(platform.capture, same(Screen.capture));
  });
}
