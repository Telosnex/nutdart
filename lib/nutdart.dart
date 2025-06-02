/// Nutdart public API. On unsupported platforms (web, Android, iOS) this
/// becomes a set of no-op placeholders so that dependent applications can
/// still compile.  On desktop platforms (macOS, Windows, Linux) the full
/// FFI implementation is used.

library;

export 'src/nutdart_stub.dart' if (dart.library.ffi) 'src/nutdart_real.dart';
export 'src/nutdart_model.dart';
