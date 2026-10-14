import 'dart:ffi';
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'unix_fd.dart';

/// Native pipeline operations run off the UI isolate. No native callbacks enter
/// Dart. GStreamer handles memory types, strides and color conversion.
class CapturedPixels {
  final Uint8List png;
  final int? runningTimeNs;
  final int? boundaryNs;
  const CapturedPixels(this.png, {this.runningTimeNs, this.boundaryNs});
}

abstract interface class PortalFrameSource {
  Future<CapturedPixels> capture({bool fresh = false});
  Future<void> close();
}

class PipeWireFrames implements PortalFrameSource {
  final int _pipeline;
  final int _sink;
  final int _fd;
  bool _closed = false;
  Future<void>? _closing;
  Future<void> _pending = Future.value();
  PipeWireFrames._(this._pipeline, this._sink, this._fd);

  /// Takes ownership of fd, including on failure.
  static Future<PipeWireFrames> open(int fd, int node) async {
    try {
      final addresses = await Isolate.run(() => _Gst().open(fd, node));
      return PipeWireFrames._(addresses.$1, addresses.$2, fd);
    } catch (_) {
      closeUnixFd(fd);
      rethrow;
    }
  }

  /// Wait for the next available frame; keep at most one queued frame.
  @override
  Future<CapturedPixels> capture({bool fresh = false}) {
    if (_closed) throw StateError('PipeWire stream is closed');
    final sink = _sink, pipeline = _pipeline;
    final result = _pending.then(
      (_) => Isolate.run(() => _Gst().capture(pipeline, sink, fresh)),
    );
    _pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Internal native-test seam. No portal or desktop access.
  static Future<PipeWireFrames> testPattern({int numBuffers = -1}) async {
    if (numBuffers == 0 || numBuffers < -1) {
      throw ArgumentError.value(numBuffers);
    }
    final addresses = await Isolate.run(
      () => _Gst().openDescription(
        'videotestsrc is-live=true pattern=black num-buffers=$numBuffers ! '
        'video/x-raw,format=RGB,width=64,height=64,framerate=30/1 ! '
        'pngenc ! appsink name=frames max-buffers=1 drop=true sync=false',
      ),
    );
    return PipeWireFrames._(addresses.$1, addresses.$2, -1);
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    await _pending;
    final pipeline = _pipeline, sink = _sink;
    try {
      await Isolate.run(() => _Gst().close(pipeline, sink));
    } finally {
      if (_fd >= 0) closeUnixFd(_fd);
    }
  }
}

class _Gst {
  final gst = DynamicLibrary.open('libgstreamer-1.0.so.0');
  final app = DynamicLibrary.open('libgstapp-1.0.so.0');
  final glib = DynamicLibrary.open('libglib-2.0.so.0');
  late final unref = gst
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('gst_object_unref');
  late final state = gst
      .lookupFunction<
        Int32 Function(Pointer<Void>, Int32),
        int Function(Pointer<Void>, int)
      >('gst_element_set_state');

  (int, int) open(int fd, int node) => openDescription(
    'pipewiresrc fd=$fd path=$node do-timestamp=true ! '
    'videoconvert ! video/x-raw,format=RGB ! pngenc compression-level=1 ! '
    'appsink name=frames max-buffers=1 drop=true sync=false',
  );

  (int, int) openDescription(String pipelineDescription) {
    final init = gst
        .lookupFunction<
          Void Function(Pointer<Void>, Pointer<Void>),
          void Function(Pointer<Void>, Pointer<Void>)
        >('gst_init');
    final parse = gst
        .lookupFunction<
          Pointer<Void> Function(Pointer<Utf8>, Pointer<Pointer<Void>>),
          Pointer<Void> Function(Pointer<Utf8>, Pointer<Pointer<Void>>)
        >('gst_parse_launch');
    final get = gst
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Void>, Pointer<Utf8>)
        >('gst_bin_get_by_name');
    init(nullptr, nullptr);
    final description = pipelineDescription.toNativeUtf8();
    final error = calloc<Pointer<Void>>();
    Pointer<Void> pipeline = nullptr, sink = nullptr;
    final name = 'frames'.toNativeUtf8();
    try {
      pipeline = parse(description, error);
      if (error.value != nullptr || pipeline == nullptr) {
        throw StateError(
          'Cannot create PipeWire pipeline; install GStreamer pipewire, videoconvert, png and app plugins',
        );
      }
      sink = get(pipeline, name);
      if (sink == nullptr || state(pipeline, 4) == 0) {
        throw StateError('Cannot start PipeWire pipeline');
      }
      return (pipeline.address, sink.address);
    } catch (_) {
      if (pipeline != nullptr) {
        state(pipeline, 1);
        unref(pipeline);
      }
      if (sink != nullptr) unref(sink);
      rethrow;
    } finally {
      if (error.value != nullptr) {
        glib.lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('g_error_free')(error.value);
      }
      calloc.free(error);
      calloc.free(description);
      calloc.free(name);
    }
  }

