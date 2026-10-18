import 'dart:io';

/// Web stub for [takeUnixFd] in `unix_fd_ffi.dart`. The portal backend needs
/// dart:ffi and a Linux desktop session.
void closeUnixFd(int fd) =>
    throw UnsupportedError('Unix descriptors require dart:ffi');

Future<int> takeUnixFd(ResourceHandle handle) async =>
    throw UnsupportedError('Unix descriptors require dart:ffi');
