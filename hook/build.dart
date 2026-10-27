/// The app build and Kiln release use this same source build. Kiln downloads
/// SHA-256-verified prebuilts only when their source key matches this package.
library;

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:kiln/kiln.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return; // Web has only Dart stubs.
    final code = input.config.code;
    // Mobile has always exposed no-op implementations, not desktop automation.
    if (code.targetOS == OS.android || code.targetOS == OS.iOS) return;
    if (!{OS.macOS, OS.linux, OS.windows}.contains(code.targetOS) ||
        !{
          Architecture.arm64,
          Architecture.x64,
        }.contains(code.targetArchitecture)) {
      throw UnsupportedError('nutdart: unsupported ${TargetName.of(code)}');
    }

    final logger = Logger('')
      // MSVC sends build errors to stdout, which CMakeBuilder logs at FINE.
      ..level = Level.ALL
      ..onRecord.listen(
        (record) => stderr.writeln('[nutdart] ${record.message}'),
      );
    await Kiln(input: input, output: output, log: logger.info).run((
      source,
    ) async {
      // No persistent source-build cache: these sources are small. A fresh
      // directory prevents stale toolchains or CMake options surviving a rebuild.
      final buildDir = Directory.fromUri(
        input.outputDirectory.resolve('cmake/'),
      );
      if (await buildDir.exists()) await buildDir.delete(recursive: true);
      await CMakeBuilder.create(
        name: 'nutdart',
        sourceDir: input.packageRoot.resolve('src/'),
        outDir: buildDir.uri,
        defines: const {'CMAKE_BUILD_TYPE': 'Release'},
        targets: const ['nutdart'],
        parallelUseAllProcessors: true,
      ).run(input: input, output: output, logger: logger);

      final filename = code.targetOS.dylibFileName('nutdart');
      final matches = await buildDir
          .list(recursive: true)
          .where((f) => f is File && f.uri.pathSegments.last == filename)
          .cast<File>()
          .toList();
      if (matches.length != 1 || await matches.single.length() == 0) {
        throw StateError(
          'nutdart: expected one nonempty $filename in $buildDir',
        );
      }
      final library = await matches.single.copy(
        input.outputDirectory.resolve(filename).toFilePath(),
      );
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'nutdart_bindings_generated.dart',
          linkMode: DynamicLoadingBundled(),
          file: library.uri,
        ),
      );
      output.dependencies.addAll(source.sourceKey.files.map((f) => f.uri));
    });
  });
}
