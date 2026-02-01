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
  void stopSession(String sessionId);
  void requestFileList(String projectPath);
  void requestSessionList();

  /// Stream of file paths from the project.
  Stream<List<String>> get fileList;

  /// Stream of active sessions.
  Stream<List<SessionInfo>> get sessionList;

  /// Buffered past history from resume_session, consumed by ChatScreen.
  PastHistoryMessage? pendingPastHistory;
}
