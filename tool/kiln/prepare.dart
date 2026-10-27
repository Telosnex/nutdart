/// Installs only the build dependencies absent on the Linux release runners.
library;

import 'dart:io';

Future<void> main() async {
  if (!Platform.isLinux) return;
  for (final args in [
    ['apt-get', 'update', '-qq'],
    [
      'apt-get',
      'install',
      '-y',
      '-qq',
      'clang',
      'cmake',
      'ninja-build',
      'pkg-config',
      'libx11-dev',
      'libxtst-dev',
      'libxinerama-dev',
      'libjpeg-dev',
    ],
  ]) {
    final process = await Process.start(
      'sudo',
      args,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) exit(code);
  }
}
