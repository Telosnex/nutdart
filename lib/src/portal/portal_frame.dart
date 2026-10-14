import 'dart:typed_data';

import '../nutdart_model.dart';

/// A PNG from the selected stream, with stream-local input coordinates.
/// Mapping assumes the original, uncropped image. If a caller resizes it,
/// provide that image's dimensions to [logicalPoint]. No desktop offset is added.
class PortalFrame {
  final Uint8List png;
  final Size pixelSize;
  final Size logicalSize;
  final Object sessionIdentity;

  /// Pipeline running time, not wall time. Null when the source has no timestamp.
  final int? runningTimeNs;

  /// Fresh capture boundary. The sample timestamp must be strictly newer.
  final int? boundaryNs;

  PortalFrame.fromPng(
    Uint8List bytes,
    this.logicalSize,
    this.sessionIdentity, {
    this.runningTimeNs,
    this.boundaryNs,
  }) : png = bytes.asUnmodifiableView(),
       pixelSize = _pngSize(bytes);

  static Size _pngSize(Uint8List png) {
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (png.length < 33 ||
        List.generate(8, (i) => png[i] == signature[i]).contains(false)) {
      throw const FormatException('Invalid PNG frame');
    }
    final data = ByteData.sublistView(png);
    if (data.getUint32(8) != 13 || data.getUint32(12) != 0x49484452) {
      throw const FormatException('Missing PNG IHDR');
    }
    final width = data.getUint32(16), height = data.getUint32(20);
    if (width == 0 || height == 0 || width > 100000 || height > 100000) {
      throw const FormatException('Invalid PNG dimensions');
    }
    return Size(width, height);
  }

  ({double x, double y}) logicalPoint(double x, double y, {Size? imageSize}) {
    final size = imageSize ?? pixelSize;
    if (size.width <= 0 ||
        size.height <= 0 ||
        !x.isFinite ||
        !y.isFinite ||
        x < 0 ||
        y < 0 ||
        x >= size.width ||
        y >= size.height) {
      throw RangeError('Point is outside the frame');
    }
    return (
      x: x * logicalSize.width / size.width,
      y: y * logicalSize.height / size.height,
    );
  }
}
