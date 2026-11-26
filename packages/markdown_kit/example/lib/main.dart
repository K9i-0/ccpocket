import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';

void main() => runApp(const ExampleApp());

const sampleMarkdown = r'''
# markdown_kit

Renders **GitHub-Flavored Markdown** with `package:flutter/widgets.dart` only,
and lets the reader select text across blocks. Long-press on a touch screen, or
drag with a mouse, then copy as text or as Markdown.

> [!TIP]
> Press **Stream** to replay this document token by token.

## Lists

1. Ordered item
   - Nested bullet
   - [x] Done task
   - [ ] Open task
2. Another item

## Table

| Feature | Supported |
| :------ | :-------: |
| Tables  |    yes    |
| Alerts  |    yes    |

## Code

```dart
void main() => print('Hello, markdown_kit');
```

Inline math \(E = mc^2\), a [link](https://flutter.dev), a footnote[^1], and
<kbd>Ctrl</kbd>+<kbd>C</kbd>.

<details>
<summary>More</summary>

Hidden until opened.

</details>

[^1]: Footnotes are collected at the end.
''';

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'markdown_kit example',
      color: const Color(0xFF1F6FEB),
      // A Navigator supplies the Overlay that selection handles and the
      // context menu are drawn in.
      home: const ExamplePage(),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  String _text = sampleMarkdown;
  bool _streaming = false;
  String _status = 'Tap a link to see its destination here.';
  Timer? _timer;

  void _stream() {
    _timer?.cancel();
    var length = 0;
    setState(() {
      _text = '';
      _streaming = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      length = (length + 6).clamp(0, sampleMarkdown.length);
      setState(() {
        _text = sampleMarkdown.substring(0, length);
        if (length == sampleMarkdown.length) {
          _streaming = false;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF57606A),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _stream,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF1F6FEB),
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Stream',
                          style: TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              // One scope around the scroll view: selection survives
              // scrolling, and dragging a handle to an edge scrolls the list.
              child: MarkdownSelectionScope(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownView(
                    data: _text,
                    isStreaming: _streaming,
                    builders: MarkdownBuilders(
                      onLinkTap: (destination, title) {
                        setState(() => _status = 'Link: $destination');
                      },
                    ),
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
