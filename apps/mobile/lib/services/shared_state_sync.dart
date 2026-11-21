import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/messages.dart';
import 'bridge_service.dart';
import 'bridge_service_helpers.dart';

/// Connects one kind of locally stored data to the Bridge's shared state.
///
/// The local copy stays the place the app reads from; the adapter only tells
/// [SharedStateSync] what is stored and takes over what the Bridge says.
abstract class SharedStateAdapter {
  /// Whether [key] belongs to this adapter.
  bool owns(String key);

  /// Whether local entries are offered to a Bridge that does not have them.
  bool get seedable => true;

  /// Every local entry, by shared key.
  Future<Map<String, Object>> readLocal();

  /// Take over the Bridge's value for [key]; null means the key is absent.
  /// Must not call [SharedStateSync.set].
  Future<void> applyRemote(String key, Object? value);
}

typedef _PendingWrite = ({String id, Object? value, bool max});

/// Keeps settings and per-project / per-session data in step with the
/// Bridge, so every device connected to it sees the same values
/// (docs/shared-state.md).
///
/// - A local change goes through [set]: it is sent to the Bridge and kept as
///   pending until the Bridge echoes it; while pending, values from the
///   Bridge for that key are ignored.
/// - After each connect the Bridge's snapshot replaces the local copies.
/// - The first time a Bridge store is seen, local entries it does not have
///   are offered to it (the migration from device-only storage).
class SharedStateSync {
  /// The app-wide instance, for the stores that are plain helpers.
  static SharedStateSync? instance;

  static const seededStoreIdsKey = 'shared_state_seeded_store_ids_v1';

  final BridgeService _bridge;
  final SharedPreferences _prefs;
  final _adapters = <SharedStateAdapter>[];
  final _pending = <String, _PendingWrite>{};
  final _random = Random();
  late final StreamSubscription<bool> _readySub;
  late final StreamSubscription<ServerMessage> _messageSub;
  late final StreamSubscription<BridgeConnectionState> _connectionSub;

  bool _active = false;
  bool _unsupported = false;
  bool _disposed = false;
  int _sequence = 0;
  String? _storeId;
  String? _awaitingSeedFor;
  Future<void> _work = Future.value();

  SharedStateSync({
    required BridgeService bridge,
    required SharedPreferences prefs,
  }) : _bridge = bridge,
       _prefs = prefs {
    _readySub = bridge.sharedStateReady.listen(_onReady);
    _messageSub = bridge.sharedStateMessages.listen(_onMessage);
    _connectionSub = bridge.connectionStatus.listen((status) {
      if (status == BridgeConnectionState.connected) return;
      _active = false;
      _unsupported = false;
      _awaitingSeedFor = null;
    });
  }

  void register(SharedStateAdapter adapter) => _adapters.add(adapter);

  void unregister(SharedStateAdapter adapter) => _adapters.remove(adapter);

  /// Whether the connected Bridge shares state between devices.
  bool get isActive => _active;

  /// Share a local change. [value] must be JSON; null deletes the key. With
  /// [max], the Bridge keeps a stored string that is not smaller.
  void set(String key, Object? value, {bool max = false}) {
    if (_disposed || _unsupported) return;
    final id = '${_sequence++}-${_random.nextInt(1 << 32).toRadixString(16)}';
    _pending[key] = (id: id, value: value, max: max);
    if (_active) _send(key);
  }

  /// Completes when the messages received so far are applied.
  Future<void> get settled => _work;

  void _send(String key) {
    final write = _pending[key];
    if (write == null) return;
    _bridge.send(
      ClientMessage.setSharedState(
        key: key,
        value: write.value,
        mutationId: write.id,
        max: write.max,
      ),
    );
  }

  void _onReady(bool supported) {
    if (_disposed) return;
    if (!supported) {
      // The data stays on this device, as before shared state existed.
      _active = false;
      _unsupported = true;
      _pending.clear();
      return;
    }
    _unsupported = false;
    _active = true;
    _bridge.send(ClientMessage.getSharedState());
  }

  void _onMessage(ServerMessage message) {
    if (_disposed) return;
    _work = _work.then((_) async {
      if (_disposed) return;
      try {
        switch (message) {
          case SharedStateMessage():
            await _applySnapshot(message);
          case SharedStateChangedMessage():
            await _applyChange(message);
          case SharedStateSeededMessage(:final storeId):
            if (_awaitingSeedFor == storeId) {
              _awaitingSeedFor = null;
              await _markSeeded(storeId);
            }
          default:
            break;
        }
      } catch (_) {
        // One unreadable entry must not stop the following messages.
      }
    });
  }

  bool _isSeeded(String storeId) =>
      (_prefs.getStringList(seededStoreIdsKey) ?? const []).contains(storeId);

  Future<void> _markSeeded(String storeId) async {
    final ids = _prefs.getStringList(seededStoreIdsKey) ?? const [];
    if (ids.contains(storeId)) return;
    // A device meets few Bridges; keep the list from growing forever anyway.
    final next = [...ids, storeId];
    await _prefs.setStringList(
      seededStoreIdsKey,
      next.length > 50 ? next.sublist(next.length - 50) : next,
    );
  }

  Future<void> _applySnapshot(SharedStateMessage message) async {
    // Writes made for another Bridge do not belong to this one.
    if (_storeId != null && _storeId != message.storeId) _pending.clear();
    _storeId = message.storeId;
    final seeded = _isSeeded(message.storeId);
    final remote = message.entries;
    final seed = <String, Object>{};

    for (final adapter in List.of(_adapters)) {
      final local = await adapter.readLocal();
      for (final entry in remote.entries) {
        final key = entry.key;
        if (!adapter.owns(key) || _pending.containsKey(key)) continue;
        if (_sameValue(local[key], entry.value)) continue;
        await adapter.applyRemote(key, entry.value);
      }
      for (final entry in local.entries) {
        final key = entry.key;
        if (remote.containsKey(key) || _pending.containsKey(key)) continue;
        if (seeded) {
          // Removed on another device while this one was away.
          await adapter.applyRemote(key, null);
        } else if (adapter.seedable) {
          seed[key] = entry.value;
        }
      }
    }

    if (!seeded && _awaitingSeedFor != message.storeId) {
      if (seed.isEmpty) {
        await _markSeeded(message.storeId);
      } else if (_active) {
        // Marked as seeded only when the Bridge confirms, so a connection
        // lost here offers the entries again.
        _awaitingSeedFor = message.storeId;
        _bridge.send(ClientMessage.seedSharedState(seed));
      }
    }

    // Writes that never reached the Bridge (made offline, or sent on a
    // connection that broke) go out again.
    if (_active) {
      for (final key in _pending.keys.toList()) {
        _send(key);
      }
    }
  }

  Future<void> _applyChange(SharedStateChangedMessage message) async {
    final pending = _pending[message.key];
    if (pending != null) {
      // An echo of an older write, or another device's write that the
      // pending one is about to replace.
      if (message.mutationId != pending.id) return;
      _pending.remove(message.key);
      // The Bridge may have kept another value (`max`, or a full store).
      if (_sameValue(pending.value, message.value)) return;
    }
    for (final adapter in List.of(_adapters)) {
      if (adapter.owns(message.key)) {
        await adapter.applyRemote(message.key, message.value);
      }
    }
  }

  bool _sameValue(Object? a, Object? b) => canonicalJson(a) == canonicalJson(b);

  void dispose() {
    _disposed = true;
    _readySub.cancel();
    _messageSub.cancel();
    _connectionSub.cancel();
    if (identical(instance, this)) instance = null;
  }
}
