// Stub implementation of the Nutdart API.
// This file is used on the web and other environments where the native
// library is unavailable.  All operations are implemented as no-ops so that
// applications depending on this package still compile and run.

import 'dart:typed_data';

// Basic geometry helpers ----------------------------------------------------
class Point {
  final int x;
  final int y;
  const Point(this.x, this.y);
  @override
  String toString() => 'Point($x, $y)';
  @override
  int get hashCode => Object.hash(x, y);
  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;
}

class Size {
  final int width;
  final int height;
  const Size(this.width, this.height);
  @override
  String toString() => 'Size($width, $height)';
  @override
  int get hashCode => Object.hash(width, height);
  @override
  bool operator ==(Object other) => other is Size && other.width == width && other.height == height;
}

class Color {
  final int r;
  final int g;
  final int b;
  const Color(this.r, this.g, this.b);
  Color.fromHex(int hex)
      : r = (hex >> 16) & 0xff,
        g = (hex >> 8) & 0xff,
        b = hex & 0xff;
  int get hex => (r << 16) | (g << 8) | b;
  @override
  String toString() => 'Color($r, $g, $b)';
  @override
  int get hashCode => Object.hash(r, g, b);
  @override
  bool operator ==(Object other) => other is Color && other.r == r && other.g == g && other.b == b;
}

// Mouse ---------------------------------------------------------------------

enum MouseButton {
  left(1),
  middle(2),
  right(3);
  const MouseButton(this.value);
  final int value;
}

class Mouse {
  Mouse._();
  static void moveTo(int x, int y) {}
  static void moveToPoint(Point p) {}
  static void click([MouseButton button = MouseButton.left]) {}
  static void clickAt(int x, int y, [MouseButton button = MouseButton.left]) {}
  static void clickAtPoint(Point p, [MouseButton button = MouseButton.left]) {}
  static void doubleClick([MouseButton button = MouseButton.left]) {}
  static void doubleClickAt(int x, int y, [MouseButton button = MouseButton.left]) {}
  static void drag(Point from, Point to, [MouseButton button = MouseButton.left]) {}
  static void scroll(int deltaX, int deltaY) {}
  static void scrollVertical(int delta) {}
  static void scrollHorizontal(int delta) {}
  static Point getPosition() => const Point(0, 0);
  static void press([MouseButton button = MouseButton.left]) {}
  static void release([MouseButton button = MouseButton.left]) {}
}

// Keyboard ------------------------------------------------------------------
class Keyboard {
  Keyboard._();
  static void tap(String key) {}
  static void tapWithModifiers(String key, List<String> modifiers) {}
  static void type(String text) {}
  static void keyDown(String key) {}
  static void keyUp(String key) {}
  // Convenience shortcuts ----------------------------------------------------
  static void copy() {}
  static void paste() {}
  static void cut() {}
  static void selectAll() {}
  static void undo() {}
  static void redo() {}
  static void save() {}
  static void enter() {}
  static void escape() {}
  static void tab() {}
  static void space() {}
  static void backspace() {}
  static void delete() {}
  static void arrowUp() {}
  static void arrowDown() {}
  static void arrowLeft() {}
  static void arrowRight() {}
}

// Screen --------------------------------------------------------------------
class Screen {
  Screen._();
  static Size getSize() => const Size(0, 0);
  static Uint8List? capture({int? maxSmallDimension, int? maxLargeDimension, int quality = 80}) => null;
  static Uint8List? captureRegion(int x, int y, int width, int height,
          {int? maxSmallDimension, int? maxLargeDimension, int quality = 80}) =>
      null;
}

// Misc utilities ------------------------------------------------------------
class ComputerUse {
  ComputerUse._();
  static Future<void> sleep(int milliseconds) => Future.delayed(Duration(milliseconds: milliseconds));
  static Future<void> sleepDuration(Duration d) => Future.delayed(d);
}
