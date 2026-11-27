import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

import 'math.dart';
import 'theme.dart';

/// Default streaming reply shown in the chat example.
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

Decoding is linear in the input: \(T(n) = O(n)\) for \(n\) bytes. Reading
\(k\) files of average size \(\bar{n}\) therefore costs

\[T = \sum_{i=1}^{k} O(n_i) = O(k\,\bar{n})\]

See the [dart:convert docs](https://api.dart.dev/dart-convert) for more.
''';

/// A reply packed with half-written syntax boundaries so the difference
/// between `isStreaming: true` and `isStreaming: false` is easy to see.
const _streamingStressReply = r'''
## Holding unfinished syntax

Toggle **Hold syntax** above while this streams to compare:

- Inline **bold text**, *emphasis*, ~~strikethrough~~ and `inline_code()` wait
  until their closing marker arrives instead of flashing raw punctuation.
- Links such as [CommonMark](https://spec.commonmark.org) and
  [pub.dev](https://pub.dev) stay hidden until `)` closes them.

| Construct | While open | When closed |
| :-------- | :--------- | :---------- |
| `**bold**` | Held at the tail | Rendered bold |
| `` `code` `` | Held at the tail | Styled code pill |
| Fenced code | Kept as code block | Finalized |
| Table row | Incomplete row held | Added cleanly |

```dart
MarkdownView(
  data: reply.text,
  isStreaming: reply.streaming,
  documentId: reply.id,
)
```

> [!NOTE]
> Try selecting text above while tokens are still arriving: the highlight is
> anchored in the document model, so it stays put across updates and scrolling.
''';

/// A longer multi-section reply for testing scroll survival and cross-block
/// selection in a lazy `ListView.builder`.
const _longGuideReply = r'''
## Selection that survives scrolling

In a lazy `ListView.builder`, items recycle as they leave the viewport.
`MarkdownSelectionScope` keeps the parsed documents registered by `documentId`,
so a selection remains valid even when part of it scrolls off screen.

### What to try

1. Drag (or long-press on touch) across this list, the code block and the table
2. Scroll up and down while the selection is active
3. Copy as **plain text** vs **Markdown** from the context menu or bottom bar

- [x] Blocks before the tail are parsed once
- [x] Handles stay clear of list scrolling on touch devices
- [x] Copy omits code block headers and bullet glyphs

```dart
final controller = MarkdownSelectionController(
  allowCrossDocumentSelection: false,
);
```

| Copy mode | Result |
| :-------- | :----- |
| Plain text | Clean prose and code, no bullet glyphs |
| Copy as Markdown | Rebuilt headings, lists, fences and tables |

> [!IMPORTANT]
> Give each message a stable `documentId` so switching `isStreaming` from
> `true` to `false` keeps the active selection intact.

<details>
<summary>Why finished blocks stay cheap</summary>

`markdown_kit` splits the document into top-level blocks and caches every
finished block. While tokens append to the last block, earlier blocks keep
their widgets and layout without re-parsing.

</details>
''';

typedef _ChatPreset = ({String id, String label, String prompt, String reply});

const _presets = <_ChatPreset>[
  (
    id: 'json',
    label: 'JSON & Math',
    prompt: 'How do I read a JSON file?',
    reply: sampleReply,
  ),
  (
    id: 'streaming',
    label: 'Streaming edge cases',
    prompt: 'Show how unfinished syntax is handled while streaming.',
    reply: _streamingStressReply,
  ),
  (
    id: 'long',
    label: 'Scroll & selection',
    prompt: 'Explain how selection survives scrolling in a chat list.',
    reply: _longGuideReply,
  ),
];

/// Streaming playback speed.
enum StreamSpeed {
  /// Slow enough to inspect incomplete-syntax holding token by token.
  slow(label: 'Slow', charsPerTick: 1, interval: Duration(milliseconds: 28)),

  /// Everyday AI chat cadence.
  normal(
    label: 'Normal',
    charsPerTick: 2,
    interval: Duration(milliseconds: 16),
  ),

  /// Rapid output for stress testing.
  fast(label: 'Fast', charsPerTick: 6, interval: Duration(milliseconds: 16));

  const StreamSpeed({
    required this.label,
    required this.charsPerTick,
    required this.interval,
  });

  final String label;
  final int charsPerTick;
  final Duration interval;
}

/// One message in the chat transcript.
class ChatMessage {
  /// Creates a message.
  ChatMessage({required this.id, required this.fromUser, required this.text});

  /// Stable identifier passed as `documentId`.
  final String id;

  /// Whether the message was sent by the user.
  final bool fromUser;

  /// Current text of the message.
  String text;

  /// Whether tokens are still arriving.
  bool streaming = false;
}

/// AI chat view demonstrating token-by-token streaming, incomplete syntax
/// holding, and model-anchored selection inside a lazy `ListView.builder`.
class ChatTab extends StatefulWidget {
  /// Creates the chat tab.
  const ChatTab({super.key, required this.colors, this.active = true});

  /// Active colour palette.
  final ExampleColors colors;

  /// Whether this tab is currently visible.
  final bool active;

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  // One controller for the whole list. A selection stays inside the message
  // it started in, which is what a chat usually wants.
  final _selection = MarkdownSelectionController(
    allowCrossDocumentSelection: false,
  );
  final _input = TextEditingController();
  final _inputFocus = FocusNode(debugLabel: 'chat-input');

  late List<ChatMessage> _messages = _initialMessages();
  Timer? _timer;
  ChatMessage? _streamingMessage;
  String _streamingTarget = '';
  int _streamingOffset = 0;

  bool _holdSyntax = true;
  StreamSpeed _speed = StreamSpeed.normal;
  int _nextPresetIndex = 0;
  String? _notice;

  bool get _busy => _timer?.isActive ?? false;

  static List<ChatMessage> _initialMessages() => <ChatMessage>[
    ChatMessage(id: 'u0', fromUser: true, text: 'How do I read a JSON file?'),
    ChatMessage(id: 'a0', fromUser: false, text: sampleReply),
  ];

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _selection.toolbarWanted = false;
      _inputFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _startStream({required String prompt, required String replyText}) {
    _stopStream(finishCurrent: true);

    final index = _messages.length ~/ 2;
    final reply = ChatMessage(id: 'a$index', fromUser: false, text: '')
      ..streaming = true;

    setState(() {
      _notice = null;
      _messages
        ..add(ChatMessage(id: 'u$index', fromUser: true, text: prompt))
        ..add(reply);
      _streamingMessage = reply;
      _streamingTarget = replyText;
      _streamingOffset = 0;
    });

    _scheduleStreamTimer();
  }

  void _scheduleStreamTimer() {
    _timer?.cancel();
    if (_streamingMessage == null) return;
    _timer = Timer.periodic(_speed.interval, _onStreamTick);
  }

  void _onStreamTick(Timer timer) {
    final reply = _streamingMessage;
    if (reply == null) {
      timer.cancel();
      return;
    }
    _streamingOffset = (_streamingOffset + _speed.charsPerTick).clamp(
      0,
      _streamingTarget.length,
    );
    final finished = _streamingOffset >= _streamingTarget.length;
    setState(() {
      reply.text = _streamingTarget.substring(0, _streamingOffset);
      if (finished) {
        reply.streaming = false;
        _streamingMessage = null;
        timer.cancel();
      }
    });
  }

  void _stopStream({bool finishCurrent = false}) {
    _timer?.cancel();
    _timer = null;
    final current = _streamingMessage;
    if (current != null) {
      if (finishCurrent && _streamingTarget.isNotEmpty) {
        current.text = _streamingTarget;
      }
      current.streaming = false;
      _streamingMessage = null;
      if (mounted) setState(() {});
    }
  }

  void _resetChat() {
    _stopStream();
    _selection.clear();
    setState(() {
      _messages = _initialMessages();
      _nextPresetIndex = 0;
      _notice = null;
    });
  }

  void _submitInput() {
    if (_busy) return;
    final typed = _input.text.trim();
    if (typed.isEmpty) {
      final preset = _presets[_nextPresetIndex % _presets.length];
      _nextPresetIndex++;
      _startStream(prompt: preset.prompt, replyText: preset.reply);
      return;
    }
    _input.clear();
    final reply = _replyForPrompt(typed);
    _startStream(prompt: typed, replyText: reply);
  }

  String _replyForPrompt(String prompt) {
    final lower = prompt.toLowerCase();
    if (lower.contains('stream') || lower.contains('syntax')) {
      return _streamingStressReply;
    }
    if (lower.contains('scroll') || lower.contains('select')) {
      return _longGuideReply;
    }
    return sampleReply;
  }

  Future<void> _copySelection({required bool asMarkdown}) async {
    final text = asMarkdown ? _selection.getMarkdown() : _selection.getText();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    _selection.toolbarWanted = false;
    if (!mounted) return;
    setState(() {
      final kind = asMarkdown ? 'Markdown' : 'plain text';
      _notice = 'Copied $kind (${text.length} chars)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControlsBar(colors),
        Hairline(colors.border),
        Expanded(
          child: ColoredBox(
            color: colors.background,
            // The scope sits above the scroll view, so selection survives
            // messages scrolling out of the lazy list, and dragging a handle
            // to the edge scrolls the list.
            child: MarkdownSelectionScope(
              controller: _selection,
              child: ListView.builder(
                key: const ValueKey('chat-list'),
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, reversedIndex) {
                  final index = _messages.length - 1 - reversedIndex;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kReadingMaxWidth,
                      ),
                      child: _MessageItem(
                        message: _messages[index],
                        order: index,
                        holdSyntax: _holdSyntax,
                        colors: colors,
                        onLinkTap: (url) =>
                            setState(() => _notice = 'Link: $url'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Hairline(colors.border),
        _buildComposerArea(colors),
      ],
    );
  }

  Widget _buildControlsBar(ExampleColors colors) {
    return ColoredBox(
      color: colors.chrome,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          children: [
            ToggleChip(
              key: const ValueKey('chat-hold-syntax'),
              label: 'Hold syntax',
              on: _holdSyntax,
              colors: colors,
              onChanged: (on) => setState(() => _holdSyntax = on),
            ),
            const SizedBox(width: 8),
            SegmentedSwitch<StreamSpeed>(
              value: _speed,
              colors: colors,
              items: [
                for (final speed in StreamSpeed.values)
                  (
                    value: speed,
                    label: speed.label,
                    key: ValueKey('chat-speed-${speed.name}'),
                  ),
              ],
              onChanged: (speed) {
                setState(() => _speed = speed);
                if (_busy) _scheduleStreamTimer();
              },
            ),
            const SizedBox(width: 8),
            Hairline.vertical(colors.border),
            const SizedBox(width: 8),
            if (_busy)
              ActionButton(
                key: const ValueKey('chat-stop'),
                label: 'Stop',
                colors: colors,
                onPressed: _stopStream,
              )
            else
              ActionButton(
                key: const ValueKey('chat-reset'),
                label: 'Reset',
                colors: colors,
                onPressed: _messages.length > 2 ? _resetChat : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerArea(ExampleColors colors) {
    final hasSelection = _selection.hasSelection;
    final selectedLength = hasSelection ? _selection.getText().length : 0;

    return ColoredBox(
      color: colors.chrome,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kReadingMaxWidth + 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _presets.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        ActionButton(
                          key: ValueKey('chat-preset-${_presets[i].id}'),
                          label: _presets[i].label,
                          colors: colors,
                          onPressed: _busy
                              ? null
                              : () => _startStream(
                                  prompt: _presets[i].prompt,
                                  replyText: _presets[i].reply,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.background,
                          border: Border.all(color: colors.border),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _input,
                                builder: (context, value, _) {
                                  if (value.text.isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return IgnorePointer(
                                    child: Text(
                                      'Ask a question or pick a preset above…',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.muted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              EditableText(
                                key: const ValueKey('chat-input'),
                                controller: _input,
                                focusNode: _inputFocus,
                                style: TextStyle(
                                  color: colors.text,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                                cursorColor: colors.accent,
                                backgroundCursorColor: colors.hover,
                                selectionColor: colors.accent.withValues(
                                  alpha: 0.25,
                                ),
                                maxLines: 1,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _submitInput(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionButton(
                      key: const ValueKey('chat-ask'),
                      label: 'Ask',
                      tone: ActionTone.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      fontSize: 14,
                      colors: colors,
                      onPressed: _busy ? null : _submitInput,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasSelection
                            ? 'Selected $selectedLength chars'
                            : (_notice ??
                                  'Select across blocks even while streaming. '
                                      'Right-click or long-press to copy.'),
                        key: const ValueKey('chat-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.muted, fontSize: 12),
                      ),
                    ),
                    if (hasSelection) ...[
                      const SizedBox(width: 8),
                      ActionButton(
                        key: const ValueKey('chat-copy-plain'),
                        label: 'Copy',
                        tone: ActionTone.subtle,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        fontSize: 12,
                        colors: colors,
                        onPressed: () => _copySelection(asMarkdown: false),
                      ),
                      const SizedBox(width: 4),
                      ActionButton(
                        key: const ValueKey('chat-copy-markdown'),
                        label: 'Copy as Markdown',
                        tone: ActionTone.subtle,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        fontSize: 12,
                        colors: colors,
                        onPressed: () => _copySelection(asMarkdown: true),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  const _MessageItem({
    required this.message,
    required this.order,
    required this.holdSyntax,
    required this.colors,
    required this.onLinkTap,
  });

  final ChatMessage message;
  final int order;
  final bool holdSyntax;
  final ExampleColors colors;
  final ValueChanged<String> onLinkTap;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              // Plain text joins the same selection scope as Markdown replies.
              child: SelectablePlainText(
                message.text,
                documentId: message.id,
                documentOrder: order,
                style: TextStyle(
                  color: colors.text,
                  fontSize: 14.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message.streaming)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                holdSyntax
                    ? 'Streaming · holding unfinished syntax'
                    : 'Streaming · raw mode (Hold syntax off)',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          MarkdownView(
            data: message.text,
            // While true, only the block still being written is re-parsed, and
            // half-typed bold, code, links, tables and fences are held back.
            isStreaming: message.streaming && holdSyntax,
            // A stable id lets selection survive scrolling away and switching
            // from streaming to finished.
            documentId: message.id,
            documentOrder: order,
            theme: colors.markdown,
            builders: MarkdownBuilders(
              onLinkTap: (url, title) => onLinkTap(url),
              inlineLatexBuilder: buildInlineMath,
              blockLatexBuilder: buildBlockMath,
            ),
          ),
        ],
      ),
    );
  }
}
