// Renders the stills shown in the package README.
//
// Each one is a single MarkdownView with the package's built-in theme and no
// app chrome, so the pictures show what the package draws by itself:
//
//     flutter run -t tool/screenshots.dart --dart-define=SHOT=blocks
//
// SHOT is one of: blocks, selection, extras, dark. Capture the device once
// the page has settled. On the selection page, long-press a word first.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:markdown_kit/markdown_kit.dart';
import 'package:markdown_kit_example/math.dart';

const _shot = String.fromEnvironment('SHOT', defaultValue: 'blocks');

void main() => runApp(const _ScreenshotApp());

const _blocks = r'''
## Release checklist

Ship from `main` once **every** step is done. See the
[release guide](https://example.com/release) for details.

1. Bump the version
   - `pubspec.yaml`
   - `CHANGELOG.md`
2. Run the checks
3. Tag and push

- [x] Analyzer is clean
- [ ] Store listing updated

```dart
Future<void> release(String version) async {
  await runChecks();
  await tag('v$version');
}
```

| Platform | Channel    | Status |
| :------- | :--------- | :----: |
| iOS      | TestFlight |   ✅   |
| Android  | Internal   |   ⏳   |

> [!WARNING]
> Tags are pushed one at a time.
''';

const _selection = r'''
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

Wrap the call in `try` / `on FormatException` to show a friendly error.
''';

const _extras = r'''
## Beyond CommonMark

Quicksort averages \(O(n \log n)\) comparisons[^1]. The recurrence is

\[T(n) = 2\,T\!\left(\frac{n}{2}\right) + O(n)\]

> [!NOTE]
> Math is typeset by a builder; see `example/lib/math.dart`.

> [!TIP]
> Alerts come in five kinds.

<details>
<summary>Why not merge sort?</summary>

It needs \(O(n)\) extra memory.

</details>

Press <kbd>Ctrl</kbd>+<kbd>C</kbd> to stop. Water is H<sub>2</sub>O, and
area grows as r<sup>2</sup>. ~~Bubble sort~~ is not an option.

> A quote with a nested list:
>
> - first
> - second

[^1]: On average; the worst case is quadratic.
''';

class _ScreenshotApp extends StatelessWidget {
  const _ScreenshotApp();

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF1F6FEB),
      debugShowCheckedModeBanner: false,
      home: const _Page(),
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
    );
  }
}

class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  final _controller = MarkdownSelectionController();

  bool get _dark => _shot == 'dark';

  String get _data => switch (_shot) {
    'selection' => _selection,
    'extras' => _extras,
    _ => _blocks,
  };

  @override
  void initState() {
    super.initState();
    if (_shot == 'selection') {
      // Handles belong to a selection started by touch, so this page waits
      // for a long-press in the list and then extends that
      // selection into the table, the way dragging the end handle would.
      _controller.addListener(_extendOnce);
    }
  }

  bool _extended = false;

  void _extendOnce() {
    if (_extended || !_controller.hasSelection) return;
    _extended = true;
    Timer(const Duration(milliseconds: 600), () {
      _controller
        ..extendToGlobal(const Offset(_endX, _endY))
        ..toolbarWanted = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _dark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
      child: SafeArea(
        child: MarkdownSelectionScope(
          controller: _controller,
          child: SingleChildScrollView(
            // The selection page leaves room above its first line for the
            // context menu.
            padding: EdgeInsets.fromLTRB(
              20,
              _shot == 'selection' ? 72 : 12,
              20,
              12,
            ),
            child: MarkdownView(
              data: _data,
              documentId: 'shot',
              theme: _dark ? MarkdownThemeData.dark() : null,
              builders: const MarkdownBuilders(
                inlineLatexBuilder: buildInlineMath,
                blockLatexBuilder: buildBlockMath,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Where the selection page ends its selection, in logical pixels of a
// 402 x 874 screen.
const double _endX = 150;
const double _endY = 440;
