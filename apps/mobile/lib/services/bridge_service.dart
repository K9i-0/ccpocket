import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/logger.dart';
import '../models/messages.dart';
import '../models/offline_pending_action.dart';
import '../utils/codex_plan_update.dart';
import 'bridge_service_base.dart';
import 'session_runtime_store.dart';

class BridgeService implements BridgeServiceBase {
  void Function(ClientMessage message)? onOutgoingMessage;
  FutureOr<void> Function()? onDisconnect;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedMessageController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();
  final _sessionStoppedController = StreamController<String>.broadcast();
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _galleryController = StreamController<List<GalleryImage>>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();
  final _diffResultController = StreamController<DiffResultMessage>.broadcast();
  final _diffImageResultController =
      StreamController<DiffImageResultMessage>.broadcast();
  final _worktreeListController =
      StreamController<WorktreeListMessage>.broadcast();
  final _windowListController = StreamController<List<WindowInfo>>.broadcast();
  final _screenshotResultController =
      StreamController<ScreenshotResultMessage>.broadcast();
  final _offlinePendingActionsController =
      StreamController<List<OfflinePendingAction>>.broadcast();
  final _debugBundleController =
      StreamController<DebugBundleMessage>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();
  final _recordingListController =
      StreamController<RecordingListMessage>.broadcast();
  final _recordingContentController =
      StreamController<RecordingContentMessage>.broadcast();
  final _backupResultController =
      StreamController<PromptHistoryBackupResultMessage>.broadcast();
  final _restoreResultController =
      StreamController<PromptHistoryRestoreResultMessage>.broadcast();
  final _backupInfoController =
      StreamController<PromptHistoryBackupInfoMessage>.broadcast();
  final _promptHistorySyncController =
      StreamController<PromptHistorySyncResultMessage>.broadcast();
  final _promptHistoryMutationController =
      StreamController<PromptHistoryMutationResultMessage>.broadcast();
  final _promptHistoryStatusController =
      StreamController<PromptHistoryStatusMessage>.broadcast();
  final _fileContentController =
      StreamController<FileContentMessage>.broadcast();
  // ---- Git Operations (Phase 1-3) ----
  final _gitStageResultController =
      StreamController<GitStageResultMessage>.broadcast();
  final _gitUnstageResultController =
      StreamController<GitUnstageResultMessage>.broadcast();
  final _gitUnstageHunksResultController =
      StreamController<GitUnstageHunksResultMessage>.broadcast();
  final _gitCommitResultController =
      StreamController<GitCommitResultMessage>.broadcast();
  final _gitPushResultController =
      StreamController<GitPushResultMessage>.broadcast();
  final _gitBranchesResultController =
      StreamController<GitBranchesResultMessage>.broadcast();
  final _gitCreateBranchResultController =
      StreamController<GitCreateBranchResultMessage>.broadcast();
  final _gitCheckoutBranchResultController =
      StreamController<GitCheckoutBranchResultMessage>.broadcast();
  final _gitRevertFileResultController =
      StreamController<GitRevertFileResultMessage>.broadcast();
  final _gitRevertHunksResultController =
      StreamController<GitRevertHunksResultMessage>.broadcast();
  final _gitFetchResultController =
      StreamController<GitFetchResultMessage>.broadcast();
  final _gitPullResultController =
      StreamController<GitPullResultMessage>.broadcast();
  final _gitStatusResultController =
      StreamController<GitStatusResultMessage>.broadcast();
  final _gitRemoteStatusResultController =
      StreamController<GitRemoteStatusResultMessage>.broadcast();
  BridgeConnectionState _connectionState = BridgeConnectionState.disconnected;
  final List<ClientMessage> _messageQueue = [];
  List<SessionInfo> _sessions = [];
  List<RecentSession> _recentSessions = [];
  List<GalleryImage> _galleryImages = [];
  List<String> _projectHistory = [];
  List<String> _allowedDirs = [];
  List<String> _claudeModels = [];
  List<String> _codexModels = [];
  List<String> _codexProfiles = [];
  String? _defaultCodexProfile;
  String? _bridgeVersion;
  String? _promptHistoryBridgeId;
  UsageResultMessage? _lastUsageResult;
  final SessionRuntimeStore _runtimeStore = SessionRuntimeStore();
  final Map<String, int> _pendingHistoryDeltaSinceSeq = {};
  final Map<String, ClientMessage> _inFlightPendingMessages = {};
  final Map<String, ClientMessage> _inFlightInputMessages = {};
  final Map<String, Timer> _inFlightPendingVisibilityTimers = {};
  final Set<String> _visibleInFlightPendingKeys = {};
  final Map<String, _DeliveryPendingInputState> _deliveryPendingInputs = {};
  final Map<String, Timer> _deliveryPendingVisibilityTimers = {};
  List<OfflinePendingAction> _offlinePendingActions = const [];

  // Diff image cache: survives screen navigation, cleared on session stop.
  // Key: "$projectPath\n$filePath"
  final _diffImageCache = <String, DiffImageCacheEntry>{};

  // Pagination & filter state
  bool _recentSessionsHasMore = false;
  bool _appendMode = false;
  String? _currentProjectFilter;
  String? _currentProvider;
  bool? _currentNamedOnly;
  String? _currentSearchQuery;

  // Auto-reconnect
  String? _lastUrl;
  int _connectionEpoch = 0;
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
  @override
  Stream<String> get stoppedSessions => _sessionStoppedController.stream;
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;
  Stream<List<GalleryImage>> get galleryStream => _galleryController.stream;
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;
  @override
  Stream<List<String>> get fileList => _fileListController.stream;
  Stream<FileContentMessage> get fileContent => _fileContentController.stream;
  Stream<DiffResultMessage> get diffResults => _diffResultController.stream;
  Stream<DiffImageResultMessage> get diffImageResults =>
      _diffImageResultController.stream;
  Stream<WorktreeListMessage> get worktreeList =>
      _worktreeListController.stream;
  Stream<List<WindowInfo>> get windowList => _windowListController.stream;
  Stream<ScreenshotResultMessage> get screenshotResults =>
      _screenshotResultController.stream;
  Stream<List<OfflinePendingAction>> get offlinePendingActionsStream =>
      _offlinePendingActionsController.stream;
  Stream<DebugBundleMessage> get debugBundles => _debugBundleController.stream;
  Stream<UsageResultMessage> get usageResults => _usageController.stream;
  Stream<RecordingListMessage> get recordingList =>
      _recordingListController.stream;
  Stream<RecordingContentMessage> get recordingContent =>
      _recordingContentController.stream;
  Stream<PromptHistoryBackupResultMessage> get backupResults =>
      _backupResultController.stream;
  Stream<PromptHistoryRestoreResultMessage> get restoreResults =>
      _restoreResultController.stream;
  Stream<PromptHistoryBackupInfoMessage> get backupInfo =>
      _backupInfoController.stream;
  Stream<PromptHistorySyncResultMessage> get promptHistorySyncResults =>
      _promptHistorySyncController.stream;
  Stream<PromptHistoryMutationResultMessage> get promptHistoryMutationResults =>
      _promptHistoryMutationController.stream;
  Stream<PromptHistoryStatusMessage> get promptHistoryStatus =>
      _promptHistoryStatusController.stream;
  // Git Operations
  Stream<GitStageResultMessage> get gitStageResults =>
      _gitStageResultController.stream;
  Stream<GitUnstageResultMessage> get gitUnstageResults =>
      _gitUnstageResultController.stream;
  Stream<GitUnstageHunksResultMessage> get gitUnstageHunksResults =>
      _gitUnstageHunksResultController.stream;
  Stream<GitCommitResultMessage> get gitCommitResults =>
      _gitCommitResultController.stream;
  Stream<GitPushResultMessage> get gitPushResults =>
      _gitPushResultController.stream;
  Stream<GitBranchesResultMessage> get gitBranchesResults =>
      _gitBranchesResultController.stream;
  Stream<GitCreateBranchResultMessage> get gitCreateBranchResults =>
      _gitCreateBranchResultController.stream;
  Stream<GitCheckoutBranchResultMessage> get gitCheckoutBranchResults =>
      _gitCheckoutBranchResultController.stream;
  Stream<GitRevertFileResultMessage> get gitRevertFileResults =>
      _gitRevertFileResultController.stream;
  Stream<GitRevertHunksResultMessage> get gitRevertHunksResults =>
      _gitRevertHunksResultController.stream;
  Stream<GitFetchResultMessage> get gitFetchResults =>
      _gitFetchResultController.stream;
  Stream<GitPullResultMessage> get gitPullResults =>
      _gitPullResultController.stream;
  Stream<GitStatusResultMessage> get gitStatusResults =>
      _gitStatusResultController.stream;
  Stream<GitRemoteStatusResultMessage> get gitRemoteStatusResults =>
      _gitRemoteStatusResultController.stream;
  BridgeConnectionState get currentBridgeConnectionState => _connectionState;
  @override
  bool get isConnected => _connectionState == BridgeConnectionState.connected;
  List<SessionInfo> get sessions => _sessions;
  List<RecentSession> get recentSessions => _recentSessions;
  bool get recentSessionsHasMore => _recentSessionsHasMore;
  String? get currentProjectFilter => _currentProjectFilter;
  List<GalleryImage> get galleryImages => _galleryImages;
  List<String> get projectHistory => _projectHistory;
  List<String> get allowedDirs => _allowedDirs;
  List<String> get claudeModels => _claudeModels;
  List<String> get codexModels => _codexModels;
  List<String> get codexProfiles => _codexProfiles;
  String? get defaultCodexProfile => _defaultCodexProfile;
  String? get bridgeVersion => _bridgeVersion;
  String? get promptHistoryBridgeId => _promptHistoryBridgeId;
  UsageResultMessage? get lastUsageResult => _lastUsageResult;
  List<OfflinePendingAction> get offlinePendingActions =>
      _offlinePendingActions;

