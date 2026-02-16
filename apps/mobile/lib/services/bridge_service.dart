import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/messages.dart';
import 'bridge_service_base.dart';

class BridgeService implements BridgeServiceBase {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedMessageController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _galleryController = StreamController<List<GalleryImage>>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();
  final _diffResultController = StreamController<DiffResultMessage>.broadcast();
  final _worktreeListController =
      StreamController<WorktreeListMessage>.broadcast();
  final _windowListController = StreamController<List<WindowInfo>>.broadcast();
  final _screenshotResultController =
      StreamController<ScreenshotResultMessage>.broadcast();
  final _debugBundleController =
      StreamController<DebugBundleMessage>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();

  BridgeConnectionState _connectionState = BridgeConnectionState.disconnected;
  final List<ClientMessage> _messageQueue = [];
  List<SessionInfo> _sessions = [];
  List<RecentSession> _recentSessions = [];
  List<GalleryImage> _galleryImages = [];
  List<String> _projectHistory = [];

  // Pagination state
  bool _recentSessionsHasMore = false;
  bool _appendMode = false;
  String? _currentProjectFilter;

  // Auto-reconnect
  String? _lastUrl;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const _maxReconnectDelay = 30;
  bool _intentionalDisconnect = false;

  @override
  Stream<ServerMessage> get messages => _messageController.stream;
  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;
  @override
  Stream<List<SessionInfo>> get sessionList => _sessionListController.stream;
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;
  Stream<List<GalleryImage>> get galleryStream => _galleryController.stream;
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;
  @override
  Stream<List<String>> get fileList => _fileListController.stream;
  Stream<DiffResultMessage> get diffResults => _diffResultController.stream;
  Stream<WorktreeListMessage> get worktreeList =>
      _worktreeListController.stream;
  Stream<List<WindowInfo>> get windowList => _windowListController.stream;
  Stream<ScreenshotResultMessage> get screenshotResults =>
      _screenshotResultController.stream;
  Stream<DebugBundleMessage> get debugBundles => _debugBundleController.stream;
  Stream<UsageResultMessage> get usageResults => _usageController.stream;
  BridgeConnectionState get currentBridgeConnectionState => _connectionState;
  @override
  bool get isConnected => _connectionState == BridgeConnectionState.connected;
  List<SessionInfo> get sessions => _sessions;
  List<RecentSession> get recentSessions => _recentSessions;
  bool get recentSessionsHasMore => _recentSessionsHasMore;
  String? get currentProjectFilter => _currentProjectFilter;
  List<GalleryImage> get galleryImages => _galleryImages;
  List<String> get projectHistory => _projectHistory;

  /// Derive HTTP base URL from the WebSocket URL.
  /// Example: ws://host:8765/path?query=1 -> http://host:8765
  @override
  String? get httpBaseUrl {
    final url = _lastUrl;
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final scheme = uri.scheme == 'wss' ? 'https' : 'http';
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '$scheme://${uri.host}$port';
  }

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeyApiKey = 'bridge_api_key';

  void _setBridgeConnectionState(BridgeConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  void connect(String url) {
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _lastUrl = url;

    _setBridgeConnectionState(BridgeConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _setBridgeConnectionState(BridgeConnectionState.connected);
      _reconnectAttempt = 0;
      _flushMessageQueue();

      _channelSub = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final sessionId = json['sessionId'] as String?;
            final msg = ServerMessage.fromJson(json);
            switch (msg) {
              case SessionListMessage(:final sessions):
                _sessions = sessions;
                _sessionListController.add(sessions);
              case RecentSessionsMessage(:final sessions, :final hasMore):
                _recentSessionsHasMore = hasMore;
                if (_appendMode) {
                  _recentSessions = [..._recentSessions, ...sessions];
                } else {
                  _recentSessions = sessions;
                }
                _appendMode = false;
                _recentSessionsController.add(_recentSessions);
              case PastHistoryMessage():
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case GalleryListMessage(:final images):
                _galleryImages = images;
                _galleryController.add(images);
              case GalleryNewImageMessage(:final image):
                _galleryImages = [image, ..._galleryImages];
                _galleryController.add(_galleryImages);
              case FileListMessage(:final files):
                _fileListController.add(files);
              case ProjectHistoryMessage(:final projects):
                _projectHistory = projects;
                _projectHistoryController.add(projects);
              case DiffResultMessage():
                _diffResultController.add(msg);
              case WorktreeListMessage():
                _worktreeListController.add(msg);
              case WindowListMessage(:final windows):
                _windowListController.add(windows);
              case ScreenshotResultMessage():
                _screenshotResultController.add(msg);
              case DebugBundleMessage():
                _debugBundleController.add(msg);
              case UsageResultMessage():
                _usageController.add(msg);
              case WorktreeRemovedMessage():
                _messageController.add(msg);
              case StatusMessage(:final status):
                // Patch cached session list so the session list screen
                // reflects status changes in real-time.
                if (sessionId != null) {
                  _patchSessionStatus(sessionId, status);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              default:
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
            }
          } catch (e) {
            final errorMsg = ErrorMessage(message: 'Parse error: $e');
            _taggedMessageController.add((errorMsg, null));
            _messageController.add(errorMsg);
          }
        },
        onError: (error) {
          _setBridgeConnectionState(BridgeConnectionState.disconnected);
          _messageController.add(
            ErrorMessage(message: 'WebSocket error: $error'),
          );
          _scheduleReconnect();
        },
        onDone: () {
          _channel = null;
          if (!_intentionalDisconnect) {
            _setBridgeConnectionState(BridgeConnectionState.disconnected);
            _scheduleReconnect();
          } else {
            _setBridgeConnectionState(BridgeConnectionState.disconnected);
          }
        },
      );
    } catch (e) {
      _setBridgeConnectionState(BridgeConnectionState.disconnected);
      _messageController.add(ErrorMessage(message: 'Connection failed: $e'));
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _lastUrl == null) return;