  CapturedPixels capture(int pipelineAddress, int address, bool fresh) {
    final pull = app
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Uint64),
          Pointer<Void> Function(Pointer<Void>, int)
        >('gst_app_sink_try_pull_sample');
    final bufferOf = gst
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('gst_sample_get_buffer');
    final sizeOfBuffer = gst
        .lookupFunction<
          UintPtr Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('gst_buffer_get_size');
    final extract = gst
        .lookupFunction<
          UintPtr Function(Pointer<Void>, UintPtr, Pointer<Void>, UintPtr),
          int Function(Pointer<Void>, int, Pointer<Void>, int)
        >('gst_buffer_extract');
    final release = gst
        .lookupFunction<
          Void Function(Pointer<Void>),
          void Function(Pointer<Void>)
        >('gst_sample_unref');
    final segmentOf = gst
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>),
          Pointer<Void> Function(Pointer<Void>)
        >('gst_sample_get_segment');
    final toRunning = gst
        .lookupFunction<
          Uint64 Function(Pointer<Void>, Int32, Uint64),
          int Function(Pointer<Void>, int, int)
        >('gst_segment_to_running_time');
    final currentTime = gst
        .lookupFunction<
          Uint64 Function(Pointer<Void>),
          int Function(Pointer<Void>)
        >('gst_element_get_current_running_time');
    final pipeline = Pointer<Void>.fromAddress(pipelineAddress);
    // Initial negotiation can precede clock selection. Wait off the UI isolate.
    if (fresh && currentTime(pipeline) == -1) {
      gst.lookupFunction<
        Int32 Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, Uint64),
        int Function(Pointer<Void>, Pointer<Int32>, Pointer<Int32>, int)
      >('gst_element_get_state')(pipeline, nullptr, nullptr, 2000000000);
    }
    final boundary = fresh ? currentTime(pipeline) : null;
    if (boundary == -1) throw StateError('Pipeline clock is unavailable');
    final watch = Stopwatch()..start();
    while (watch.elapsedMicroseconds < 10000000) {
      final remaining = 10000000000 - watch.elapsedMicroseconds * 1000;
      if (remaining <= 0) break;
      final sample = pull(Pointer.fromAddress(address), remaining);
      if (sample == nullptr) {
        throw TimeoutException(
          'No eligible PipeWire frame within 10 seconds; the desktop may be static or the stream stopped',
        );
      }
      Pointer<Uint8> data = nullptr;
      try {
        final buffer = bufferOf(sample);
        if (buffer == nullptr) throw StateError('Empty PipeWire sample');
        final pts = buffer.cast<_GstBuffer>().ref.pts;
        final segment = segmentOf(sample);
        final running = pts == -1 || segment == nullptr
            ? -1
            : toRunning(segment, 3, pts); // GST_FORMAT_TIME
        if (fresh && (running == -1 || running <= boundary!)) continue;
        final length = sizeOfBuffer(buffer);
        if (length < 24 || length > 256 * 1024 * 1024) {
          throw StateError('Invalid frame size: $length');
        }
        data = calloc<Uint8>(length);
        if (extract(buffer, 0, data.cast(), length) != length) {
          throw StateError('Incomplete PipeWire frame');
        }
        return CapturedPixels(
          Uint8List.fromList(data.asTypedList(length)),
          runningTimeNs: running == -1 ? null : running,
          boundaryNs: boundary,
        );
      } finally {
        if (data != nullptr) calloc.free(data);
        release(sample);
      }
    }
    throw TimeoutException('No frame newer than the capture boundary');
  }

  void close(int pipelineAddress, int sinkAddress) {
    final pipeline = Pointer<Void>.fromAddress(pipelineAddress);
    state(pipeline, 1);
    unref(Pointer<Void>.fromAddress(sinkAddress));
    unref(pipeline);
  }
}

// Public GStreamer 1.x ABI from gstminiobject.h and gstbuffer.h.
// Unlike a hard-coded byte offset, Struct alignment follows the Linux ABI.
final class _GstMiniObject extends Struct {
  @UintPtr()
  external int type;
  @Int32()
  external int refcount;
  @Int32()
  external int lockstate;
  @Uint32()
  external int flags;
  external Pointer<Void> copy;
  external Pointer<Void> dispose;
  external Pointer<Void> free;
  @Uint32()
  external int privateUint;
  external Pointer<Void> privatePointer;
}

final class _GstBuffer extends Struct {
  external _GstMiniObject miniObject;
  external Pointer<Void> pool;
  @Uint64()
  external int pts;
  @Uint64()
  external int dts;
  @Uint64()
  external int duration;
  @Uint64()
  external int offset;
  @Uint64()
  external int offsetEnd;
}