  BridgeService() {
    unawaited(_ensureOfflineQueueRestored());
  }

  /// The last WebSocket URL used for connection (or reconnection).
  String? get lastUrl => _lastUrl;

  void _rememberPromptHistoryBridgeId(String? value) {
    if (value != null && value.isNotEmpty) {
      _promptHistoryBridgeId = value;
    }
  }

  QueuedInputItem? deliveryPendingInputForSession(
    String sessionId, {
    bool includeHidden = false,
  }) {
    final pending = _deliveryPendingInputs[sessionId];
    if (pending == null || (!includeHidden && !pending.visible)) return null;
    return pending.item;
  }

  void setDeliveryPendingInput(
    String sessionId,
    QueuedInputItem item, {
    Duration visibleAfter = Duration.zero,
  }) {
    _deliveryPendingVisibilityTimers.remove(sessionId)?.cancel();
    _deliveryPendingInputs[sessionId] = _DeliveryPendingInputState(item);
    if (visibleAfter == Duration.zero || visibleAfter.isNegative) {
      showDeliveryPendingInput(sessionId, itemId: item.itemId);
      return;
    }
    _deliveryPendingVisibilityTimers[sessionId] = Timer(visibleAfter, () {
      _deliveryPendingVisibilityTimers.remove(sessionId);
      showDeliveryPendingInput(sessionId, itemId: item.itemId);
    });
  }

  void showDeliveryPendingInput(String sessionId, {required String itemId}) {
    final pending = _deliveryPendingInputs[sessionId];
    if (pending == null || pending.item.itemId != itemId) return;
    if (pending.visible) return;
    pending.visible = true;
    _patchSessionQueuedInput(sessionId, pending.item);
  }

  void clearDeliveryPendingInput(String sessionId, {String? itemId}) {
    final pending = _deliveryPendingInputs[sessionId];
    if (pending == null) return;
    if (itemId != null && pending.item.itemId != itemId) return;
    _deliveryPendingVisibilityTimers.remove(sessionId)?.cancel();
    _deliveryPendingInputs.remove(sessionId);
    final idx = _sessions.indexWhere((session) => session.id == sessionId);
    if (idx < 0) return;
    if (_sessions[idx].queuedInput?.itemId == pending.item.itemId) {
      _patchSessionQueuedInput(sessionId, null);
    }
  }

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
  static const _prefKeyOfflinePendingMessages =
      'bridge_offline_pending_messages_v1';
  static const _inFlightPendingVisibilityDelay = Duration(milliseconds: 600);

  Future<void>? _offlineQueueRestore;
  int _offlineQueueGeneration = 0;

