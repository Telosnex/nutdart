// The Linux code must not start a process: sandboxed packages (Flatpak, Snap)
// have no host commands, and computer use must not run a shell.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _nativeSpawn = RegExp(
  r'\b(system|popen|fork|vfork|posix_spawnp?|exec(l|lp|le|v|vp|ve|vpe)|'
  r'g_spawn_\w+|g_subprocess_\w+)\s*\(',
);
final _dartSpawn = RegExp(r'\bProcess\s*\.\s*(run|runSync|start)\b');

List<String> _matches(String dir, Set<String> extensions, RegExp pattern) {
  final found = <String>[];
  for (final entity in Directory(dir).listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!extensions.any(entity.path.endsWith)) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        found.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return found;
}

void main() {
  test('src/linux starts no process', () {
    expect(
      _matches('src/linux', {'.c', '.cc', '.cpp', '.h'}, _nativeSpawn),
      isEmpty,
    );
  });

  test('lib starts no process', () {
    expect(_matches('lib', {'.dart'}, _dartSpawn), isEmpty);
  });

  test('the pattern matches the calls it must reject', () {
    for (final line in [
      'system("which grim");',
      'FILE *f = popen(cmd, "r");',
      'execvp (argv[0], argv);',
      'pid_t pid = fork();',
      'posix_spawnp(&pid, "sh", 0, 0, argv, envp);',
      'g_spawn_command_line_sync("grim", 0, 0, 0, 0);',
    ]) {
      expect(_nativeSpawn.hasMatch(line), isTrue, reason: line);
    }
    expect(_nativeSpawn.hasMatch('Linux systems.'), isFalse);
    expect(_dartSpawn.hasMatch("await Process.run('grim', []);"), isTrue);
  });
}
