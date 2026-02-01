import '../models/messages.dart';

/// Abstract interface that [ChatScreen] depends on.
/// Both [BridgeService] (real WebSocket) and [MockBridgeService] implement this.
abstract class BridgeServiceBase {
  Stream<ServerMessage> get messages;
  String? get httpBaseUrl;
  bool get isConnected;
  Stream<BridgeConnectionState> get connectionStatus;
  void send(ClientMessage message);
  void requestSessionHistory(String sessionId);

  /// Buffered past history from resume_session, consumed by ChatScreen.
  PastHistoryMessage? pendingPastHistory;
}
