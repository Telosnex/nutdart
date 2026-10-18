import 'dart:typed_data';

class CapturedPixels {
  final Uint8List png;
  final int? runningTimeNs;
  final int? boundaryNs;
  const CapturedPixels(this.png, {this.runningTimeNs, this.boundaryNs});
}

abstract interface class PortalFrameSource {
  Future<CapturedPixels> capture({bool fresh = false});
  Future<void> close();
}
