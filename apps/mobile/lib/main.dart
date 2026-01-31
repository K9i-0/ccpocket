import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'models/messages.dart';
import 'services/bridge_service.dart';
import 'widgets/message_bubble.dart';

void main() {
  if (kDebugMode) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  runApp(const CcpocketApp());
}

class CcpocketApp extends StatelessWidget {
  const CcpocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ccpocket',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final BridgeService _bridge = BridgeService();
  final List<ChatEntry> _entries = [];
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _urlController =
      TextEditingController(text: 'ws://localhost:8765');
  final TextEditingController _projectPathController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isConnected = false;
  bool _sessionStarted = false;
  ProcessStatus _status = ProcessStatus.idle;
  String? _pendingToolUseId;

  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<bool>? _connectionSub;

  @override
  void initState() {
    super.initState();
    _messageSub = _bridge.messages.listen(_onServerMessage);
    _connectionSub = _bridge.connectionStatus.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (!connected) {
          _sessionStarted = false;
          _status = ProcessStatus.idle;
        }
      });
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _bridge.dispose();
    _inputController.dispose();
    _urlController.dispose();
    _projectPathController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServerMessage(ServerMessage msg) {
    setState(() {
      switch (msg) {
        case StatusMessage(:final status):
          _status = status;
          _pendingToolUseId = null;
        case AssistantServerMessage(:final message):
          _entries.add(ServerChatEntry(msg));
          for (final content in message.content) {
            if (content is ToolUseContent) {
              _pendingToolUseId = content.id;
            }
          }
        case HistoryMessage(:final messages):
          for (final m in messages) {
            if (m is! StatusMessage) {
              _entries.add(ServerChatEntry(m));
            }
            if (m is StatusMessage) {
              _status = m.status;
            }
          }
        case SystemMessage():
          _entries.add(ServerChatEntry(msg));
          _sessionStarted = true;
        default:
          _entries.add(ServerChatEntry(msg));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _connect() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      _bridge.connect(url);
    }
  }

  void _disconnect() {
    _bridge.disconnect();
    setState(() {
      _isConnected = false;
      _sessionStarted = false;
      _status = ProcessStatus.idle;
      _pendingToolUseId = null;
    });
  }

  void _startSession() {
    final path = _projectPathController.text.trim();
    if (path.isNotEmpty) {
      _bridge.send(ClientMessage.start(path));
      setState(() {
        _entries.clear();
        _sessionStarted = true;
      });
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _entries.add(UserChatEntry(text));
    });
    _bridge.send(ClientMessage.input(text));
    _inputController.clear();
    _scrollToBottom();
  }

  void _approveToolUse() {
    if (_pendingToolUseId != null) {
      _bridge.send(ClientMessage.approve(_pendingToolUseId!));
      setState(() => _pendingToolUseId = null);
    }
  }

  void _rejectToolUse() {
    if (_pendingToolUseId != null) {
      _bridge.send(ClientMessage.reject(_pendingToolUseId!));
      setState(() => _pendingToolUseId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ccpocket'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          _buildStatusIndicator(),
          if (_isConnected)
            IconButton(
              key: const ValueKey('disconnect_button'),
              icon: const Icon(Icons.link_off),
              onPressed: _disconnect,
              tooltip: 'Disconnect',
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected) _buildConnectBar(),
          if (_isConnected && !_sessionStarted) _buildSessionBar(),
          Expanded(child: _buildMessageList()),
          if (_status == ProcessStatus.waitingApproval &&
              _pendingToolUseId != null)
            _buildApprovalBar(),
          if (_isConnected && _sessionStarted) _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final (color, label) = switch (_status) {
      ProcessStatus.idle => (Colors.grey, 'Idle'),
      ProcessStatus.running => (Colors.green, 'Running'),
      ProcessStatus.waitingApproval => (Colors.orange, 'Approval'),
    };
    return Padding(
      key: const ValueKey('status_indicator'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildConnectBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('server_url_field'),
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'ws://localhost:8765',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _connect(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('connect_button'),
              onPressed: _connect,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('project_path_field'),
            controller: _projectPathController,
            decoration: const InputDecoration(
              labelText: 'Project Path',
              hintText: '/path/to/your/project',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _startSession(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('start_session_button'),
              onPressed: _startSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Session'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      key: const ValueKey('message_list'),
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        return ChatEntryWidget(entry: _entries[index]);
      },
    );
  }

  Widget _buildApprovalBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(top: BorderSide(color: Colors.orange.shade200)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Tool execution requires approval',
              style: TextStyle(fontSize: 13),
            ),
          ),
          OutlinedButton(
            key: const ValueKey('reject_button'),
            onPressed: _rejectToolUse,
            child: const Text('Reject'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('approve_button'),
            onPressed: _approveToolUse,
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('message_input'),
              controller: _inputController,
              decoration: const InputDecoration(
                hintText: 'Message Claude...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              enabled: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('send_button'),
            onPressed:
                _sendMessage,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
