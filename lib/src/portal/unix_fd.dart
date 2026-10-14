import 'dart:ffi';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// Linux ABI. This backend supports 64-bit Linux only.
final class _IOVec extends Struct {
  external Pointer<Void> base;
  @UintPtr()
  external int length;
}

final class _Message extends Struct {
  external Pointer<Void> name;
  @Uint32()
  external int nameLength;
  external Pointer<_IOVec> vectors;
  @UintPtr()
  external int vectorCount;
  external Pointer<Void> control;
  @UintPtr()
  external int controlLength;
  @Int32()
  external int flags;
}

final _libc = DynamicLibrary.open('libc.so.6');
final _close = _libc.lookupFunction<Int32 Function(Int32), int Function(int)>(
  'close',
);
void closeUnixFd(int fd) {
  _close(fd);
}

/// Transfer a Dart-owned handle through SCM_RIGHTS to an FFI-owned descriptor.
/// Dart exposes no public integer FD accessor. The private socket directory
/// prevents other users from connecting to this one-shot bridge.
Future<int> takeUnixFd(ResourceHandle handle) async {
  final ownedSocket = handle.toRawSocket();
  ownedSocket.readEventsEnabled = false;
  ownedSocket.writeEventsEnabled = false;
  Directory? directory;
  RawSocket? sender;
  int server = -1, peer = -1;
  final address = calloc<Uint8>(110);
  final message = calloc<_Message>();
  final vector = calloc<_IOVec>();
  final byte = calloc<Uint8>();
  final control = calloc<Uint8>(24);
  try {
    if (sizeOf<IntPtr>() != 8) {
      throw UnsupportedError('PipeWire capture requires 64-bit Linux');
    }
    directory = await Directory.systemTemp.createTemp('nutdart-fd-');
    final path = '${directory.path}/socket';
    final bytes = Uint8List.fromList(utf8.encode(path));
    if (bytes.length >= 108) throw StateError('Unix socket path is too long');
    address.cast<Uint16>().value = 1; // AF_UNIX
    address.asTypedList(110).setRange(2, 2 + bytes.length, bytes);
    final socket = _libc
        .lookupFunction<
          Int32 Function(Int32, Int32, Int32),
          int Function(int, int, int)
        >('socket');
    final bind = _libc
        .lookupFunction<
          Int32 Function(Int32, Pointer<Void>, Uint32),
          int Function(int, Pointer<Void>, int)
        >('bind');
    final listen = _libc
        .lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
          'listen',
        );
    final accept = _libc
        .lookupFunction<
          Int32 Function(Int32, Pointer<Void>, Pointer<Void>, Int32),
          int Function(int, Pointer<Void>, Pointer<Void>, int)
        >('accept4');
    final recv = _libc
        .lookupFunction<
          IntPtr Function(Int32, Pointer<_Message>, Int32),
          int Function(int, Pointer<_Message>, int)
        >('recvmsg');
    server = socket(1, 1 | 0x80000 | 0x800, 0); // STREAM, CLOEXEC, NONBLOCK
    if (server < 0 ||
        bind(server, address.cast(), 110) != 0 ||
        listen(server, 1) != 0) {
      throw StateError('Cannot create FD bridge');
    }
    sender = await RawSocket.connect(
      InternetAddress(path, type: InternetAddressType.unix),
      0,
    );
    peer = accept(server, nullptr, nullptr, 0x80000 | 0x800);
    if (peer < 0) throw StateError('Cannot accept FD bridge');
    final sent = sender.sendMessage(
      [
        SocketControlMessage.fromHandles([
          ResourceHandle.fromRawSocket(ownedSocket),
        ]),
      ],
      [1],
    );
    if (sent != 1) throw StateError('Cannot send PipeWire descriptor');
    vector.ref.base = byte.cast();
    vector.ref.length = 1;
    message.ref.vectors = vector;
    message.ref.vectorCount = 1;
    message.ref.control = control.cast();
    message.ref.controlLength = 24;
    final received = recv(peer, message, 0x40000000); // MSG_CMSG_CLOEXEC
    if (received != 1 ||
        message.ref.controlLength < 20 ||
        control.cast<Uint64>().value != 20 ||
        (control + 8).cast<Int32>().value != 1 ||
        (control + 12).cast<Int32>().value != 1) {
      throw StateError('Invalid SCM_RIGHTS response');
    }
    return (control + 16).cast<Int32>().value;
  } finally {
    await sender?.close();
    await ownedSocket.close();
    if (peer >= 0) closeUnixFd(peer);
    if (server >= 0) closeUnixFd(server);
    calloc.free(address);
    calloc.free(message);
    calloc.free(vector);
    calloc.free(byte);
    calloc.free(control);
    await directory?.delete(recursive: true);
  }
}