    _reconnectAttempt++;
    final delay = min(pow(2, _reconnectAttempt).toInt(), _maxReconnectDelay);
    _setBridgeConnectionState(BridgeConnectionState.reconnecting);
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_lastUrl != null && !_intentionalDisconnect) {
        connect(_lastUrl!);
      }
    });
  }

  @override
  void send(ClientMessage message) {
    if (_channel != null && isConnected) {
      _channel!.sink.add(message.toJson());
    } else {
      _messageQueue.add(message);
    }
  }

  void _flushMessageQueue() {
    if (_messageQueue.isEmpty || !isConnected) return;
    final queued = List<ClientMessage>.from(_messageQueue);
    _messageQueue.clear();
    for (final msg in queued) {
      send(msg);
    }
  }

  @override
  void requestSessionList() {
    send(ClientMessage.listSessions());
  }

  void requestRecentSessions({int? limit, int? offset, String? projectPath}) {
    if (offset == null || offset == 0) {
      _appendMode = false;
    }
    send(
      ClientMessage.listRecentSessions(
        limit: limit,
        offset: offset,
        projectPath: projectPath,
      ),
    );
  }

  /// Load the next page of recent sessions (append mode).
  void loadMoreRecentSessions({int pageSize = 20}) {
    _appendMode = true;
    send(
      ClientMessage.listRecentSessions(
        limit: pageSize,
        offset: _recentSessions.length,
        projectPath: _currentProjectFilter,
      ),
    );
  }

  /// Switch project filter: fetches from offset 0 for the new project.
  /// Old sessions remain visible until the server response arrives.
  void switchProjectFilter(String? projectPath, {int pageSize = 20}) {
    _currentProjectFilter = projectPath;
    _appendMode = false;
    send(
      ClientMessage.listRecentSessions(
        limit: pageSize,
        offset: 0,
        projectPath: projectPath,
      ),
    );
  }

  @override
  void requestSessionHistory(String sessionId) {
    send(ClientMessage.getHistory(sessionId));
  }

  void resumeSession(
    String sessionId,
    String projectPath, {
    String? permissionMode,
    String? effort,
    int? maxTurns,
    double? maxBudgetUsd,
    String? fallbackModel,
    bool? forkSession,
    bool? persistSession,
    String? provider,
    String? approvalPolicy,
    String? sandboxMode,
    String? model,
    String? modelReasoningEffort,
    bool? networkAccessEnabled,
    String? webSearchMode,
  }) {
    send(
      ClientMessage.resumeSession(
        sessionId,
        projectPath,
        permissionMode: permissionMode,
        effort: effort,
        maxTurns: maxTurns,
        maxBudgetUsd: maxBudgetUsd,
        fallbackModel: fallbackModel,
        forkSession: forkSession,
        persistSession: persistSession,
        provider: provider,
        approvalPolicy: approvalPolicy,
        sandboxMode: sandboxMode,
        model: model,
        modelReasoningEffort: modelReasoningEffort,
        networkAccessEnabled: networkAccessEnabled,
        webSearchMode: webSearchMode,
      ),
    );
  }

  @override
  void stopSession(String sessionId) {
    send(ClientMessage.stopSession(sessionId));
  }

  void requestProjectHistory() {
    send(ClientMessage.listProjectHistory());
  }

  void requestDebugBundle(
    String sessionId, {
    int? traceLimit,
    bool includeDiff = true,
  }) {
    send(
      ClientMessage.getDebugBundle(
        sessionId,
        traceLimit: traceLimit,
        includeDiff: includeDiff,
      ),
    );
  }

  void requestUsage() {
    send(ClientMessage.getUsage());
  }

  void removeProjectHistory(String path) {
    send(ClientMessage.removeProjectHistory(path));
  }

  void requestWorktreeList(String projectPath) {
    send(ClientMessage.listWorktrees(projectPath));
  }

  void removeWorktree(String projectPath, String worktreePath) {
    send(ClientMessage.removeWorktree(projectPath, worktreePath));
  }

  void requestGallery({String? project, String? sessionId}) {
    send(ClientMessage.listGallery(project: project, sessionId: sessionId));
  }

  void requestWindowList() {
    send(ClientMessage.listWindows());
  }

  void takeScreenshot({
    required String mode,
    int? windowId,
    required String projectPath,
    String? sessionId,
  }) {
    send(
      ClientMessage.takeScreenshot(
        mode: mode,
        windowId: windowId,
        projectPath: projectPath,
        sessionId: sessionId,
      ),
    );
  }

  @override
  void requestFileList(String projectPath) {
    send(ClientMessage.listFiles(projectPath));
  }

  @override
  void interrupt(String sessionId) {
    send(ClientMessage.interrupt(sessionId: sessionId));
  }

  void registerPushToken({required String token, required String platform}) {
    send(ClientMessage.pushRegister(token: token, platform: platform));
  }

  void unregisterPushToken(String token) {
    send(ClientMessage.pushUnregister(token));
  }

  /// Update the cached [_sessions] list when a [StatusMessage] arrives,
  /// so the session list screen reflects the change in real-time.
  void _patchSessionStatus(String sessionId, ProcessStatus status) {
    final statusStr = switch (status) {
      ProcessStatus.starting => 'starting',
      ProcessStatus.idle => 'idle',
      ProcessStatus.running => 'running',
      ProcessStatus.waitingApproval => 'waiting_approval',
    };
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    if (_sessions[idx].status == statusStr) return;
    _sessions = List.of(_sessions)
      ..[idx] = _sessions[idx].copyWith(status: statusStr);
    _sessionListController.add(_sessions);
  }

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedMessageController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  /// Try to auto-connect using saved preferences.
  Future<bool> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefKeyUrl);
    if (url == null || url.isEmpty) return false;

    var connectUrl = url;
    final apiKey = prefs.getString(_prefKeyApiKey);
    if (apiKey != null && apiKey.isNotEmpty) {
      final sep = connectUrl.contains('?') ? '&' : '?';
      connectUrl = '$connectUrl${sep}token=$apiKey';
    }
    connect(connectUrl);
    return true;
  }

  /// Save connection settings to preferences.
  Future<void> savePreferences(String url, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, url);
    await prefs.setString(_prefKeyApiKey, apiKey);
  }

  /// Check if the Bridge server is reachable via /health endpoint.
  /// Returns the health JSON on success, null on failure.
  static Future<Map<String, dynamic>?> checkHealth(String wsUrl) async {
    try {
      final uri = Uri.tryParse(wsUrl);
      if (uri == null) return null;
      final scheme = uri.scheme == 'wss' ? 'https' : 'http';
      final port = uri.hasPort ? ':${uri.port}' : '';
      final healthUrl = '$scheme://${uri.host}$port/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Upload an image to the gallery from base64 data.
  /// Returns the GalleryImage on success, null on failure.
  Future<GalleryImage?> uploadImageBase64({
    required String base64Data,
    required String mimeType,
    required String projectPath,
    String? sessionId,
  }) async {
    final baseUrl = httpBaseUrl;
    if (baseUrl == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/gallery/upload'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'base64': base64Data,
              'mimeType': mimeType,
              'projectPath': projectPath,
              'sessionId': ?sessionId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final imageJson = json['image'] as Map<String, dynamic>;
        return GalleryImage.fromJson(imageJson);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete a gallery image by ID.
  /// Returns true on success, false on failure.
  /// On success, immediately removes the image from the local cache
  /// and pushes the updated list to [galleryStream].
  Future<bool> deleteGalleryImage(String id) async {
    final baseUrl = httpBaseUrl;
    if (baseUrl == null) return false;

    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/api/gallery/$id'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _galleryImages = _galleryImages.where((img) => img.id != id).toList();
        _galleryController.add(_galleryImages);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Verify WebSocket health and reconnect if the connection is stale.
  ///
  /// Call this when the app returns to foreground — iOS may silently kill
  /// background WebSocket connections without triggering [onDone]/[onError].
  void ensureConnected() {
    if (_lastUrl == null) return;
    if (_connectionState == BridgeConnectionState.connected) {
      // The channel may appear "connected" but the underlying socket is dead.
      // A non-null closeCode means the socket has already been closed.
      if (_channel?.closeCode != null) {
        _scheduleReconnect();
      }
    } else if (_connectionState == BridgeConnectionState.disconnected) {
      connect(_lastUrl!);
    }
    // If reconnecting, do nothing — already in progress.
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _setBridgeConnectionState(BridgeConnectionState.disconnected);
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
    _taggedMessageController.close();
    _connectionController.close();
    _sessionListController.close();
    _recentSessionsController.close();
    _galleryController.close();
    _fileListController.close();
    _projectHistoryController.close();
    _diffResultController.close();
    _worktreeListController.close();
    _windowListController.close();
    _screenshotResultController.close();
    _debugBundleController.close();
    _usageController.close();
  }
}
