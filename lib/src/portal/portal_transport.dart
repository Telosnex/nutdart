import 'dart:async';

import 'package:dbus/dbus.dart';

import 'unix_fd.dart';

const portalName = 'org.freedesktop.portal.Desktop';
const portalPath = '/org/freedesktop/portal/desktop';
const portalInterface = 'org.freedesktop.portal.';

/// Internal transport seam for deterministic tests without a desktop.
abstract interface class PortalTransport {
  Future<Map<String, DBusValue>> request(
    String interface,
    String method,
    List<DBusValue> arguments,
    Map<String, DBusValue> options,
  );
  Future<int> openPipeWire(String session);
  Future<void> notify(String method, List<DBusValue> arguments);
  Stream<void> closed(String session);
  Future<void> closeSession(String session);

  /// Create an Inhibit monitor session and return its handle.
  /// [onState] receives every StateChanged for that handle, including any
  /// that arrive before this future completes.
  Future<String> createStateMonitor(
    void Function(String monitor, Map<String, DBusValue> state) onState,
  );

  /// Acknowledge a Query End state within one second of receiving it.
  Future<void> queryEndResponse(String monitor);
  Future<void> close();
}

class PortalResponseException implements Exception {
  final String method;

  /// 1: user cancelled. 2: portal failed.
  final int code;
  const PortalResponseException(this.method, this.code);
  @override
  String toString() => '$method: portal response $code';
}

class DBusPortalTransport implements PortalTransport {
  final DBusClient _client = DBusClient.session();
  final Duration timeout;
  int _counter = 0;
  DBusPortalTransport({this.timeout = const Duration(minutes: 3)});

  Future<String> _portalOwner() async {
    final owner =
        await _client.getNameOwner(portalName) ??
        await _client
            .startServiceByName(portalName)
            .then((_) => _client.getNameOwner(portalName));
    if (owner == null) throw StateError('Desktop portal is unavailable');
    return owner;
  }

  DBusRemoteObject _object(String path) =>
      DBusRemoteObject(_client, name: portalName, path: DBusObjectPath(path));

  @override
  Future<Map<String, DBusValue>> request(
    String interface,
    String method,
    List<DBusValue> arguments,
    Map<String, DBusValue> options,
  ) async {
    // Connect and resolve the sender before the signal subscription.
    final owner = await _portalOwner();
    final token = 'nutdart_${++_counter}';
    final sender = _client.uniqueName.substring(1).replaceAll('.', '_');
    final path = '$portalPath/request/$sender/$token';
    final response = Completer<DBusSignal>();
    final subscription =
        DBusSignalStream(
          _client,
          sender: owner,
          path: DBusObjectPath(path),
          interface: '${portalInterface}Request',
          name: 'Response',
          signature: DBusSignature('ua{sv}'),
        ).listen(
          (signal) {
            if (!response.isCompleted) response.complete(signal);
          },
          onError: (Object error, StackTrace stack) {
            if (!response.isCompleted) response.completeError(error, stack);
          },
        );
    // Attach an error handler before the method call can fail.
    final timer = Timer(timeout, () {
      if (!response.isCompleted) {
        response.completeError(
          TimeoutException('Portal consent timed out', timeout),
        );
      }
    });
    final result = response.future;
    unawaited(result.then<void>((_) {}, onError: (Object _) {}));
    try {
      // A bus round trip orders AddMatch before the portal method call.
      // Not Peer.Ping: Flatpak denies it to the bus, Snap to every peer.
      await _client.getNameOwner(portalName).timeout(timeout);
      final reply = await _object(portalPath)
          .callMethod('$portalInterface$interface', method, [
            ...arguments,
            DBusDict.stringVariant({
              ...options,
              'handle_token': DBusString(token),
            }),
          ], replySignature: DBusSignature('o'))
          .timeout(timeout);
      if (reply.returnValues.single.asObjectPath().value != path) {
        throw StateError('Portal returned an unexpected request path');
      }
      final signal = await result;
      final code = signal.values[0].asUint32();
      if (code != 0) throw PortalResponseException(method, code);
      return signal.values[1].asStringVariantDict();
    } catch (_) {
      // Cancel pending consent. Keep the original error if Close fails.
      try {
        await _object(path)
            .callMethod('${portalInterface}Request', 'Close', [])
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      rethrow;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }

  @override
  Future<int> openPipeWire(String session) async {
    final reply = await _object(portalPath).callMethod(
      '${portalInterface}ScreenCast',
      'OpenPipeWireRemote',
      [DBusObjectPath(session), DBusDict.stringVariant({})],
      replySignature: DBusSignature('h'),
    );
    return takeUnixFd(reply.returnValues.single.asUnixFd());
  }

  @override
  Future<void> notify(String method, List<DBusValue> arguments) async {
    await _object(portalPath)
        .callMethod(
          '${portalInterface}RemoteDesktop',
          method,
          arguments,
          replySignature: DBusSignature(''),
        )
        .timeout(const Duration(seconds: 10));
  }

  @override
  Stream<void> closed(String session) => DBusRemoteObjectSignalStream(
    object: _object(session),
    interface: '${portalInterface}Session',
    name: 'Closed',
    signature: DBusSignature('a{sv}'),
  ).map((_) {});

  @override
  Future<void> closeSession(String session) async {
    await _monitors.remove(session)?.cancel();
    await _object(session)
        .callMethod('${portalInterface}Session', 'Close', [])
        .timeout(const Duration(seconds: 5));
  }

  @override
  Future<String> createStateMonitor(
    void Function(String monitor, Map<String, DBusValue> state) onState,
  ) async {
    final owner = await _portalOwner();
    String? handle;
    final early = <(String, Map<String, DBusValue>)>[];
    // Subscribe before CreateMonitor so that the first state is not lost.
    final subscription =
        DBusSignalStream(
          _client,
          sender: owner,
          path: DBusObjectPath(portalPath),
          interface: '${portalInterface}Inhibit',
          name: 'StateChanged',
          signature: DBusSignature('oa{sv}'),
        ).listen((signal) {
          final session = signal.values[0].asObjectPath().value;
          final state = signal.values[1].asStringVariantDict();
          if (handle == null) {
            early.add((session, state));
          } else if (session == handle) {
            onState(session, state);
          }
        });
    try {
      await _client.getNameOwner(portalName).timeout(timeout); // request()
      final result = await request(
        'Inhibit',
        'CreateMonitor',
        [const DBusString('')],
        {
          'session_handle_token': DBusString(
            'nutdart_monitor_${DateTime.now().microsecondsSinceEpoch}',
          ),
        },
      );
      // The portal returns this object path as a string (spec erratum).
      final path = result['session_handle']?.asString();
      if (path == null) throw StateError('Portal returned no monitor handle');
      handle = path;
      for (final (session, state) in early) {
        if (session == path) onState(path, state);
      }
      early.clear();
      _monitors[path] = subscription;
      return path;
    } catch (_) {
      await subscription.cancel();
      rethrow;
    }
  }

  final _monitors = <String, StreamSubscription<DBusSignal>>{};

  @override
  Future<void> queryEndResponse(String monitor) async {
    await _object(portalPath)
        .callMethod('${portalInterface}Inhibit', 'QueryEndResponse', [
          DBusObjectPath(monitor),
        ], replySignature: DBusSignature(''))
        .timeout(const Duration(seconds: 1));
  }

  @override
  Future<void> close() async {
    for (final subscription in _monitors.values) {
      await subscription.cancel();
    }
    _monitors.clear();
    await _client.close();
  }
}
