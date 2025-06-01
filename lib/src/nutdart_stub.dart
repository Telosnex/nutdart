// Stub implementation of the Nutdart API.
// This file is used on the web and other environments where the native
// library is unavailable.  All operations are implemented as no-ops so that
// applications depending on this package still compile and run.

import 'dart:typed_data';

import 'package:nutdart/src/nutdart_model.dart';

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
