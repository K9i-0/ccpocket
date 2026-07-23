import 'dart:async';

import 'package:flutter/services.dart';

import '../core/logger.dart';
import '../models/messages.dart';
import 'bridge_service.dart';
import 'watch_snapshot_builder.dart';

/// Relays the existing Bridge session to the native watchOS companion app.
class WatchConnectivityService {
  static const channelName = 'ccpocket/watch_connectivity';

  final BridgeService _bridge;
  final MethodChannel _channel;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  UsageResultMessage? _usage;
  Future<void> _publishChain = Future.value();
  bool _initialized = false;

  WatchConnectivityService({
    required BridgeService bridge,
    MethodChannel channel = const MethodChannel(channelName),
  }) : _bridge = bridge,
       _channel = channel;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler(_handleWatchCall);
    _subscriptions
      ..add(_bridge.sessionList.listen((_) => _scheduleSnapshot()))
      ..add(_bridge.connectionStatus.listen(_handleConnection))
      ..add(
        _bridge.usageResults.listen((usage) {
          _usage = usage;
          _scheduleSnapshot();
        }),
      );
    await _channel.invokeMethod<void>('activate');
    _scheduleSnapshot();
  }

  void _handleConnection(BridgeConnectionState state) {
    if (state == BridgeConnectionState.connected) {
      _bridge
        ..requestSessionList()
        ..requestUsage();
    } else {
      // Usage belongs to a Bridge instance and must not leak across reconnects
      // or machine switches.
      _usage = null;
    }
    _scheduleSnapshot();
  }

  void _scheduleSnapshot() {
    if (!_initialized) return;
    _publishChain = _publishChain
        .catchError((Object error, StackTrace stackTrace) {
          logger.warning('[watch] Snapshot queue recovered', error, stackTrace);
        })
        .then((_) => _publishSnapshot());
  }

  Future<void> _publishSnapshot() async {
    final snapshot = WatchSnapshotBuilder.build(
      connected: _bridge.isConnected,
      sessions: _bridge.sessions,
      bridgeUrl: _bridge.httpBaseUrl,
      usage: _usage,
    );
    try {
      await _channel.invokeMethod<void>('updateSnapshot', snapshot);
    } catch (error, stackTrace) {
      // The paired Watch may be unavailable. A later state change retries.
      logger.warning('[watch] Snapshot update failed', error, stackTrace);
    }
  }

  Future<Object?> _handleWatchCall(MethodCall call) async {
    final arguments = call.arguments;
    final action = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : const <String, dynamic>{};
    return switch (call.method) {
      'requestRefresh' => _refresh(),
      'performAction' => _performAction(action),
      _ => throw MissingPluginException('Unknown Watch method ${call.method}'),
    };
  }

  Map<String, Object?> _refresh() {
    if (_bridge.isConnected) {
      _bridge
        ..requestSessionList()
        ..requestUsage();
    }
    _scheduleSnapshot();
    return {'accepted': true};
  }

  Map<String, Object?> _performAction(Map<String, dynamic> action) {
    final type = action['type'] as String?;
    final sessionId = action['sessionId'] as String?;
    if (type == null || sessionId == null) {
      return _rejected('Invalid Watch action');
    }
    // Never queue a time-sensitive Watch action across a Bridge reconnect.
    // The permission may belong to an entirely different process by then.
    if (!_bridge.isConnected) return _rejected('Bridge is disconnected');
    final session = _bridge.sessions
        .where((candidate) => candidate.id == sessionId)
        .firstOrNull;
    if (session == null) return _rejected('Session is no longer active');

    if (type == 'input') {
      final text = (action['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return _rejected('Message is empty');
      _bridge.send(ClientMessage.input(text, sessionId: sessionId));
      return _accepted();
    }

    final permission = session.pendingPermission;
    final toolUseId = action['toolUseId'] as String?;
    if (permission == null || permission.toolUseId != toolUseId) {
      return _rejected('This request has already changed');
    }

    switch (type) {
      case 'approve':
        if (!permission.canApprove) return _rejected('Approval unavailable');
        _bridge.markToolUseResponded(sessionId, permission.toolUseId);
        _bridge.send(
          ClientMessage.approve(permission.toolUseId, sessionId: sessionId),
        );
        _bridge.clearSessionPermission(sessionId);
      case 'reject':
        if (!permission.canDecline) return _rejected('Rejection unavailable');
        _bridge.markToolUseResponded(sessionId, permission.toolUseId);
        _bridge.send(
          ClientMessage.reject(permission.toolUseId, sessionId: sessionId),
        );
        _bridge.clearSessionPermission(sessionId);
      case 'answer':
        final rawAnswers = action['answers'];
        if (rawAnswers is! Map) return _rejected('Invalid answer');
        final answers = <String, List<String>>{};
        for (final entry in rawAnswers.entries) {
          final values = entry.value;
          if (values is List) {
            answers[entry.key.toString()] = values.whereType<String>().toList(
              growable: false,
            );
          }
        }
        final result = WatchSnapshotBuilder.buildAnswerResult(
          permission: permission,
          answers: answers,
        );
        if (result == null) return _rejected('Complete required answers');
        _bridge.markToolUseResponded(sessionId, permission.toolUseId);
        _bridge.send(
          ClientMessage.answer(
            permission.toolUseId,
            result,
            sessionId: sessionId,
          ),
        );
        _bridge.clearSessionPermission(sessionId);
      default:
        return _rejected('Unsupported Watch action');
    }
    return _accepted();
  }

  Map<String, Object?> _accepted() => const {'accepted': true};

  Map<String, Object?> _rejected(String message) => {
    'accepted': false,
    'message': message,
  };

  Future<void> dispose() async {
    _initialized = false;
    _channel.setMethodCallHandler(null);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}
