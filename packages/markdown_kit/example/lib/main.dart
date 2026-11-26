import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

void main() => runApp(const ExampleApp());

/// The reply the example "agent" streams.
const sampleReply = r'''
## Reading a JSON file

Use `dart:convert` and read the file **asynchronously** so the UI stays
responsive.

1. Read the file as a string
2. Decode it with `jsonDecode`
3. Map the result to your own type

```dart
Future<Config> loadConfig(File file) async {
  final text = await file.readAsString();
  final json = jsonDecode(text) as Map<String, Object?>;
  return Config.fromJson(json);
}
```

| Step   | API                 | Throws |
| :----- | :------------------ | :----: |
| Read   | `File.readAsString` |  yes   |
| Decode | `jsonDecode`        |  yes   |

> [!TIP]
> Wrap the call in `try` / `on FormatException` to show a friendly error.

See the [dart:convert docs](https://api.dart.dev/dart-convert) for more.
''';

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'markdown_kit example',
      color: const Color(0xFF1F6FEB),
      debugShowCheckedModeBanner: false,
      // A Navigator supplies the Overlay that selection handles and the
      // context menu are drawn in.
      home: const ChatPage(),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

class Message {
  Message({required this.id, required this.fromUser, required this.text});

  final String id;
  final bool fromUser;
  String text;
  bool streaming = false;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // One controller for the whole list. A selection stays inside the message
  // it started in, which is what a chat usually wants.
  final _selection = MarkdownSelectionController(
    allowCrossDocumentSelection: false,
  );

  final _messages = <Message>[
    Message(id: 'u0', fromUser: true, text: 'How do I read a JSON file?'),
    Message(id: 'a0', fromUser: false, text: sampleReply),
  ];

  Timer? _timer;
  String _status = 'Long-press a reply to select. Tap a link to see it here.';

  bool get _busy => _timer?.isActive ?? false;

  void _ask() {
    if (_busy) return;
    final index = _messages.length ~/ 2;
    final reply = Message(id: 'a$index', fromUser: false, text: '')
      ..streaming = true;
    setState(() {
      _messages
        ..add(Message(id: 'u$index', fromUser: true, text: 'Show me again.'))
        ..add(reply);
    });

    var length = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      length = (length + 2).clamp(0, sampleReply.length);
      setState(() {
        reply.text = sampleReply.substring(0, length);
        if (length == sampleReply.length) {
          reply.streaming = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFFFFFF),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // The scope sits above the scroll view, so the selection
              // survives messages scrolling out of the lazy list, and dragging
              // a handle to the edge scrolls the list.
              child: MarkdownSelectionScope(
                controller: _selection,
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, reversedIndex) {
                    final index = _messages.length - 1 - reversedIndex;
                    return _MessageView(
                      message: _messages[index],
                      order: index,
                      onLinkTap: (url) => setState(() => _status = url),
                    );
                  },
                ),
              ),
            ),
            _Composer(status: _status, busy: _busy, onAsk: _ask),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.message,
    required this.order,
    required this.onLinkTap,
  });

  final Message message;
  final int order;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xFFDDF4FF),
              borderRadius: BorderRadius.all(Radius.circular(14)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              // Plain text joins the same selection as the Markdown replies.
              child: SelectablePlainText(
                message.text,
                documentId: message.id,
                documentOrder: order,
                style: const TextStyle(
                  color: Color(0xFF1F2328),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: MarkdownView(
        data: message.text,
        // While true, only the block still being written is re-parsed, and
        // half-typed fences are held back instead of flickering.
        isStreaming: message.streaming,
        // A stable id lets a selection survive the item scrolling away and
        // the switch from streaming to finished.
        documentId: message.id,
        documentOrder: order,
        builders: MarkdownBuilders(onLinkTap: (url, title) => onLinkTap(url)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.status,
    required this.busy,
    required this.onAsk,
  });

  final String status;
  final bool busy;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFD0D7DE))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                status,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF57606A), fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onAsk,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: busy
                      ? const Color(0xFF8C959F)
                      : const Color(0xFF1F6FEB),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Text(
                    'Ask',
                    style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