  void _setBridgeConnectionState(BridgeConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  void connect(String url) {
    final previousUrl = _lastUrl;
    final isBridgeSwitch =
        previousUrl != null && !_sameBridgeTarget(previousUrl, url);
    _connectionEpoch++;
    final epoch = _connectionEpoch;
    _intentionalDisconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _lastUsageResult = null;
    _promptHistoryBridgeId = null;
    if (isBridgeSwitch) {
      _clearBridgeScopedState(clearOfflineQueue: true);
    }
    _lastUrl = url;

    _setBridgeConnectionState(BridgeConnectionState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _setBridgeConnectionState(BridgeConnectionState.connected);
      _reconnectAttempt = 0;
      send(ClientMessage.clientCapabilities());
      _flushMessageQueue();

      _channelSub = _channel!.stream.listen(
        (data) {
          if (epoch != _connectionEpoch) return;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            final sessionId = json['sessionId'] as String?;
            final msg = ServerMessage.fromJson(json);
            if (sessionId != null && msg is HistoryDeltaMessage) {
              _handleHistoryDelta(sessionId, msg);
              return;
            }
            if (sessionId != null && msg is HistorySnapshotMessage) {
              _handleHistorySnapshot(sessionId, msg);
              return;
            }
            if (sessionId != null) {
              _cacheAcceptedInFlightInput(msg, sessionId: sessionId);
              _runtimeStore.applyServerMessage(
                sessionId,
                msg,
                historySeq:
                    _readHistorySeq(json['historySeq']) ??
                    (msg is InputAckMessage ? msg.acceptedSeq : null),
              );
            }
            _clearDeliveredDeliveryPendingInput(msg, sessionId: sessionId);
            _clearDeliveredInFlightInput(msg, sessionId: sessionId);
            switch (msg) {
              case SessionListMessage(
                :final sessions,
                :final allowedDirs,
                :final claudeModels,
                :final codexModels,
                :final codexProfiles,
                :final defaultCodexProfile,
                :final bridgeVersion,
              ):
                _sessions = _applyLocalDeliveryPendingInputs(sessions);
                _clearPendingStartActionsForSessions(_sessions);
                _sessionListController.add(_sessions);
                _allowedDirs = allowedDirs;
                _claudeModels = claudeModels;
                _codexModels = codexModels;
                _codexProfiles = codexProfiles;
                _defaultCodexProfile = defaultCodexProfile;
                _bridgeVersion = bridgeVersion;
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
              case FileContentMessage():
                _fileContentController.add(msg);
              case FileListMessage(:final files):
                _fileListController.add(files);
              case ProjectHistoryMessage(:final projects):
                _projectHistory = projects;
                _projectHistoryController.add(projects);
              case DiffResultMessage():
                _diffResultController.add(msg);
              case DiffImageResultMessage():
                _diffImageResultController.add(msg);
              case WorktreeListMessage():
                _worktreeListController.add(msg);
              case WindowListMessage(:final windows):
                _windowListController.add(windows);
              case ScreenshotResultMessage():
                _screenshotResultController.add(msg);
              case DebugBundleMessage():
                _debugBundleController.add(msg);
              case UsageResultMessage():
                _lastUsageResult = msg;
                _usageController.add(msg);
              case RecordingListMessage():
                _recordingListController.add(msg);
              case RecordingContentMessage():
                _recordingContentController.add(msg);
              case PromptHistoryBackupResultMessage():
                _backupResultController.add(msg);
              case PromptHistoryRestoreResultMessage():
                _restoreResultController.add(msg);
              case PromptHistoryBackupInfoMessage():
                _backupInfoController.add(msg);
              case PromptHistorySyncResultMessage():
                _rememberPromptHistoryBridgeId(msg.bridgeInstanceId);
                _promptHistorySyncController.add(msg);
              case PromptHistoryMutationResultMessage():
                _rememberPromptHistoryBridgeId(msg.bridgeInstanceId);
                _promptHistoryMutationController.add(msg);
              case PromptHistoryStatusMessage():
                _rememberPromptHistoryBridgeId(msg.bridgeInstanceId);
                _promptHistoryStatusController.add(msg);
              // Git Operations
              case GitStageResultMessage():
                _gitStageResultController.add(msg);
              case GitUnstageResultMessage():
                _gitUnstageResultController.add(msg);
              case GitUnstageHunksResultMessage():
                _gitUnstageHunksResultController.add(msg);
              case GitCommitResultMessage():
                _gitCommitResultController.add(msg);
              case GitPushResultMessage():
                _gitPushResultController.add(msg);
              case GitBranchesResultMessage():
                _gitBranchesResultController.add(msg);
              case GitCreateBranchResultMessage():
                _gitCreateBranchResultController.add(msg);
              case GitCheckoutBranchResultMessage():
                _gitCheckoutBranchResultController.add(msg);
              case GitRevertFileResultMessage():
                _gitRevertFileResultController.add(msg);
              case GitRevertHunksResultMessage():
                _gitRevertHunksResultController.add(msg);
              case GitFetchResultMessage():
                _gitFetchResultController.add(msg);
              case GitPullResultMessage():
                _gitPullResultController.add(msg);
              case GitStatusResultMessage():
                _gitStatusResultController.add(msg);
              case GitRemoteStatusResultMessage():
                _gitRemoteStatusResultController.add(msg);
              case ArchiveResultMessage(:final success):
                if (success) {
                  // Refresh the recent sessions list to reflect the archived session
                  requestRecentSessions();
                }
              case WorktreeRemovedMessage():
                _messageController.add(msg);
              case ConversationQueueMessage(:final items):
                if (sessionId != null) {
                  _patchSessionQueuedInput(
                    sessionId,
                    items.isNotEmpty ? items.first : null,
                  );
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case AssistantServerMessage(:final message):
                if (sessionId != null) {
                  _patchSessionLastMessage(sessionId, message);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case PermissionRequestMessage():
                if (sessionId != null) {
                  _patchSessionPermission(sessionId, msg);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case PermissionResolvedMessage():
                if (sessionId != null) {
                  clearSessionPermission(sessionId);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case SystemMessage(:final permissionMode):
                if (msg.subtype == 'session_created') {
                  _clearPendingSessionActionFor(msg);
                }
                if (sessionId != null && permissionMode != null) {
                  _patchSessionPermissionMode(
                    sessionId,
                    permissionMode,
                    provider: msg.provider,
                    executionMode: msg.executionMode,
                    planMode: msg.planMode,
                    approvalPolicy: msg.approvalPolicy,
                    approvalsReviewer: msg.approvalsReviewer,
                    codexPermissionsMode: msg.codexPermissionsMode,
                  );
                }
                if (sessionId != null) {
                  _patchSessionSystemSettings(sessionId, msg);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case StatusMessage(:final status):
                // Patch cached session list so the session list screen
                // reflects status changes in real-time.
                if (sessionId != null) {
                  _patchSessionStatus(sessionId, status);
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case ResultMessage(:final subtype) when subtype == 'stopped':
                if (sessionId != null) {
                  clearExplorerHistory(sessionId);
                  _sessions = _sessions
                      .where((session) => session.id != sessionId)
                      .toList();
                  _sessionListController.add(_sessions);
                  _sessionStoppedController.add(sessionId);
                  clearDiffImageCache();
                }
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              case ErrorMessage(:final message):
                if (msg.errorCode == 'unsupported_message' &&
                    message == 'get_history_delta') {
                  _fallbackPendingHistoryDeltaRequests();
                }
                // Bridge explicitly rejected auth — stop reconnecting.
                if (msg.errorCode == 'auth_failed') {
                  _intentionalDisconnect = true;
                }
                logger.error('Bridge error: $message');
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
              default:
                _taggedMessageController.add((msg, sessionId));
                _messageController.add(msg);
            }
          } catch (e, st) {
            logger.error('WS parse error', e, st);
            final errorMsg = ErrorMessage(message: 'Parse error: $e');
            _taggedMessageController.add((errorMsg, null));
            _messageController.add(errorMsg);
          }
        },
        onError: (error, stackTrace) {
          if (epoch != _connectionEpoch) return;
          logger.error('WS stream error', error, stackTrace);
          _setBridgeConnectionState(BridgeConnectionState.disconnected);
          _requeueInFlightInputMessages();
          _requeueInFlightPendingMessages();
          _messageController.add(
            ErrorMessage(message: 'WebSocket error: $error'),
          );
          _scheduleReconnect();
        },
        onDone: () {
          if (epoch != _connectionEpoch) return;
          final closeCode = _channel?.closeCode;
          _channel = null;
          if (!_intentionalDisconnect) {
            _setBridgeConnectionState(BridgeConnectionState.disconnected);
            _requeueInFlightInputMessages();
            _requeueInFlightPendingMessages();
            // Don't retry on auth failure (4001) — the token is invalid and
            // retrying with the same credentials will never succeed.
            if (closeCode == 4001) {
              _messageController.add(
                ErrorMessage(
                  message:
                      'Authentication failed. Please reconnect with a valid API key.',
                ),
              );
            } else {
              _scheduleReconnect();
            }
          } else {
            _setBridgeConnectionState(BridgeConnectionState.disconnected);
          }
        },
      );
    } catch (e, st) {
      logger.error('WS connect failed', e, st);
      _setBridgeConnectionState(BridgeConnectionState.disconnected);
      _messageController.add(ErrorMessage(message: 'Connection failed: $e'));
      _scheduleReconnect();
    }
  }

  bool _sameBridgeTarget(String left, String right) {
    final leftUri = Uri.tryParse(left);
    final rightUri = Uri.tryParse(right);
    if (leftUri == null || rightUri == null) return left == right;
    return _bridgeTargetKey(leftUri) == _bridgeTargetKey(rightUri);
  }

  String _bridgeTargetKey(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);
    final path = uri.path.isEmpty ? '/' : uri.path;
    return '$scheme://$host:$port$path';
  }

  void _clearBridgeScopedState({required bool clearOfflineQueue}) {
    _sessions = const [];
    _recentSessions = const [];
    _recentSessionsHasMore = false;
    _appendMode = false;
    _currentProjectFilter = null;
    _galleryImages = const [];
    _projectHistory = const [];
    _allowedDirs = const [];
    _claudeModels = const [];
    _codexModels = const [];
    _codexProfiles = const [];
    _defaultCodexProfile = null;
    _bridgeVersion = null;
    _promptHistoryBridgeId = null;
    _lastUsageResult = null;
    _pendingHistoryDeltaSinceSeq.clear();
    _deliveryPendingInputs.clear();
    for (final timer in _deliveryPendingVisibilityTimers.values) {
      timer.cancel();
    }
    _deliveryPendingVisibilityTimers.clear();
    _runtimeStore.clearAll();
    clearDiffImageCache();

    _sessionListController.add(_sessions);
    _recentSessionsController.add(_recentSessions);
    _galleryController.add(_galleryImages);
    _projectHistoryController.add(_projectHistory);
    _fileListController.add(const []);

    if (clearOfflineQueue) {
      _clearOfflinePendingState();
    }
  }

  void _clearOfflinePendingState() {
    _offlineQueueGeneration++;
    _messageQueue.clear();
    _inFlightPendingMessages.clear();
    _inFlightInputMessages.clear();
    for (final timer in _inFlightPendingVisibilityTimers.values) {
      timer.cancel();
    }
    _inFlightPendingVisibilityTimers.clear();
    _visibleInFlightPendingKeys.clear();
    _offlinePendingActions = const [];
    _offlinePendingActionsController.add(_offlinePendingActions);
    _offlineQueueRestore = Future.value();
    unawaited(_clearPersistedOfflinePendingMessages());
  }

  Future<void> _clearPersistedOfflinePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyOfflinePendingMessages);
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to clear offline pending messages',
        error,
        stackTrace,
      );
    }
  }

  int? _readHistorySeq(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  void _handleHistoryDelta(String sessionId, HistoryDeltaMessage msg) {
    final previousSnapshot = _runtimeStore.snapshot(sessionId);
    final hadCachedTimeline = previousSnapshot.messages.isNotEmpty;
    final previousLatestSeq = previousSnapshot.historySeq;
    final previousCachedSeq = previousSnapshot.cachedHistorySeq;
    final shouldReplace =
        hadCachedTimeline &&
        ((previousCachedSeq == 0 && msg.fromSeq <= 1) ||
            (msg.fromSeq <= previousCachedSeq + 1 &&
                msg.fromSeq <= previousLatestSeq));
    _pendingHistoryDeltaSinceSeq.remove(sessionId);
    _runtimeStore.applyServerMessage(sessionId, msg);

    if (shouldReplace) {
      final history = HistoryMessage(
        messages: _runtimeStore.messages(sessionId),
      );
      _taggedMessageController.add((history, sessionId));
      _messageController.add(history);
    } else {
      final messages = msg.entries.map((entry) => entry.message).toList();
      for (final message in messages) {
        _taggedMessageController.add((message, sessionId));
        _messageController.add(message);
      }
    }

    final status = msg.status;
    if (status != null) {
      _patchSessionStatus(sessionId, status);
      final statusMessage = StatusMessage(status: status);
      _runtimeStore.applyServerMessage(sessionId, statusMessage);
      _taggedMessageController.add((statusMessage, sessionId));
      _messageController.add(statusMessage);
    }
  }

  void _handleHistorySnapshot(String sessionId, HistorySnapshotMessage msg) {
    _pendingHistoryDeltaSinceSeq.remove(sessionId);
    _runtimeStore.applyServerMessage(sessionId, msg);

    final history = HistoryMessage(
      messages: msg.entries.map((entry) => entry.message).toList(),
    );
    _taggedMessageController.add((history, sessionId));
    _messageController.add(history);

    final status = msg.status;
    if (status != null) {
      _patchSessionStatus(sessionId, status);
      final statusMessage = StatusMessage(status: status);
      _runtimeStore.applyServerMessage(sessionId, statusMessage);
      _taggedMessageController.add((statusMessage, sessionId));
      _messageController.add(statusMessage);
    }
  }

  void _fallbackPendingHistoryDeltaRequests() {
    if (_pendingHistoryDeltaSinceSeq.isEmpty) return;
    final sessionIds = List<String>.from(_pendingHistoryDeltaSinceSeq.keys);
    _pendingHistoryDeltaSinceSeq.clear();
    for (final sessionId in sessionIds) {
      send(ClientMessage.getHistory(sessionId));
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
    onOutgoingMessage?.call(message);
    if (_channel != null && isConnected) {
      if (!_trackInFlightPendingMessage(message)) return;
      _trackInFlightInputMessage(message);
      try {
        _channel!.sink.add(message.toJson());
      } catch (error, stackTrace) {
        logger.warning('WS send failed; queued message', error, stackTrace);
        _queueOfflineMessage(message);
        _setBridgeConnectionState(BridgeConnectionState.disconnected);
        _scheduleReconnect();
      }
    } else {
      _queueOfflineMessage(message);
    }
  }

  void _queueOfflineMessage(ClientMessage message) {
    final dedupeKey = _offlineMessageDedupeKey(message);
    if (dedupeKey != null) {
      _clearInFlightPendingMessage(dedupeKey);
      _clearInFlightInputMessage(dedupeKey);
    }
    final didAdd = _addQueuedMessageIfAbsent(message);
    if (didAdd || _isPersistableOfflineMessage(message)) {
      _publishOfflinePendingActions();
    }
    if (_isPersistableOfflineMessage(message)) {
      unawaited(_persistOfflinePendingMessages());
    }
  }

  bool _addQueuedMessageIfAbsent(ClientMessage message) {
    final dedupeKey = _offlineMessageDedupeKey(message);
    final shouldSkip =
        dedupeKey != null &&
        _messageQueue.any((queued) {
          return _offlineMessageDedupeKey(queued) == dedupeKey;
        });
    if (shouldSkip) return false;
    _messageQueue.add(message);
    return true;
  }

  bool _trackInFlightPendingMessage(ClientMessage message) {
    final dedupeKey = _offlineMessageDedupeKey(message);
    if (dedupeKey == null || _offlinePendingActionFor(message) == null) {
      return true;
    }
    final isQueued = _messageQueue.any((queued) {
      return _offlineMessageDedupeKey(queued) == dedupeKey;
    });
    if (isQueued || _inFlightPendingMessages.containsKey(dedupeKey)) {
      _publishOfflinePendingActions();
      return false;
    }
    _inFlightPendingMessages[dedupeKey] = message;
    _scheduleInFlightPendingVisibility(dedupeKey);
    return true;
  }

  void _scheduleInFlightPendingVisibility(String dedupeKey) {
    _inFlightPendingVisibilityTimers[dedupeKey]?.cancel();
    _inFlightPendingVisibilityTimers[dedupeKey] = Timer(
      _inFlightPendingVisibilityDelay,
      () {
        _inFlightPendingVisibilityTimers.remove(dedupeKey);
        if (!_inFlightPendingMessages.containsKey(dedupeKey)) return;
        _visibleInFlightPendingKeys.add(dedupeKey);
        _publishOfflinePendingActions();
      },
    );
  }

  void _clearInFlightPendingMessage(String dedupeKey) {
    _inFlightPendingMessages.remove(dedupeKey);
    _visibleInFlightPendingKeys.remove(dedupeKey);
    _inFlightPendingVisibilityTimers.remove(dedupeKey)?.cancel();
  }

  void _trackInFlightInputMessage(ClientMessage message) {
    if (message.type != 'input') return;
    final dedupeKey = _offlineMessageDedupeKey(message);
    if (dedupeKey == null) return;
    _inFlightInputMessages[dedupeKey] = message;
  }

  void _cacheAcceptedInFlightInput(
    ServerMessage message, {
    required String sessionId,
  }) {
    if (message is! InputAckMessage) return;
    if (message.queued == true) return;
    final clientMessageId = message.clientMessageId;
    if (clientMessageId == null || clientMessageId.isEmpty) return;
    final key = 'input:$sessionId:$clientMessageId';
    final input = _inFlightInputMessages[key];
    if (input == null) return;

    final json = jsonDecode(input.toJson()) as Map<String, dynamic>;
    final text = json['text'] as String?;
    if (text == null) return;
    final images = json['images'] as List?;
    if (images != null && images.isNotEmpty) {
      // The ack does not include ImageStore URLs. Let the next history delta
      // fetch the canonical user_input so image-only messages remain visible
      // after leaving and re-entering the running session.
      return;
    }

    _runtimeStore.applyServerMessage(
      sessionId,
      UserInputMessage(
        text: text,
        clientMessageId: clientMessageId,
        imageCount: images?.length ?? 0,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      ),
      historySeq: message.acceptedSeq,
    );
  }

  void _clearInFlightInputMessage(String dedupeKey) {
    _inFlightInputMessages.remove(dedupeKey);
  }

  void _clearDeliveredDeliveryPendingInput(
    ServerMessage message, {
    required String? sessionId,
  }) {
    if (sessionId == null) return;
    switch (message) {
      case InputAckMessage(:final clientMessageId, :final queued):
        if (clientMessageId == null || queued) return;
        clearDeliveryPendingInput(
          sessionId,
          itemId: 'pending:$clientMessageId',
        );
      case InputRejectedMessage(:final clientMessageId):
        if (clientMessageId == null) return;
        clearDeliveryPendingInput(
          sessionId,
          itemId: 'pending:$clientMessageId',
        );
      case AssistantServerMessage():
        clearDeliveryPendingInput(sessionId);
      default:
        return;
    }
  }

  void _clearDeliveredInFlightInput(
    ServerMessage message, {
    required String? sessionId,
  }) {
    switch (message) {
      case InputAckMessage(:final clientMessageId) ||
          InputRejectedMessage(:final clientMessageId):
        if (clientMessageId == null) return;
        _clearInFlightInputMessage('input:${sessionId ?? ''}:$clientMessageId');
      case AssistantServerMessage():
        if (sessionId == null) return;
        final prefix = 'input:$sessionId:';
        for (final key in List<String>.from(_inFlightInputMessages.keys)) {
          if (!key.startsWith(prefix)) continue;
          _clearInFlightInputMessage(key);
          return;
        }
      default:
        return;
    }
  }

  void _requeueInFlightInputMessages() {
    if (_inFlightInputMessages.isEmpty) return;
    final messages = List<ClientMessage>.from(_inFlightInputMessages.values);
    _inFlightInputMessages.clear();
    var didAdd = false;
    for (final message in messages) {
      didAdd = _addQueuedMessageIfAbsent(message) || didAdd;
    }
    if (didAdd) {
      unawaited(_persistOfflinePendingMessages());
    }
  }

  void _requeueInFlightPendingMessages() {
    if (_inFlightPendingMessages.isEmpty) return;
    final messages = List<ClientMessage>.from(_inFlightPendingMessages.values);
    for (final dedupeKey in _inFlightPendingMessages.keys) {
      _inFlightPendingVisibilityTimers.remove(dedupeKey)?.cancel();
      _visibleInFlightPendingKeys.remove(dedupeKey);
    }
    _inFlightPendingMessages.clear();
    var didAdd = false;
    for (final message in messages) {
      didAdd = _addQueuedMessageIfAbsent(message) || didAdd;
    }
    _publishOfflinePendingActions();
    if (didAdd) {
      unawaited(_persistOfflinePendingMessages());
    }
  }

  void _flushMessageQueue() {
    unawaited(_flushMessageQueueAsync());
  }

  Future<void> _flushMessageQueueAsync() async {
    await _ensureOfflineQueueRestored();
    if (_messageQueue.isEmpty || !isConnected) return;
    final queued = List<ClientMessage>.from(_messageQueue);
    _messageQueue.clear();
    await _persistOfflinePendingMessages();
    _publishOfflinePendingActions();
    for (final msg in queued) {
      send(msg);
    }
  }

  Future<void> _ensureOfflineQueueRestored() {
    return _offlineQueueRestore ??= _restoreOfflinePendingMessages();
  }

  bool _isPersistableOfflineMessage(ClientMessage message) {
    return switch (message.type) {
      'input' ||
      'start' ||
      'resume_session' ||
      'rename_session' ||
      'update_queued_input' ||
      'cancel_queued_input' => true,
      _ => false,
    };
  }

  String? _offlineMessageDedupeKey(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    return switch (message.type) {
      'input' when json['clientMessageId'] is String =>
        'input:${json['sessionId'] ?? ''}:${json['clientMessageId']}',
      'resume_session' =>
        'resume:${json['provider'] ?? 'claude'}:${json['sessionId']}',
      'start' => 'start:${_canonicalJson(json)}',
      _ => null,
    };
  }

  String _offlinePendingActionId(ClientMessage message) {
    final key =
        _offlineMessageDedupeKey(message) ??
        _canonicalJson(jsonDecode(message.toJson()) as Map<String, dynamic>);
    return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
  }

  String _canonicalJson(Object? value) {
    if (value is Map) {
      final normalized = <String, Object?>{};
      for (final key in value.keys.map((k) => k.toString()).toList()..sort()) {
        normalized[key] = _canonicalValue(value[key]);
      }
      return jsonEncode(normalized);
    }
    return jsonEncode(_canonicalValue(value));
  }

  Object? _canonicalValue(Object? value) {
    if (value is Map) {
      return {
        for (final key in value.keys.map((k) => k.toString()).toList()..sort())
          key: _canonicalValue(value[key]),
      };
    }
    if (value is List) {
      return value.map(_canonicalValue).toList();
    }
    return value;
  }

  OfflinePendingAction? _offlinePendingActionFor(
    ClientMessage message, {
    bool canCancel = true,
  }) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final projectPath = json['projectPath'] as String?;
    if (projectPath == null || projectPath.isEmpty) return null;
    final provider = json['provider'] as String? ?? Provider.claude.value;
    final createdAt = DateTime.now();
    return switch (message.type) {
      'start' => OfflinePendingAction(
        id: _offlinePendingActionId(message),
        kind: OfflinePendingActionKind.start,
        projectPath: projectPath,
        provider: provider,
        createdAt: createdAt,
        canCancel: canCancel,
      ),
      'resume_session' => OfflinePendingAction(
        id: _offlinePendingActionId(message),
        kind: OfflinePendingActionKind.resume,
        projectPath: projectPath,
        provider: provider,
        createdAt: createdAt,
        canCancel: canCancel,
        sessionId: json['sessionId'] as String?,
      ),
      _ => null,
    };
  }

  void _publishOfflinePendingActions() {
    final actions = <OfflinePendingAction>[];
    final seen = <String>{};
    for (final message in _messageQueue) {
      final action = _offlinePendingActionFor(message);
      if (action == null || !seen.add(action.id)) continue;
      actions.add(action);
    }
    for (final entry in _inFlightPendingMessages.entries) {
      if (!_visibleInFlightPendingKeys.contains(entry.key)) continue;
      final message = entry.value;
      final action = _offlinePendingActionFor(message, canCancel: false);
      if (action == null || !seen.add(action.id)) continue;
      actions.add(action);
    }
    _offlinePendingActions = List.unmodifiable(actions);
    _offlinePendingActionsController.add(_offlinePendingActions);
  }

  bool _samePendingProjectPath(String a, String b) {
    String normalize(String value) {
      final trimmed = value.trim();
      if (trimmed == '/') return trimmed;
      return trimmed.replaceAll(RegExp(r'/+$'), '');
    }

    return normalize(a) == normalize(b);
  }

  bool _compatiblePendingProjectPath(String a, String b) {
    if (_samePendingProjectPath(a, b)) return true;

    String basename(String value) {
      final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
      final parts = normalized.split('/').where((part) => part.isNotEmpty);
      return parts.isEmpty ? normalized : parts.last;
    }

    final left = basename(a);
    final right = basename(b);
    return left.isNotEmpty && left == right;
  }

  Future<void> cancelOfflinePendingAction(String actionId) async {
    await _ensureOfflineQueueRestored();
    _messageQueue.removeWhere((message) {
      final action = _offlinePendingActionFor(message);
      return action?.id == actionId;
    });
    for (final entry in List.of(_inFlightPendingMessages.entries)) {
      final message = entry.value;
      final action = _offlinePendingActionFor(message, canCancel: false);
      if (action?.id == actionId) {
        _clearInFlightPendingMessage(entry.key);
      }
    }
    _publishOfflinePendingActions();
    await _persistOfflinePendingMessages();
  }

  void _clearPendingSessionActionFor(SystemMessage message) {
    final provider = message.provider ?? Provider.claude.value;
    final projectPath = message.projectPath;
    final claudeSessionId = message.claudeSessionId;
    final sourceSessionId = message.sourceSessionId;

    bool matches(ClientMessage pending) {
      final action = _offlinePendingActionFor(pending);
      if (action == null || action.provider != provider) return false;
      if (action.kind == OfflinePendingActionKind.start) return false;
      if (projectPath != null &&
          !_samePendingProjectPath(action.projectPath, projectPath)) {
        return false;
      }
      return action.sessionId == claudeSessionId ||
          action.sessionId == sourceSessionId ||
          (claudeSessionId == null && sourceSessionId == null);
    }

    var removed = false;
    for (final entry in List.of(_inFlightPendingMessages.entries)) {
      if (!_shouldClearPendingStartForSessionCreated(
        entry.value,
        provider: provider,
        projectPath: projectPath,
      )) {
        if (!matches(entry.value)) continue;
      }
      _clearInFlightPendingMessage(entry.key);
      removed = true;
      break;
    }
    if (!removed) {
      final before = _messageQueue.length;
      var didRemove = false;
      _messageQueue.removeWhere((pending) {
        if (didRemove) return false;
        if (!_shouldClearPendingStartForSessionCreated(
          pending,
          provider: provider,
          projectPath: projectPath,
        )) {
          if (!matches(pending)) return false;
        }
        didRemove = true;
        return true;
      });
      removed = before != _messageQueue.length;
      if (removed) {
        unawaited(_persistOfflinePendingMessages());
      }
    }
    if (removed) {
      _publishOfflinePendingActions();
    }
  }

  bool _shouldClearPendingStartForSessionCreated(
    ClientMessage pending, {
    required String provider,
    required String? projectPath,
  }) {
    final action = _offlinePendingActionFor(pending);
    if (action == null ||
        action.kind != OfflinePendingActionKind.start ||
        action.provider != provider) {
      return false;
    }
    if (projectPath == null || projectPath.isEmpty) {
      return true;
    }
    if (_compatiblePendingProjectPath(action.projectPath, projectPath)) {
      return true;
    }
    return false;
  }

  void _clearPendingStartActionsForSessions(List<SessionInfo> sessions) {
    if (sessions.isEmpty ||
        (_messageQueue.isEmpty && _inFlightPendingMessages.isEmpty)) {
      return;
    }

    bool overlapsActiveSession(OfflinePendingAction action) {
      if (action.kind != OfflinePendingActionKind.start) return false;
      final sameProviderSessions = sessions.where((session) {
        final provider = session.provider ?? Provider.claude.value;
        return provider == action.provider;
      }).toList();
      if (sameProviderSessions.isEmpty) return false;
      return sameProviderSessions.any(
        (session) => _compatiblePendingProjectPath(
          action.projectPath,
          session.projectPath,
        ),
      );
    }

    var removed = false;
    for (final entry in List.of(_inFlightPendingMessages.entries)) {
      final action = _offlinePendingActionFor(entry.value, canCancel: false);
      if (action == null || !overlapsActiveSession(action)) continue;
      _clearInFlightPendingMessage(entry.key);
      removed = true;
    }

    final before = _messageQueue.length;
    _messageQueue.removeWhere((message) {
      final action = _offlinePendingActionFor(message);
      return action != null && overlapsActiveSession(action);
    });
    final removedQueued = before != _messageQueue.length;
    removed = removed || removedQueued;

    if (!removed) return;
    if (removedQueued) {
      unawaited(_persistOfflinePendingMessages());
    }
    _publishOfflinePendingActions();
  }

  Future<void> _restoreOfflinePendingMessages() async {
    final generation = _offlineQueueGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_prefKeyOfflinePendingMessages);
      if (encoded == null || encoded.isEmpty) return;
      if (generation != _offlineQueueGeneration) return;

      final existingJson = _messageQueue
          .map((message) => message.toJson())
          .toSet();
      final existingDedupeKeys = _messageQueue
          .map(_offlineMessageDedupeKey)
          .whereType<String>()
          .toSet();
      existingDedupeKeys.addAll(_inFlightPendingMessages.keys);
      for (final raw in encoded) {
        try {
          final json = jsonDecode(raw);
          if (json is! Map<String, dynamic>) continue;
          final message = ClientMessage.raw(json);
          if (!_isPersistableOfflineMessage(message)) continue;
          final dedupeKey = _offlineMessageDedupeKey(message);
          final isDuplicate = dedupeKey != null
              ? !existingDedupeKeys.add(dedupeKey)
              : !existingJson.add(message.toJson());
          if (!isDuplicate) {
            if (generation != _offlineQueueGeneration) return;
            _messageQueue.add(message);
          }
        } catch (error, stackTrace) {
          logger.warning(
            'Failed to restore offline pending message',
            error,
            stackTrace,
          );
        }
      }
      _publishOfflinePendingActions();
    } catch (error, stackTrace) {
      if (_isSharedPreferencesUnavailable(error)) {
        return;
      }
      logger.warning(
        'Failed to load offline pending messages',
        error,
        stackTrace,
      );
    }
  }

