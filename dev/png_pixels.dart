import 'dart:io';
import 'dart:typed_data';

/// Minimal decoder for the RGB8, non-interlaced PNG emitted by our pipeline.
/// Used only for probe assertions. Does not accept general-purpose images.
class PngPixels {
  late final int width, height;
  late final Uint8List pixels;
  PngPixels(Uint8List png) {
    final data = ByteData.sublistView(png);
    width = data.getUint32(16);
    height = data.getUint32(20);
    if (png[24] != 8 || png[25] != 2 || png[28] != 0) {
      throw const FormatException('Expected non-interlaced RGB8 PNG');
    }
    final compressed = BytesBuilder(copy: false);
    var offset = 8;
    while (offset + 12 <= png.length) {
      final size = data.getUint32(offset), type = data.getUint32(offset + 4);
      if (offset + size + 12 > png.length) {
        throw const FormatException('Truncated PNG');
      }
      if (type == 0x49444154) {
        compressed.add(
          Uint8List.sublistView(png, offset + 8, offset + 8 + size),
        );
      }
      offset += size + 12;
      if (type == 0x49454e44) break;
    }
    final raw = ZLibDecoder().convert(compressed.takeBytes());
    final stride = width * 3;
    if (raw.length != (stride + 1) * height) {
      throw const FormatException('Unexpected PNG data length');
    }
    pixels = Uint8List(stride * height);
    for (var y = 0; y < height; y++) {
      final filter = raw[y * (stride + 1)];
      for (var x = 0; x < stride; x++) {
        final pos = y * stride + x;
        final a = x >= 3 ? pixels[pos - 3] : 0;
        final b = y > 0 ? pixels[pos - stride] : 0;
        final c = y > 0 && x >= 3 ? pixels[pos - stride - 3] : 0;
        final prediction = switch (filter) {
          0 => 0,
          1 => a,
          2 => b,
          3 => (a + b) ~/ 2,
          4 => _paeth(a, b, c),
          _ => throw const FormatException('Unsupported PNG filter'),
        };
        pixels[pos] = (raw[y * (stride + 1) + 1 + x] + prediction) & 255;
      }
    }
  }
  static int _paeth(int a, int b, int c) {
    final p = a + b - c,
        pa = (b - c).abs(),
        pb = (a - c).abs(),
        pc = (p - c).abs();
    return pa <= pb && pa <= pc
        ? a
        : pb <= pc
        ? b
        : c;
  }

  (int, int, int) at(int x, int y) {
    final pos = (y * width + x) * 3;
    return (pixels[pos], pixels[pos + 1], pixels[pos + 2]);
  }
}
