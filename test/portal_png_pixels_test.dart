import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../dev/png_pixels.dart';

void main() {
  for (var filter = 0; filter <= 4; filter++) {
    test('probe decoder reconstructs PNG filter $filter', () {
      const rows = [
        [180, 0, 0, 0, 180, 0],
        [0, 0, 180, 255, 255, 255],
      ];
      final encoded = <int>[];
      for (var y = 0; y < 2; y++) {
        encoded.add(filter);
        for (var x = 0; x < 6; x++) {
          final a = x < 3 ? 0 : rows[y][x - 3];
          final b = y == 0 ? 0 : rows[y - 1][x];
          final c = y == 0 || x < 3 ? 0 : rows[y - 1][x - 3];
          final p = a + b - c;
          final prediction = switch (filter) {
            0 => 0,
            1 => a,
            2 => b,
            3 => (a + b) ~/ 2,
            _ =>
              (p - a).abs() <= (p - b).abs() && (p - a).abs() <= (p - c).abs()
                  ? a
                  : (p - b).abs() <= (p - c).abs()
                  ? b
                  : c,
          };
          encoded.add((rows[y][x] - prediction) & 255);
        }
      }
      final png = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
      final header = Uint8List(13);
      ByteData.sublistView(header)
        ..setUint32(0, 2)
        ..setUint32(4, 2);
      header[8] = 8;
      header[9] = 2;
      void chunk(int type, List<int> bytes) {
        final prefix = ByteData(8)
          ..setUint32(0, bytes.length)
          ..setUint32(4, type);
        png
          ..add(prefix.buffer.asUint8List())
          ..add(bytes)
          ..add([0, 0, 0, 0]);
      }

      chunk(0x49484452, header);
      chunk(0x49444154, ZLibEncoder().convert(encoded));
      chunk(0x49454e44, []);
      final pixels = PngPixels(png.takeBytes());
      expect(pixels.at(0, 0), (180, 0, 0));
      expect(pixels.at(1, 0), (0, 180, 0));
      expect(pixels.at(0, 1), (0, 0, 180));
      expect(pixels.at(1, 1), (255, 255, 255));
    });
  }
}
