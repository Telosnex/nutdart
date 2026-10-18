// dart:ffi is unavailable on web, so the descriptor bridge has a stub there.
export 'unix_fd_stub.dart' if (dart.library.ffi) 'unix_fd_ffi.dart';
