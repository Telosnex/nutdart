import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Send a fixed command to portal_loop_probe.dart --serve as the same user.
/// Usage: `dart run dev/portal_loop_command.dart CONTROL-directory run [0|25|100]`
/// Commands: run, state, close. No new session or consent request is made.
Future<void> main(List<String> arguments) async {
  if (arguments.length < 2 ||
      !['run', 'state', 'close'].contains(arguments[1])) {
    throw ArgumentError('Expected CONTROL directory and run, state, or close');
  }
  final directory = Directory(arguments[0]);
  final hold = arguments.length > 2 && arguments[2] != '--wait-focus'
      ? int.parse(arguments[2])
      : 0;
  if (![0, 25, 100].contains(hold)) {
    throw ArgumentError('Unsupported key duration');
  }
  if (arguments.contains('--wait-focus') && arguments[1] == 'run') {
    final waiting = Stopwatch()..start();
    var focused = false;
    while (waiting.elapsed < const Duration(minutes: 2)) {
      final state =
          jsonDecode(await send(directory, 'state', 0)) as Map<String, dynamic>;
      if (state['targetActive'] == true && state['buttonFocused'] == true) {
        focused = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!focused) {
      throw TimeoutException('Fixture remained inactive; no probe input sent');
    }
  }
  stdout.writeln(await send(directory, arguments[1], hold));
}

Future<String> send(Directory directory, String command, int hold) async {
  final request = File('${directory.path}/request.json');
  final response = File('${directory.path}/response.json');
  if (await request.exists()) {
    throw StateError('Another probe command is pending');
  }
  if (await response.exists()) await response.delete();
  final temporary = File('${directory.path}/request-$pid.tmp');
  await temporary.writeAsString(
    jsonEncode({'command': command, 'holdMs': hold}),
  );
  await temporary.rename(request.path);
  if (command == 'close') return 'Close requested';
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(minutes: 3)) {
    if (await response.exists()) {
      return response.readAsString();
    }
    if (!await directory.exists()) throw StateError('Probe session closed');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException('Probe did not respond');
}
