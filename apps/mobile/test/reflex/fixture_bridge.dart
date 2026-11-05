/// In-memory Bridge for Reflex-style behavior tests.
///
/// The real [BridgeService] runs unchanged; only the WebSocket is replaced by
/// an in-memory pair (`package:web_socket/testing.dart`). The fixture answers
/// client requests through registered handlers and fails the test on any
/// request type it does not know, so no test silently depends on a Bridge
/// behavior it never declared. See docs/reflex-prototype.md.
library;

import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/models/protocol_version.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:web_socket/testing.dart';
import 'package:web_socket/web_socket.dart';
import 'package:web_socket_channel/adapter_web_socket_channel.dart';

typedef JsonMap = Map<String, dynamic>;

/// Returns the server messages answering one client request.
typedef FixtureHandler = List<JsonMap> Function(JsonMap request);

class FixtureBridge {
  FixtureBridge({Map<String, FixtureHandler>? handlers, Set<String>? ignored})
    : _handlers = {...?handlers},
      _ignored = {...defaultIgnoredRequests, ...?ignored};

  /// Requests the client sends on its own that need no answer in these tests.
  static const defaultIgnoredRequests = <String>{'client_capabilities'};

  final Map<String, FixtureHandler> _handlers;
  final Set<String> _ignored;

  /// Every request the client sent, in order.
  final List<JsonMap> received = [];

  /// Request types that had no handler and were not ignored.
  final List<String> unhandled = [];

  WebSocket? _server;
  final _receivedController = StreamController<JsonMap>.broadcast();

  void on(String type, FixtureHandler handler) => _handlers[type] = handler;

  /// Creates a [BridgeService] connected to this fixture.
  BridgeService connect({Duration? recentSessionsRequestTimeout}) {
    final service = BridgeService(
      recentSessionsRequestTimeout:
          recentSessionsRequestTimeout ?? const Duration(seconds: 10),
      channelFactory: (_) {
        final (client, server) = fakes();
        _attach(server);
        return AdapterWebSocketChannel(client);
      },
    );
    service.connect('ws://fixture.invalid:8765');
    return service;
  }

  void _attach(WebSocket server) {
    _server = server;
    server.events.listen((event) {
      if (event is! TextDataReceived) return;
      final request = jsonDecode(event.text) as JsonMap;
      received.add(request);
      _receivedController.add(request);
      final type = request['type'] as String? ?? '<no type>';
      final handler = _handlers[type];
      if (handler != null) {
        handler(request).forEach(push);
      } else if (!_ignored.contains(type)) {
        unhandled.add(type);
      }
    });
    // A Bridge announces itself with session_list right after accepting.
    push(sessionListMessage());
  }

  /// Sends a server message to the client.
  void push(JsonMap message) => _server!.sendText(jsonEncode(message));

  /// Waits for the next client request of [type] (or returns one already
  /// received after [after]).
  Future<JsonMap> nextRequest(
    String type, {
    bool Function(JsonMap request)? where,
    Duration timeout = const Duration(seconds: 2),
  }) => _receivedController.stream
      .firstWhere((r) => r['type'] == type && (where?.call(r) ?? true))
      .timeout(timeout);

  List<JsonMap> requestsOf(String type) =>
      received.where((r) => r['type'] == type).toList();

  static JsonMap sessionListMessage({List<JsonMap> sessions = const []}) => {
    'type': 'session_list',
    'sessions': sessions,
    'protocolVersion': appProtocolMaxVersion,
    'minimumProtocolVersion': appProtocolMinVersion,
  };
}
