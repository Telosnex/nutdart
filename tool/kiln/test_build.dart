/// Load the release output and resolve every public C function. No mouse,
/// keyboard or screen-recording calls: safe on a headless runner.
library;

import 'dart:ffi';
import 'dart:io';

void main() {
  final target = Platform.environment['TARGET']!;
  // Intel macOS is cross-built on ARM64; integration runs it on an Intel host.
  if (target == 'macos-x64' && Abi.current() == Abi.macosArm64) return;
  final filename = Platform.isWindows
      ? 'nutdart.dll'
      : Platform.isMacOS
      ? 'libnutdart.dylib'
      : 'libnutdart.so';
  final library = DynamicLibrary.open(
    '${Platform.environment['OUT']}/out/$target/$filename',
  );
  final header = File('src/nutdart.h').readAsStringSync();
  final symbols = RegExp(
    r'NUTDART_API\s+[^;]*?\b(cu_\w+)\s*\(',
  ).allMatches(header).map((m) => m[1]!).toList();
  if (symbols.length < 20) throw StateError('Did not read the public C API');
  for (final symbol in symbols) {
    library.lookup<Void>(symbol);
  }
  stdout.writeln('$target: resolved all ${symbols.length} public C symbols');
}
