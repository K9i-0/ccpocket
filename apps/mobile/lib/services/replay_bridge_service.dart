import 'dart:async';

import '../models/messages.dart';
import '../models/recorded_event.dart';
import 'bridge_service.dart';

/// A chunk of outgoing server messages grouped between user actions.
class _ReplayChunk {
  _ReplayChunk({required this.messages, required this.delays});

  /// The server messages in this chunk.
  final List<ServerMessage> messages;

  /// The relative delay (from chunk start) for each message.
  final List<Duration> delays;
}

/// Replay mode for controlling playback timing.
enum ReplayMode {
  /// Use original timing deltas between messages.
  realtime,

  /// Emit all messages in a chunk instantly (for tests).
  instant,
}

/// A [BridgeService] that replays recorded session messages.
///
/// Loads a JSONL recording (from [RecordingStore]) and replays the
/// server→client messages. User actions (approve, reject, input, etc.)
/// serve as breakpoints between message chunks.
///
/// Usage:
/// ```dart
/// final service = ReplayBridgeService(mode: ReplayMode.realtime);
/// service.loadFromJsonLines(lines);
/// service.play(); // starts emitting the first chunk
/// // When the user taps approve, service.send() advances to next chunk
/// ```
class ReplayBridgeService extends BridgeService {
  ReplayBridgeService({this.mode = ReplayMode.realtime});

  final ReplayMode mode;

  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();

  final _timers = <Timer>[];
  final sentMessages = <ClientMessage>[];

  List<_ReplayChunk> _chunks = [];
  int _currentChunk = 0;
  String? _sessionId;
  bool _isPlaying = false;

  /// Whether all chunks have been played.
  bool get isComplete => _currentChunk >= _chunks.length;

  /// The number of chunks in the recording.
  int get chunkCount => _chunks.length;

  /// The current chunk index.
  int get currentChunkIndex => _currentChunk;

  // ---------------------------------------------------------------------------
  // Loading
  // ---------------------------------------------------------------------------

  /// Load a recording from JSONL lines.
  void loadFromJsonLines(List<String> lines) {
    final events = RecordedEvent.parseJsonLines(lines);
    _buildChunks(events);
  }

  /// Load a recording from a JSONL string.
  void loadFromJsonlString(String jsonl) {
    final events = RecordedEvent.parseJsonlString(jsonl);
    _buildChunks(events);
  }

  /// Build replay chunks from recorded events.
  ///
  /// Groups consecutive outgoing messages into chunks, separated by
  /// incoming (user action) events.
  void _buildChunks(List<RecordedEvent> events) {
    _chunks = [];
    _currentChunk = 0;

    if (events.isEmpty) return;

    // Extract sessionId from first outgoing message
    for (final e in events) {
      if (e.isOutgoing) {
        _sessionId = e.message['sessionId'] as String?;
        break;
      }
    }

    var currentMessages = <ServerMessage>[];
    var currentDelays = <Duration>[];
    DateTime? chunkStartTime;

    for (final event in events) {
      if (event.isOutgoing) {
        // Try to parse as ServerMessage
        try {
          final msg = ServerMessage.fromJson(event.message);
          chunkStartTime ??= event.timestamp;
          currentMessages.add(msg);
          currentDelays.add(event.timestamp.difference(chunkStartTime));
        } catch (_) {
          // Skip messages that can't be parsed
        }
      } else if (event.isIncoming) {
        // Skip infrastructure messages that aren't real user actions.
        // These are sent automatically by the session screen and shouldn't
        // create breakpoints in the replay.
        final type = event.type;
        if (_isInfrastructureMessage(type)) continue;

        // Incoming event = breakpoint. Flush current chunk if non-empty.
        if (currentMessages.isNotEmpty) {
          _chunks.add(
            _ReplayChunk(
              messages: List.of(currentMessages),
              delays: List.of(currentDelays),
            ),
          );
          currentMessages = [];
          currentDelays = [];
          chunkStartTime = null;
        }
      }
    }

    // Flush remaining outgoing messages as the last chunk
    if (currentMessages.isNotEmpty) {
      _chunks.add(
        _ReplayChunk(
          messages: List.of(currentMessages),
          delays: List.of(currentDelays),
        ),
      );
    }
  }

  /// Messages that are sent automatically by the session screen and should
  /// not create breakpoints in the replay.
  static const _infrastructureTypes = {
    'get_history',
    'list_sessions',
    'list_recent_sessions',
    'list_files',
    'list_gallery',
    'list_project_history',
    'get_debug_bundle',
    'list_recordings',
    'get_usage',
  };

  static bool _isInfrastructureMessage(String type) =>
      _infrastructureTypes.contains(type);

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Start playing the recording. Emits the first chunk automatically.
  void play() {
    if (_chunks.isEmpty || _isPlaying) return;
    _isPlaying = true;
    _playCurrentChunk();
  }

  /// Advance to and play the next chunk.
  void _advanceToNextChunk() {
    _currentChunk++;
    if (_currentChunk < _chunks.length) {
      _playCurrentChunk();
    }
  }

  /// Play all messages in the current chunk.
  void _playCurrentChunk() {
    if (_currentChunk >= _chunks.length) return;

    // Cancel any pending timers from previous chunk to avoid overlap
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    final chunk = _chunks[_currentChunk];

    for (var i = 0; i < chunk.messages.length; i++) {
      final message = chunk.messages[i];
      final delay = chunk.delays[i];

      if (mode == ReplayMode.instant || delay == Duration.zero) {
        _emit(message);
      } else {
        final timer = Timer(delay, () => _emit(message));
        _timers.add(timer);
      }
    }
  }

  void _emit(ServerMessage message) {
    if (_messageController.isClosed) return;
    _taggedController.add((message, _sessionId));
    _messageController.add(message);
  }

  // ---------------------------------------------------------------------------
  // BridgeService overrides
  // ---------------------------------------------------------------------------

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  String? get httpBaseUrl => null;

  @override
  bool get isConnected => true;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<List<String>> get fileList => _fileListController.stream;

  @override
  Stream<List<SessionInfo>> get sessionList => _sessionListController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
    // Any user action advances the replay to the next chunk
    _advanceToNextChunk();
  }

  @override
  void interrupt(String sessionId) {}

  @override
  void stopSession(String sessionId) {}

  @override
  void requestFileList(String projectPath) {}

  @override
  void requestSessionList() {}

  @override
  void requestSessionHistory(String sessionId) {
    // Trigger initial playback when the session screen requests history.
    if (!_isPlaying) {
      scheduleMicrotask(play);
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _messageController.close();
    _taggedController.close();
    _connectionController.close();
    _fileListController.close();
    _sessionListController.close();
    super.dispose();
  }
}
