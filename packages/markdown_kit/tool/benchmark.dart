// Measures the two workloads the package is tuned for, so a change can be
// compared before and after:
//
//     flutter test tool/benchmark.dart
//
// - chat: one long reply streamed two characters at a time.
// - editor: single characters typed into the middle of a long document.
//
// Times are wall-clock medians in a debug VM and only meaningful relative to
// another run on the same machine. The built/reused counts are exact.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

const _section = r'''
## Reading a JSON file, part {n}

Use `dart:convert` and read the file **asynchronously** so the UI stays
responsive. This is paragraph {n} of the reply.

1. Read the file as a string
2. Decode it with `jsonDecode`
3. Map the result to your own type

```dart
Future<Config> loadConfig{n}(File file) async {
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
> Wrap call {n} in `try` / `on FormatException` to show a friendly error.

See the [dart:convert docs](https://api.dart.dev/dart-convert) for more.
''';

String _document(int sections) =>
    [for (var i = 0; i < sections; i++) _section.replaceAll('{n}', '$i')]
        .join();

int _median(List<int> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(size: Size(420, 680)),
    child: SingleChildScrollView(child: child),
  ),
);

void main() {
  final results = <String, Object>{};
  tearDownAll(() {
    // ignore: avoid_print
    print('BENCHMARK ${jsonEncode(results)}');
  });

  test('chat: parse a streamed reply', () {
    final reply = _document(8);
    final times = <int>[];
    for (var run = 0; run < 9; run++) {
      final parser = GfmMarkdownParser();
      final watch = Stopwatch()..start();
      for (var end = 2; end < reply.length; end += 2) {
        parser.parse(reply.substring(0, end), isStreaming: true);
      }
      parser.parse(reply);
      times.add(watch.elapsedMicroseconds);
    }
    results['chat_parse_stream_us'] = _median(times.sublist(2));
    results['chat_reply_chars'] = reply.length;
  });

  test('chat: parse finished replies cold', () {
    final reply = _document(8);
    final times = <int>[];
    for (var run = 0; run < 30; run++) {
      final parser = GfmMarkdownParser();
      final watch = Stopwatch()..start();
      parser.parse(reply);
      times.add(watch.elapsedMicroseconds);
    }
    results['chat_parse_cold_us'] = _median(times.sublist(5));
  });

  testWidgets('chat: stream a reply into MarkdownView', (tester) async {
    final reply = _document(4);
    final times = <int>[];
    var built = 0;
    var reused = 0;
    for (var run = 0; run < 5; run++) {
      built = 0;
      reused = 0;
      final parser = GfmMarkdownParser();
      await tester.pumpWidget(const SizedBox());
      final watch = Stopwatch()..start();
      for (var end = 2; end < reply.length; end += 2) {
        await tester.pumpWidget(
          _host(
            MarkdownView(
              data: reply.substring(0, end),
              isStreaming: true,
              parser: parser,
              documentId: 'reply',
              onBlockBuilt: (_, _) => built++,
              onBlockReused: (_, _) => reused++,
            ),
          ),
        );
      }
      await tester.pumpWidget(
        _host(
          MarkdownView(
            data: reply,
            parser: parser,
            documentId: 'reply',
            onBlockBuilt: (_, _) => built++,
            onBlockReused: (_, _) => reused++,
          ),
        ),
      );
      times.add(watch.elapsedMicroseconds);
    }
    results['chat_view_stream_us'] = _median(times.sublist(1));
    results['chat_view_built'] = built;
    results['chat_view_reused'] = reused;
  });

  test('editor: parse while typing in the middle', () {
    final before = _document(30);
    final after = _document(30);
    final times = <int>[];
    for (var run = 0; run < 7; run++) {
      final parser = GfmMarkdownParser();
      parser.parse('$before\n$after');
      var typed = '';
      final watch = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        typed += 'word '[i % 5];
        parser.parse('$before$typed\n$after');
      }
      times.add(watch.elapsedMicroseconds ~/ 100);
    }
    results['editor_parse_per_key_us'] = _median(times.sublist(2));
    results['editor_doc_chars'] = before.length + after.length;
  });

  testWidgets('editor: type into one block in the middle of MarkdownView', (
    tester,
  ) async {
    final before = _document(6);
    final after = _document(6);
    var built = 0;
    var reused = 0;
    final parser = GfmMarkdownParser();
    Widget view(String data) => _host(
      MarkdownView(
        data: data,
        parser: parser,
        documentId: 'doc',
        onBlockBuilt: (_, _) => built++,
        onBlockReused: (_, _) => reused++,
      ),
    );
    await tester.pumpWidget(view('$before\nw\n\n$after'));
    built = 0;
    reused = 0;
    final watch = Stopwatch()..start();
    var typed = 'w';
    for (var i = 1; i < 41; i++) {
      typed += 'word'[i % 4];
      await tester.pumpWidget(view('$before\n$typed\n\n$after'));
    }
    results['editor_view_per_key_us'] = watch.elapsedMicroseconds ~/ 40;
    results['editor_view_built'] = built;
    results['editor_view_reused'] = reused;
  });

  testWidgets('editor: add and remove a block in the middle of MarkdownView', (
    tester,
  ) async {
    final before = _document(30);
    final after = _document(30);
    var built = 0;
    var reused = 0;
    final parser = GfmMarkdownParser();
    Widget view(String data) => _host(
      MarkdownView(
        data: data,
        parser: parser,
        documentId: 'doc',
        onBlockBuilt: (_, _) => built++,
        onBlockReused: (_, _) => reused++,
      ),
    );
    final without = '$before\n$after';
    final withBlock = '$before\nnew paragraph\n\n$after';
    await tester.pumpWidget(view(without));
    await tester.pumpWidget(view(withBlock));
    await tester.pumpWidget(view(without));
    built = 0;
    reused = 0;
    final watch = Stopwatch()..start();
    for (var i = 0; i < 10; i++) {
      await tester.pumpWidget(view(i.isEven ? withBlock : without));
    }
    results['editor_view_per_insert_us'] = watch.elapsedMicroseconds ~/ 10;
    results['editor_view_insert_built'] = built;
    results['editor_view_insert_reused'] = reused;
  });
}
