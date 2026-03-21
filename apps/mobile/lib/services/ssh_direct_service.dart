import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../core/logger.dart';
import '../models/machine.dart';
import '../models/messages.dart';
import 'bridge_service_base.dart';
import 'machine_manager_service.dart';
import 'ssh_message_mapper.dart';

/// SSH Direct Service — connects to a remote machine via SSH and runs
/// Claude Code CLI directly, bypassing the Bridge Server entirely.
///
/// This approach is fully compliant with Anthropic's ToS because:
/// - The `claude` CLI is launched directly by the user (via SSH)
/// - The app is just an SSH client + viewer — no OAuth tokens are used
/// - From Anthropic's perspective, it's identical to using a terminal
///
/// Architecture:
/// ```
/// [CC Pocket App] → SSH → [User's Mac] → claude --output-format stream-json
///                   ↕ stdin/stdout (JSON Lines)
/// ```
class SshDirectService implements BridgeServiceBase {
  final MachineManagerService _machineManager;

  /// SSH connection
  SSHClient? _sshClient;
  SSHSession? _sshSession;

  /// Stream controllers for BridgeServiceBase interface
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedMessageController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();

  /// Internal state
  BridgeConnectionState _connectionState = BridgeConnectionState.disconnected;
  String? _currentSessionId;
  String? _currentProjectPath;
  String? _connectedMachineId;
  final List<SessionInfo> _sessions = [];
  final List<ServerMessage> _sessionHistory = [];

  /// Pending control requests (request_id → completer for approval)
  final _pendingControlRequests = <String, Completer<bool>>{};

  /// Stdout line buffer for JSON parsing
  final _lineBuffer = StringBuffer();

  /// Timeout for SSH connection
  static const _connectionTimeout = Duration(seconds: 15);

  SshDirectService(this._machineManager);

  // ---- BridgeServiceBase implementation ----

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<List<SessionInfo>> get sessionList => _sessionListController.stream;

  @override
  Stream<List<String>> get fileList => _fileListController.stream;

  @override
  String? get httpBaseUrl => null; // No HTTP server in SSH mode

