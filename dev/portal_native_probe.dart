import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:nutdart/src/portal/pipewire_frames.dart';
import 'package:nutdart/src/portal/unix_fd.dart';

import 'png_pixels.dart';

/// Linux native checks with synthetic frames and local sockets only.
/// No desktop consent, input injection, packages, or build steps.
Future<void> main() async {
  await bridge();
  await stream(); // Warm native libraries and worker pools.
  final before = await fdCount();
  for (var i = 0; i < 25; i++) {
    await bridge();
    await stream();
  }
  final after = await fdCount();
  if (after > before) throw StateError('Descriptor growth: $before → $after');
  final stopped = await PipeWireFrames.testPattern(numBuffers: 1);
  try {
    await stopped.capture();
    try {
      await stopped.capture(fresh: true);
      throw StateError('Accepted EOS as a fresh frame');
    } on TimeoutException {
      stdout.writeln('PASS: EOS rejects fresh capture');
    }
  } finally {
    await stopped.close();
  }
  stdout.writeln(
    'PASS: 25 FD transfers and 25 pipeline cycles; FD count $before → $after',
  );
}

Future<int> fdCount() async =>
    (await Directory('/proc/self/fd').list().toList()).length;
Future<void> stream() async {
  final source = await PipeWireFrames.testPattern();
  try {
    await source.capture();
    await Future<void>.delayed(
      const Duration(milliseconds: 100),
    ); // Leave an old sample queued.
    final sample = await source.capture(fresh: true);
    if (sample.runningTimeNs! <= sample.boundaryNs!) {
      throw StateError('Stale sample');
    }
    if (PngPixels(sample.png).at(20, 20) != (0, 0, 0)) {
      throw StateError('Unexpected synthetic pixels');
    }
    final pending = source.capture(fresh: true);
    final closing = source.close(), again = source.close();
    if (!identical(closing, again)) {
      throw StateError('Concurrent close did not share cleanup');
    }
    await pending;
    await closing;
    try {
      source.capture();
      throw StateError('Capture after close succeeded');
    } on StateError catch (e) {
      if (!e.toString().contains('stream is closed')) rethrow;
    }
  } finally {
    await source.close();
  }
}

Future<void> bridge() async {
  final directory = await Directory.systemTemp.createTemp(
    'nutdart-native-test-',
  );
  RawServerSocket? server;
  RawSocket? sender, receiver;
  StreamSubscription<RawSocketEvent>? events;
  int fd = -1;
  final byte = calloc<Uint8>()..value = 42;
  try {
    final address = InternetAddress(
      '${directory.path}/source',
      type: InternetAddressType.unix,
    );
    server = await RawServerSocket.bind(address, 0);
    final accepted = server.first;
    sender = await RawSocket.connect(address, 0);
    receiver = await accepted;
    fd = await takeUnixFd(ResourceHandle.fromRawSocket(sender));
    final received = Completer<int>();
    events = receiver.listen((event) {
      if (event == RawSocketEvent.read) {
        final bytes = receiver!.read();
        if (bytes != null && !received.isCompleted) {
          received.complete(bytes.single);
        }
      }
    });
    final write = DynamicLibrary.open('libc.so.6')
        .lookupFunction<
          IntPtr Function(Int32, Pointer<Void>, UintPtr),
          int Function(int, Pointer<Void>, int)
        >('write');
    if (write(fd, byte.cast(), 1) != 1 ||
        await received.future.timeout(const Duration(seconds: 2)) != 42) {
      throw StateError('FD transfer did not preserve socket data');
    }
  } finally {
    if (fd >= 0) closeUnixFd(fd);
    calloc.free(byte);
    await events?.cancel();
    await sender?.close();
    await receiver?.close();
    await server?.close();
    await directory.delete(recursive: true);
  }
}
