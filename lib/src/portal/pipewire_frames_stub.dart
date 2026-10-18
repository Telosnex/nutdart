import 'portal_frame_source.dart';

/// Web stub for `pipewire_frames_ffi.dart`. Capture needs dart:ffi and
/// GStreamer on a Linux desktop.
class PipeWireFrames implements PortalFrameSource {
  PipeWireFrames._();

  static Future<PipeWireFrames> open(int fd, int node) async =>
      throw UnsupportedError('PipeWire capture requires dart:ffi');

  static Future<PipeWireFrames> testPattern({int numBuffers = -1}) async =>
      throw UnsupportedError('PipeWire capture requires dart:ffi');

  @override
  Future<CapturedPixels> capture({bool fresh = false}) async =>
      throw UnsupportedError('PipeWire capture requires dart:ffi');

  @override
  Future<void> close() async {}
}