  bool _isSharedPreferencesUnavailable(Object error) {
    if (error is MissingPluginException) return true;
    final message = error.toString();
    return message.contains('Binding has not yet been initialized');
  }

  Future<void> _persistOfflinePendingMessages() async {
    await _ensureOfflineQueueRestored();
    final pending = _messageQueue
        .where(_isPersistableOfflineMessage)
        .map((message) => message.toJson())
        .toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pending.isEmpty) {
        await prefs.remove(_prefKeyOfflinePendingMessages);
      } else {
        await prefs.setStringList(_prefKeyOfflinePendingMessages, pending);
      }
    } catch (error, stackTrace) {
      logger.warning(
        'Failed to persist offline pending messages',
        error,
        stackTrace,
      );
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
        provider: _currentProvider,
        namedOnly: _currentNamedOnly,
        searchQuery: _currentSearchQuery,
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
        provider: _currentProvider,
        namedOnly: _currentNamedOnly,
        searchQuery: _currentSearchQuery,
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
        provider: _currentProvider,
        namedOnly: _currentNamedOnly,
        searchQuery: _currentSearchQuery,
      ),
    );
  }

  /// Switch all filters at once and re-fetch from offset 0.
  void switchFilter({
    String? projectPath,
    String? provider,
    bool? namedOnly,
    String? searchQuery,
    int pageSize = 20,
  }) {
    _currentProjectFilter = projectPath;
    _currentProvider = provider;
    _currentNamedOnly = namedOnly;
    _currentSearchQuery = searchQuery;
    _appendMode = false;
    send(
      ClientMessage.listRecentSessions(
        limit: pageSize,
        offset: 0,
        projectPath: projectPath,
        provider: provider,
        namedOnly: namedOnly,
        searchQuery: searchQuery,
      ),
    );
  }

  @override
  void requestSessionHistory(String sessionId) {
    final snapshot = _runtimeStore.snapshot(sessionId);
    if (snapshot.messages.isNotEmpty) {
      _pendingHistoryDeltaSinceSeq[sessionId] = snapshot.cachedHistorySeq;
      send(
        ClientMessage.getHistoryDelta(
          sessionId,
          sinceSeq: snapshot.cachedHistorySeq,
        ),
      );
      return;
    }
    send(ClientMessage.getHistory(sessionId));
  }

  void refreshBranch(String sessionId) {
    send(ClientMessage.refreshBranch(sessionId));
  }

  void requestMessageImages({
    required String claudeSessionId,
    required String messageUuid,
  }) {
    send(
      ClientMessage.getMessageImages(
        claudeSessionId: claudeSessionId,
        messageUuid: messageUuid,
      ),
    );
  }

  void resumeSession(
    String sessionId,
    String projectPath, {
    String? permissionMode,
    String? executionMode,
    String? approvalPolicy,
    String? approvalsReviewer,
    String? codexPermissionsMode,
    bool? planMode,
    String? effort,
    int? maxTurns,
    double? maxBudgetUsd,
    String? fallbackModel,
    bool? forkSession,
    bool? persistSession,
    String? profile,
    String? provider,
    String? sandboxMode,
    String? model,
    String? modelReasoningEffort,
    bool? networkAccessEnabled,
    String? webSearchMode,
    List<String>? additionalWritableRoots,
  }) {
    send(
      ClientMessage.resumeSession(
        sessionId,
        projectPath,
        permissionMode: permissionMode,
        executionMode: executionMode,
        approvalPolicy: approvalPolicy,
        approvalsReviewer: approvalsReviewer,
        codexPermissionsMode: codexPermissionsMode,
        planMode: planMode,
        effort: effort,
        maxTurns: maxTurns,
        maxBudgetUsd: maxBudgetUsd,
        fallbackModel: fallbackModel,
        forkSession: forkSession,
        persistSession: persistSession,
        profile: profile,
        provider: provider,
        sandboxMode: sandboxMode,
        model: model,
        modelReasoningEffort: modelReasoningEffort,
        networkAccessEnabled: networkAccessEnabled,
        webSearchMode: webSearchMode,
        additionalWritableRoots: additionalWritableRoots,
      ),
    );
  }

  Future<bool> updateOfflinePendingInput({
    required String sessionId,
    required String clientMessageId,
    required String text,
    List<Map<String, String>>? skills,
    List<Map<String, String>>? mentions,
  }) async {
    await _ensureOfflineQueueRestored();
    var updated = false;
    for (var i = 0; i < _messageQueue.length; i++) {
      final json =
          jsonDecode(_messageQueue[i].toJson()) as Map<String, dynamic>;
      if (json['type'] != 'input' ||
          json['sessionId'] != sessionId ||
          json['clientMessageId'] != clientMessageId) {
        continue;
      }
      json['text'] = text;
      if (skills != null && skills.isNotEmpty) {
        json['skills'] = skills;
        json['skill'] = skills.first;
      } else {
        json.remove('skills');
        json.remove('skill');
      }
      if (mentions != null && mentions.isNotEmpty) {
        json['mentions'] = mentions;
      } else {
        json.remove('mentions');
      }
      _messageQueue[i] = ClientMessage.raw(json);
      updated = true;
      break;
    }
    if (!updated) return false;
    _publishOfflinePendingActions();
    await _persistOfflinePendingMessages();
    return true;
  }

  Future<bool> cancelOfflinePendingInput({
    required String sessionId,
    required String clientMessageId,
  }) async {
    await _ensureOfflineQueueRestored();
    final before = _messageQueue.length;
    _messageQueue.removeWhere((message) {
      final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
      return json['type'] == 'input' &&
          json['sessionId'] == sessionId &&
          json['clientMessageId'] == clientMessageId;
    });
    if (before == _messageQueue.length) return false;
    _publishOfflinePendingActions();
    await _persistOfflinePendingMessages();
    return true;
  }

  @override
  void stopSession(String sessionId) {
    send(ClientMessage.stopSession(sessionId));
    clearExplorerHistory(sessionId);
    _sessionStoppedController.add(sessionId);
    clearDiffImageCache();
  }

  ExplorerHistorySnapshot getExplorerHistory(String sessionId) {
    return _runtimeStore.getExplorerHistory(sessionId);
  }

  List<ServerMessage> cachedSessionMessages(String sessionId) {
    return _runtimeStore.messages(sessionId);
  }

  @override
  int cachedSessionHistorySeq(String sessionId) {
    return _runtimeStore.cachedHistorySeq(sessionId);
  }

  void setExplorerHistory(
    String sessionId, {
    required String currentPath,
    required List<String> recentPeekedFiles,
  }) {
    final normalizedPath = currentPath.trim();
    final normalizedFiles = recentPeekedFiles
        .map((file) => file.trim())
        .where((file) => file.isNotEmpty)
        .take(10)
        .toList();
    if (normalizedPath.isEmpty && normalizedFiles.isEmpty) {
      _runtimeStore.setExplorerHistory(
        sessionId,
        currentPath: '',
        recentPeekedFiles: const [],
      );
      return;
    }
    _runtimeStore.setExplorerHistory(
      sessionId,
      currentPath: normalizedPath,
      recentPeekedFiles: normalizedFiles,
    );
  }

  void migrateExplorerHistory(String fromSessionId, String toSessionId) {
    _runtimeStore.migrateSession(fromSessionId, toSessionId);
  }

  void clearExplorerHistory(String sessionId) {
    _runtimeStore.clearSession(sessionId);
  }

  /// Rename a session. For running sessions, [sessionId] is the bridge id.
  /// For recent sessions, include [provider], [providerSessionId], and [projectPath].
  void renameSession({
    required String sessionId,
    String? name,
    String? provider,
    String? providerSessionId,
    String? projectPath,
  }) {
    send(
      ClientMessage.renameSession(
        sessionId: sessionId,
        name: name,
        provider: provider,
        providerSessionId: providerSessionId,
        projectPath: projectPath,
      ),
    );
  }

  void archiveSession({
    required String sessionId,
    required String provider,
    required String projectPath,
  }) {
    send(
      ClientMessage.archiveSession(
        sessionId: sessionId,
        provider: provider,
        projectPath: projectPath,
      ),
    );
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

  void requestPromptHistorySync({
    required String clientId,
    String? clientName,
    int? sinceRevision,
  }) {
    send(
      ClientMessage.syncPromptHistory(
        clientId: clientId,
        clientName: clientName,
        sinceRevision: sinceRevision,
      ),
    );
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

  void registerPushToken({
    required String token,
    required String platform,
    String? locale,
    bool? privacyMode,
  }) {
    send(
      ClientMessage.pushRegister(
        token: token,
        platform: platform,
        locale: locale,
        privacyMode: privacyMode,
      ),
    );
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
      ProcessStatus.compacting => 'compacting',
    };
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    if (current.status == statusStr && current.pendingPermission == null) {
      return;
    }
    // Clear pendingPermission when status moves away from waiting_approval
    final shouldClear =
        statusStr != 'waiting_approval' && current.pendingPermission != null;
    _sessions = List.of(_sessions)
      ..[idx] = current.copyWith(
        status: statusStr,
        clearPermission: shouldClear,
      );
    _sessionListController.add(_sessions);
  }

  /// Attach a [PermissionRequestMessage] to the cached session for real-time
  /// display. The server also includes this in session_list responses, but
  /// this method provides instant UI feedback without waiting for the next
  /// session_list refresh.
  void _patchSessionPermission(
    String sessionId,
    PermissionRequestMessage permission,
  ) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    _sessions = List.of(_sessions)
      ..[idx] = _sessions[idx].copyWith(pendingPermission: permission);
    _sessionListController.add(_sessions);
  }

  void _patchSessionPermissionMode(
    String sessionId,
    String permissionMode, {
    String? provider,
    String? executionMode,
    bool? planMode,
    String? approvalPolicy,
    String? approvalsReviewer,
    String? codexPermissionsMode,
  }) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    _patchSessionModes(
      sessionId,
      permissionMode: permissionMode,
      executionMode:
          executionModeFromRaw(executionMode)?.value ??
          deriveExecutionMode(
            provider: provider ?? current.provider,
            executionMode: executionMode,
            permissionMode: permissionMode,
            approvalPolicy: approvalPolicy ?? current.codexApprovalPolicy,
          ).value,
      planMode:
          planMode ??
          derivePlanMode(planMode: planMode, permissionMode: permissionMode),
      approvalPolicy: approvalPolicy,
      approvalsReviewer: approvalsReviewer,
      codexPermissionsMode: codexPermissionsMode,
    );
  }

  void patchSessionModes(
    String sessionId, {
    required String permissionMode,
    required String executionMode,
    required bool planMode,
    String? approvalPolicy,
    String? approvalsReviewer,
    String? codexPermissionsMode,
  }) {
    _patchSessionModes(
      sessionId,
      permissionMode: permissionMode,
      executionMode: executionMode,
      planMode: planMode,
      approvalPolicy: approvalPolicy,
      approvalsReviewer: approvalsReviewer,
      codexPermissionsMode: codexPermissionsMode,
    );
  }

  void _patchSessionModes(
    String sessionId, {
    required String permissionMode,
    required String executionMode,
    required bool planMode,
    String? approvalPolicy,
    String? approvalsReviewer,
    String? codexPermissionsMode,
  }) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    if (current.permissionMode == permissionMode &&
        current.executionMode == executionMode &&
        current.planMode == planMode &&
        (codexPermissionsMode == null ||
            current.codexPermissionsMode == codexPermissionsMode) &&
        (approvalsReviewer == null ||
            current.codexApprovalsReviewer == approvalsReviewer)) {
      return;
    }
    _sessions = List.of(_sessions)
      ..[idx] = current.copyWith(
        permissionMode: permissionMode,
        executionMode: executionMode,
        planMode: planMode,
        codexApprovalPolicy: approvalPolicy ?? current.codexApprovalPolicy,
        codexApprovalsReviewer:
            approvalsReviewer ?? current.codexApprovalsReviewer,
        codexPermissionsMode:
            codexPermissionsMode ?? current.codexPermissionsMode,
      );
    _sessionListController.add(_sessions);
  }

  void _patchSessionSystemSettings(String sessionId, SystemMessage message) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    final codexModel = sanitizeCodexModelName(message.model);
    _sessions = List.of(_sessions)
      ..[idx] = current.copyWith(
        permissionMode: message.permissionMode ?? current.permissionMode,
        executionMode: message.executionMode ?? current.executionMode,
        planMode: message.planMode ?? current.planMode,
        model: message.provider == Provider.claude.value ? message.model : null,
        codexApprovalPolicy: resolveCodexApprovalPolicy(
          approvalPolicy: message.approvalPolicy ?? current.codexApprovalPolicy,
          executionMode: message.executionMode ?? current.executionMode,
        ),
        codexApprovalsReviewer:
            message.approvalsReviewer ?? current.codexApprovalsReviewer,
        codexPermissionsMode:
            message.codexPermissionsMode ?? current.codexPermissionsMode,
        codexSandboxMode: message.provider == Provider.codex.value
            ? (message.sandboxMode ?? current.codexSandboxMode)
            : current.codexSandboxMode,
        codexModel: message.provider == Provider.codex.value
            ? (codexModel ?? current.codexModel)
            : current.codexModel,
        codexModelReasoningEffort:
            message.modelReasoningEffort ?? current.codexModelReasoningEffort,
        codexNetworkAccessEnabled:
            message.networkAccessEnabled ?? current.codexNetworkAccessEnabled,
        codexWebSearchMode: message.webSearchMode ?? current.codexWebSearchMode,
      );
    _sessionListController.add(_sessions);
  }

  /// Update the cached lastMessage when an [AssistantMessage] arrives so the
  /// session list card shows the latest response in real-time.
  void _patchSessionLastMessage(String sessionId, AssistantMessage message) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    final messageModel = sanitizeCodexModelName(message.model) ?? '';
    final text = message.content
        .map(_assistantContentPreviewText)
        .where((text) => text.isNotEmpty)
        .join(' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final shouldPatchModel =
        current.provider == Provider.codex.value &&
        messageModel.isNotEmpty &&
        messageModel != current.codexModel;
    if (text.isEmpty && !shouldPatchModel) return;
    final preview = text.length > 100 ? text.substring(0, 100) : text;
    _sessions = List.of(_sessions)
      ..[idx] = current.copyWith(
        lastMessage: text.isNotEmpty ? preview : null,
        codexModel: shouldPatchModel ? messageModel : null,
      );
    _sessionListController.add(_sessions);
  }

  String _assistantContentPreviewText(AssistantContent content) {
    return switch (content) {
      TextContent(:final text) => text,
      ToolUseContent(:final name, :final input)
          when isCodexUpdatePlanTool(name) =>
        codexPlanUpdateTextFromInput(input) ?? '',
      _ => '',
    };
  }

  /// Clear pending permission from a cached session after the user has
  /// acted on it (approve/reject/answer). Provides instant UI feedback
  /// without waiting for the server status change.
  void clearSessionPermission(String sessionId) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    _sessions = List.of(_sessions)
      ..[idx] = _sessions[idx].copyWith(clearPermission: true);
    _sessionListController.add(_sessions);
  }

  void _patchSessionQueuedInput(String sessionId, QueuedInputItem? item) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    _sessions = List.of(_sessions)
      ..[idx] = _sessions[idx].copyWith(
        queuedInput: item,
        clearQueuedInput: item == null,
      );
    _sessionListController.add(_sessions);
  }

  List<SessionInfo> _applyLocalDeliveryPendingInputs(
    List<SessionInfo> sessions,
  ) {
    return sessions.map((session) {
      final pending = deliveryPendingInputForSession(session.id);
      if (pending == null) return session;
      return session.copyWith(queuedInput: pending);
    }).toList();
  }

  void patchSessionPermissionMode(String sessionId, String permissionMode) {
    _patchSessionPermissionMode(sessionId, permissionMode);
  }

  void patchSessionSandboxMode(String sessionId, String sandboxMode) {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;
    final current = _sessions[idx];
    if (current.codexSandboxMode == sandboxMode) return;
    _sessions = List.of(_sessions)
      ..[idx] = current.copyWith(codexSandboxMode: sandboxMode);
    _sessionListController.add(_sessions);
  }

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedMessageController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  /// Try to auto-connect using saved preferences.
  ///
  /// [apiKey] should be provided from [FlutterSecureStorage] via
  /// [MachineManagerService]. Falls back to legacy [SharedPreferences]
  /// for migration.
  Future<bool> autoConnect({String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_prefKeyUrl);
    if (url == null || url.isEmpty) return false;

    // Prefer caller-provided apiKey (from SecureStorage), fall back to
    // legacy SharedPreferences value for backward compatibility.
    final effectiveApiKey = apiKey ?? prefs.getString(_prefKeyApiKey);

    var connectUrl = url;
    if (effectiveApiKey != null && effectiveApiKey.isNotEmpty) {
      final sep = connectUrl.contains('?') ? '&' : '?';
      connectUrl = '$connectUrl${sep}token=$effectiveApiKey';
    }

    // Migrate: remove legacy plaintext API key from SharedPreferences.
    if (prefs.containsKey(_prefKeyApiKey)) {
      await prefs.remove(_prefKeyApiKey);
    }

    connect(connectUrl);
    return true;
  }

  /// Save connection URL to preferences.
  ///
  /// API keys are stored separately via [FlutterSecureStorage] in
  /// [MachineManagerService], not in [SharedPreferences].
  Future<void> savePreferences(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyUrl, url);
    // API key is no longer stored in SharedPreferences (plaintext).
    // It is managed by MachineManagerService via FlutterSecureStorage.
    // Clean up any legacy value.
    if (prefs.containsKey(_prefKeyApiKey)) {
      await prefs.remove(_prefKeyApiKey);
    }
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
    _connectionEpoch++;
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _setBridgeConnectionState(BridgeConnectionState.disconnected);
    _clearBridgeScopedState(clearOfflineQueue: true);
    final disconnectCallback = onDisconnect;
    if (disconnectCallback != null) {
      unawaited(Future<void>.sync(disconnectCallback));
    }
  }

  // ---------------------------------------------------------------------------
  // Diff image cache
  // ---------------------------------------------------------------------------

  static String _diffImageCacheKey(String projectPath, String filePath) =>
      '$projectPath\n$filePath';

  /// Retrieve cached image bytes for a diff file.
  DiffImageCacheEntry? getDiffImageCache(String projectPath, String filePath) =>
      _diffImageCache[_diffImageCacheKey(projectPath, filePath)];

  /// Store image bytes in the diff cache.
  void setDiffImageCache(
    String projectPath,
    String filePath,
    DiffImageCacheEntry entry,
  ) {
    _diffImageCache[_diffImageCacheKey(projectPath, filePath)] = entry;
  }

  /// Clear all cached diff images.
  void clearDiffImageCache() => _diffImageCache.clear();

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    for (final timer in _inFlightPendingVisibilityTimers.values) {
      timer.cancel();
    }
    _inFlightPendingVisibilityTimers.clear();
    for (final timer in _deliveryPendingVisibilityTimers.values) {
      timer.cancel();
    }
    _deliveryPendingVisibilityTimers.clear();
    _deliveryPendingInputs.clear();
    _inFlightInputMessages.clear();
    _channelSub?.cancel();
    _channelSub = null;
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
    _taggedMessageController.close();
    _connectionController.close();
    _sessionListController.close();
    _sessionStoppedController.close();
    _recentSessionsController.close();
    _galleryController.close();
    _fileListController.close();
    _projectHistoryController.close();
    _diffResultController.close();
    _diffImageResultController.close();
    _worktreeListController.close();
    _windowListController.close();
    _screenshotResultController.close();
    _offlinePendingActionsController.close();
    _debugBundleController.close();
    _usageController.close();
    _backupResultController.close();
    _restoreResultController.close();
    _backupInfoController.close();
    _promptHistorySyncController.close();
    _promptHistoryMutationController.close();
    _promptHistoryStatusController.close();
    // Git Operations
    _gitStageResultController.close();
    _gitUnstageResultController.close();
    _gitUnstageHunksResultController.close();
    _gitCommitResultController.close();
    _gitPushResultController.close();
    _gitBranchesResultController.close();
    _gitCreateBranchResultController.close();
    _gitCheckoutBranchResultController.close();
    _gitRevertFileResultController.close();
    _gitRevertHunksResultController.close();
    _gitFetchResultController.close();
    _gitPullResultController.close();
    _gitStatusResultController.close();
    _gitRemoteStatusResultController.close();
    clearDiffImageCache();
  }
}

class _DeliveryPendingInputState {
  _DeliveryPendingInputState(this.item);

  final QueuedInputItem item;
  bool visible = false;
}

/// Cached diff image data for a single file.
class DiffImageCacheEntry {
  final int? oldSize;
  final int? newSize;
  final Uint8List? oldBytes;
  final Uint8List? newBytes;

  const DiffImageCacheEntry({
    this.oldSize,
    this.newSize,
    this.oldBytes,
    this.newBytes,
  });
}
