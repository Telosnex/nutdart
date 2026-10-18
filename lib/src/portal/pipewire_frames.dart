// dart:ffi is unavailable on web, so PipeWire capture has a stub there.
export 'portal_frame_source.dart';
export 'pipewire_frames_stub.dart'
    if (dart.library.ffi) 'pipewire_frames_ffi.dart';