  @override
  bool get isConnected => _connectionState == BridgeConnectionState.connected;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedMessageController.stream
        .where((tagged) {
          final (_, taggedSessionId) = tagged;
          return taggedSessionId == null || taggedSessionId == sessionId;
        })
        .map((tagged) => tagged.$1);
  }

  @override
  void send(ClientMessage message) {
    switch (message.type) {
      case 'start':
        _handleStart(message);
      case 'input':
        _handleInput(message);
      case 'approve':
        _handleApprove(message);
      case 'approve_always':
        _handleApprove(message);
      case 'reject':
        _handleReject(message);
      case 'stop_session':
        _handleStopSession(message);
      case 'interrupt':
        _handleInterrupt(message);
      case 'list_sessions':
        _emitSessionList();
      case 'get_history':
        _handleGetHistory(message);
      case 'set_permission_mode':
        // Permission mode changes require restarting the claude process
        // with different flags. For now, log a warning.
        logger.w('SshDirect: permission mode changes require session restart');
      default:
        logger.d('SshDirect: unsupported message type: ${message.type}');
    }
  }

  @override
  void requestSessionHistory(String sessionId) {
    // Emit cached history
    if (_sessionHistory.isNotEmpty) {
      _emit(HistoryMessage(messages: List.of(_sessionHistory)));
    }
  }

  @override
  void stopSession(String sessionId) {
    send(ClientMessage.stopSession(sessionId));
  }

  @override
  void requestFileList(String projectPath) {
    // File listing via SSH: run `find` or `ls` command
    _runSshCommand('ls -1 "$projectPath" 2>/dev/null | head -100').then((
      output,
    ) {
      if (output != null) {
        final files =
            output
                .split('\n')
                .where((f) => f.isNotEmpty)
                .map((f) => '$projectPath/$f')
                .toList();
        _fileListController.add(files);
      }
    });
  }

  @override
  void requestSessionList() {
    _emitSessionList();
  }

  @override
  void interrupt(String sessionId) {
    send(ClientMessage.interrupt(sessionId));
  }

  // ---- Public API (beyond BridgeServiceBase) ----

  /// Connect to a machine via SSH.
  Future<bool> connect(String machineId) async {
    final machine = _machineManager.getMachine(machineId);
    if (machine == null) {
      logger.e('SshDirect: Machine not found: $machineId');
      return false;
    }

    if (machine.sshUsername == null) {
      logger.e('SshDirect: SSH username not configured');
      return false;
    }

    _setConnectionState(BridgeConnectionState.connecting);

    try {
      final socket = await SSHSocket.connect(
        machine.host,
        machine.sshPort,
        timeout: _connectionTimeout,
      );

      // Authenticate
      String? password;
      String? privateKey;

      if (machine.sshAuthType == SshAuthType.password) {
        password = await _machineManager.getSshPassword(machineId);
        if (password == null || password.isEmpty) {
          _setConnectionState(BridgeConnectionState.disconnected);
          return false;
        }
        _sshClient = SSHClient(
          socket,
          username: machine.sshUsername!,
          onPasswordRequest: () => password!,
        );
      } else {
        privateKey = await _machineManager.getSshPrivateKey(machineId);
        if (privateKey == null || privateKey.isEmpty) {
          _setConnectionState(BridgeConnectionState.disconnected);
          return false;
        }
        _sshClient = SSHClient(
          socket,
          username: machine.sshUsername!,
          identities: [...SSHKeyPair.fromPem(privateKey)],
        );
      }

      _connectedMachineId = machineId;
      _setConnectionState(BridgeConnectionState.connected);

      // Emit initial session list (empty)
      _emitSessionList();

      logger.i('SshDirect: Connected to ${machine.host}:${machine.sshPort}');
      return true;
    } on SSHAuthFailError {
      logger.e('SshDirect: Authentication failed');
      _setConnectionState(BridgeConnectionState.disconnected);
      return false;
    } on TimeoutException {
      logger.e('SshDirect: Connection timeout');
      _setConnectionState(BridgeConnectionState.disconnected);
      return false;
    } catch (e) {
      logger.e('SshDirect: Connection failed: $e');
      _setConnectionState(BridgeConnectionState.disconnected);
      return false;
    }
  }

  /// Disconnect from the remote machine.
  void disconnect() {
    _stopClaudeProcess();
    _sshClient?.close();
    _sshClient = null;
    _connectedMachineId = null;
    _sessions.clear();
    _sessionHistory.clear();
    _setConnectionState(BridgeConnectionState.disconnected);
  }

  /// Dispose all resources.
  void dispose() {
    disconnect();
    _messageController.close();
    _taggedMessageController.close();
    _connectionController.close();
    _sessionListController.close();
    _fileListController.close();
  }

  // ---- Message handlers ----

  void _handleStart(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final projectPath = json['projectPath'] as String? ?? '';
    final permissionMode = json['permissionMode'] as String?;
    final executionMode = json['executionMode'] as String?;
    final planMode = json['planMode'] as bool?;
    final sessionId = json['sessionId'] as String?;
    final model = json['model'] as String?;

    _startClaudeSession(
      projectPath: projectPath,
      sessionId: sessionId,
      permissionMode: permissionMode,
      executionMode: executionMode,
      planMode: planMode,
      model: model,
    );
  }

  void _handleInput(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final text = json['text'] as String? ?? '';
    final images = json['images'] as List?;

    final imageList = images
        ?.map((i) => i as Map<String, dynamic>)
        .toList();

    _sendToClaudeProcess(
      SshMessageMapper.buildUserInput(text, images: imageList),
    );

    // Emit input ack
    _emit(InputAckMessage(sessionId: _currentSessionId));

    // Emit status change to running
    _emit(StatusMessage(status: ProcessStatus.running));
    _updateSessionStatus('running');
  }

  void _handleApprove(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final id = json['id'] as String? ?? '';

    final completer = _pendingControlRequests.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }

    // Send control_response to CLI
    _sendToClaudeProcess(SshMessageMapper.buildApproveResponse(id));

    // Emit permission resolved
    _emit(PermissionResolvedMessage(toolUseId: id));
    _emit(StatusMessage(status: ProcessStatus.running));
    _updateSessionStatus('running');
  }

  void _handleReject(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final id = json['id'] as String? ?? '';
    final rejectMessage = json['message'] as String?;

    final completer = _pendingControlRequests.remove(id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }

    _sendToClaudeProcess(
      SshMessageMapper.buildDenyResponse(id, message: rejectMessage),
    );

    _emit(PermissionResolvedMessage(toolUseId: id));
    _emit(StatusMessage(status: ProcessStatus.running));
    _updateSessionStatus('running');
  }

  void _handleStopSession(ClientMessage message) {
    _stopClaudeProcess();
    _updateSessionStatus('idle');
  }

  void _handleInterrupt(ClientMessage message) {
    // Send SIGINT-equivalent: close the current session's stdin
    // The CLI should handle this gracefully
    _stopClaudeProcess();
    _emit(
      ResultMessage(
        subtype: 'error_during_execution',
        error: 'Session interrupted by user',
      ),
    );
    _updateSessionStatus('idle');
  }

  void _handleGetHistory(ClientMessage message) {
    if (_sessionHistory.isNotEmpty) {
      _emit(HistoryMessage(messages: List.of(_sessionHistory)));
    }
  }

  // ---- Claude CLI process management ----

  Future<void> _startClaudeSession({
    required String projectPath,
    String? sessionId,
    String? permissionMode,
    String? executionMode,
    bool? planMode,
    String? model,
  }) async {
    if (_sshClient == null) {
      _emit(ErrorMessage(message: 'Not connected via SSH'));
      return;
    }

    // Stop any existing session
    _stopClaudeProcess();

    // Generate session ID
    _currentSessionId = sessionId ?? _generateSessionId();
    _currentProjectPath = projectPath;
    _sessionHistory.clear();

    // Build CLI command
    final command = _buildClaudeCommand(
      projectPath: projectPath,
      sessionId: _currentSessionId,
      permissionMode: permissionMode,
      executionMode: executionMode,
      planMode: planMode,
      model: model,
    );

    logger.i('SshDirect: Starting claude session: $command');

    try {
      // Start SSH session with the claude command
      _sshSession = await _sshClient!.execute(command);

      // Update session list
      final session = SessionInfo(
        id: _currentSessionId!,
        provider: 'claude',
        projectPath: projectPath,
        claudeSessionId: _currentSessionId,
        status: 'starting',
        createdAt: DateTime.now().toIso8601String(),
        lastActivityAt: DateTime.now().toIso8601String(),
        permissionMode: permissionMode,
        executionMode: executionMode,
        planMode: planMode ?? false,
        model: model,
      );
      _sessions.clear();
      _sessions.add(session);
      _emitSessionList();

      // Emit status
      _emit(StatusMessage(status: ProcessStatus.starting));

      // Listen to stdout (JSON Lines)
      _sshSession!.stdout
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
            _onStdoutData,
            onDone: _onProcessDone,
            onError: (error) {
              logger.e('SshDirect: stdout error: $error');
              _emit(ErrorMessage(message: 'SSH stdout error: $error'));
            },
          );

      // Listen to stderr for error messages
      _sshSession!.stderr
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen((data) {
            logger.w('SshDirect: stderr: $data');
            // Don't emit all stderr as errors — claude CLI outputs info to stderr
          });
    } catch (e) {
      logger.e('SshDirect: Failed to start claude session: $e');
      _emit(ErrorMessage(message: 'Failed to start Claude session: $e'));
      _updateSessionStatus('idle');
    }
  }

  /// Build the `claude` CLI command with appropriate flags.
  String _buildClaudeCommand({
    required String projectPath,
    String? sessionId,
    String? permissionMode,
    String? executionMode,
    bool? planMode,
    String? model,
  }) {
    final args = <String>[
      'claude',
      '-p', // Print/headless mode
      '--output-format', 'stream-json',
      '--input-format', 'stream-json',
      '--verbose',
    ];

    // Session resumption
    if (sessionId != null) {
      args.addAll(['--session-id', sessionId]);
    }

    // Model selection
    if (model != null && model.isNotEmpty) {
      args.addAll(['--model', model]);
    }

    // Permission handling based on mode
    final effectiveMode = executionMode ?? permissionMode;
    switch (effectiveMode) {
      case 'bypassPermissions':
      case 'fullAccess':
        args.add('--dangerously-skip-permissions');
      case 'acceptEdits':
        args.addAll([
          '--allowedTools',
          'Bash(read_only:true),Read,Glob,Grep,Edit,Write,WebSearch',
        ]);
      case 'plan':
        // Plan mode: no tool execution, just planning
        // Use minimal permissions
        args.addAll(['--allowedTools', 'Read,Glob,Grep,WebSearch']);
      default:
        // Default mode: only safe read-only tools
        args.addAll(['--allowedTools', 'Read,Glob,Grep,WebSearch']);
    }

    // Working directory
    final command = 'cd ${_shellEscape(projectPath)} && ${args.join(' ')}';

    // Wrap in login shell to pick up user's env (nvm, etc.)
    return 'zsh -li -c ${_shellEscape(command)}';
  }

  void _onStdoutData(String data) {
    // Buffer incoming data and process complete lines
    _lineBuffer.write(data);
    final buffered = _lineBuffer.toString();
    final lines = buffered.split('\n');

    // Keep the last (potentially incomplete) line in the buffer
    _lineBuffer.clear();
    if (lines.isNotEmpty && !buffered.endsWith('\n')) {
      _lineBuffer.write(lines.removeLast());
    } else if (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        _processCliMessage(json);
      } catch (e) {
        // Not JSON — could be startup messages or warnings
        logger.d('SshDirect: non-JSON stdout: $trimmed');
      }
    }
  }

  void _processCliMessage(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    // Handle control_request (permission) messages
    if (type == 'control_request') {
      final mapped = SshMessageMapper.mapControlRequest(json);
      if (mapped != null) {
        final (requestId, permMessage) = mapped;
        _pendingControlRequests[requestId] = Completer<bool>();
        _emit(permMessage);
        _emit(StatusMessage(status: ProcessStatus.waitingApproval));
        _updateSessionStatus('waiting_approval');
      }
      return;
    }

    // Map SDK message to ServerMessage
    final serverMessage = SshMessageMapper.mapSdkMessage(json);
    if (serverMessage == null) return;

    // Track history for non-streaming messages
    if (serverMessage is! StreamDeltaMessage &&
        serverMessage is! ThinkingDeltaMessage &&
        serverMessage is! StatusMessage) {
      _sessionHistory.add(serverMessage);
    }

    // Update status on specific message types
    if (serverMessage is SystemMessage &&
        serverMessage.subtype == 'session_created') {
      _emit(StatusMessage(status: ProcessStatus.idle));
      _updateSessionStatus('idle');
    }

    if (serverMessage is ResultMessage) {
      _emit(StatusMessage(status: ProcessStatus.idle));
      _updateSessionStatus('idle');
    }

    _emit(serverMessage);
  }

  void _onProcessDone() {
    logger.i('SshDirect: Claude process finished');

    // If there's still buffered data, try to process it
    final remaining = _lineBuffer.toString().trim();
    if (remaining.isNotEmpty) {
      try {
        final json = jsonDecode(remaining) as Map<String, dynamic>;
        _processCliMessage(json);
      } catch (_) {
        // Ignore
      }
    }
    _lineBuffer.clear();

    // Emit idle status if we didn't get a result message
    _updateSessionStatus('idle');
    _sshSession = null;
  }

  void _sendToClaudeProcess(String jsonLine) {
    if (_sshSession == null) {
      logger.w('SshDirect: No active SSH session to send to');
      return;
    }

    try {
      _sshSession!.stdin.add(utf8.encode('$jsonLine\n'));
    } catch (e) {
      logger.e('SshDirect: Failed to write to stdin: $e');
      _emit(ErrorMessage(message: 'Failed to send message: $e'));
    }
  }

  void _stopClaudeProcess() {
    if (_sshSession != null) {
      try {
        _sshSession!.close();
      } catch (_) {
        // Ignore close errors
      }
      _sshSession = null;
    }
    _lineBuffer.clear();
    _pendingControlRequests.clear();
  }

  /// Run a one-off SSH command (for file listing, etc.)
  Future<String?> _runSshCommand(String command) async {
    if (_sshClient == null) return null;

    try {
      final result = await _sshClient!.run(command);
      return utf8.decode(result);
    } catch (e) {
      logger.e('SshDirect: Command failed: $e');
      return null;
    }
  }

  // ---- Helpers ----

  void _emit(ServerMessage message) {
    _messageController.add(message);
    _taggedMessageController.add((message, _currentSessionId));
  }

  void _setConnectionState(BridgeConnectionState state) {
    _connectionState = state;
    _connectionController.add(state);
  }

  void _emitSessionList() {
    _sessionListController.add(List.unmodifiable(_sessions));
  }

  void _updateSessionStatus(String status) {
    if (_currentSessionId == null) return;

    final idx = _sessions.indexWhere((s) => s.id == _currentSessionId);
    if (idx >= 0) {
      _sessions[idx] = _sessions[idx].copyWith(
        status: status,
        lastMessage: '',
      );
      _emitSessionList();
    }
  }

  String _generateSessionId() {
    // Simple UUID-like ID
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'ssh-${now.toRadixString(36)}';
  }

  /// Shell-escape a string for safe use in a command.
  static String _shellEscape(String s) {
    return "'${s.replaceAll("'", "'\\''")}'";
  }
}
