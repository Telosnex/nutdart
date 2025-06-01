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
  left,
  middle,
  right;
}