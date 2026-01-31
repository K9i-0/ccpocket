import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/messages.dart';

class BridgeService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = false;

  Stream<ServerMessage> get messages => _messageController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;

  void connect(String url) {
    disconnect();
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      _connectionController.add(true);

      _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final msg = ServerMessage.fromJson(json);
            _messageController.add(msg);
          } catch (e) {
            _messageController.add(ErrorMessage(message: 'Parse error: $e'));
          }
        },
        onError: (error) {
          _isConnected = false;
          _connectionController.add(false);
          _messageController.add(ErrorMessage(message: 'WebSocket error: $error'));
        },
        onDone: () {
          _isConnected = false;
          _connectionController.add(false);
          _channel = null;
        },
      );
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _messageController.add(ErrorMessage(message: 'Connection failed: $e'));
    }
  }

  void send(ClientMessage message) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(message.toJson());
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (_isConnected) {
      _isConnected = false;
      _connectionController.add(false);
    }
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionController.close();
  }
}
