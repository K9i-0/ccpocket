/// Runs the 652 examples of the CommonMark 0.31.2 specification through
/// [GfmMarkdownParser].
///
/// markdown_kit is not a CommonMark renderer: it produces an AST for chat
/// messages, shows raw HTML as text, and adds GFM and its own extensions. So
/// the goal here is not 100%, it is to know exactly which examples differ and
/// why, and to notice when that set changes.
///
/// Each example is sorted into one of three outcomes:
/// - `pass`: the AST, written as HTML, equals the specification's HTML.
/// - `upstream`: it differs, and plain `package:markdown` (GFM) differs from
///   the specification too. The cause is below markdown_kit.
/// - `kit`: it differs although `package:markdown` matches. The cause is in
///   markdown_kit's conversion or extensions, by design or by defect.
///
/// `baseline.json` records the examples in the last two groups, `kit` ones
/// with the reason. The test fails when an example leaves or enters a group,
/// in either direction, so the baseline can only change deliberately:
///
/// ```sh
/// UPDATE_COMMONMARK_BASELINE=1 flutter test test/commonmark_spec
/// ```
///
/// Reasons already written are kept; new `kit` entries are marked `TODO` and
/// must be explained before committing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_kit/markdown_kit.dart';

import 'html_writer.dart';

const _dir = 'test/commonmark_spec';

String _upstreamHtml(String markdown) {
  try {
    return md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubFlavored,
    );
  } catch (_) {
    return '<<upstream threw>>';
  }
}

void main() {
  final examples = (jsonDecode(
    File('$_dir/spec.json').readAsStringSync(),
  ) as List).cast<Map<String, dynamic>>();
  final baselineFile = File('$_dir/baseline.json');
  final baseline = baselineFile.existsSync()
      ? jsonDecode(baselineFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final knownUpstream = ((baseline['upstream'] as List?) ?? const [])
      .cast<int>()
      .toSet();
  final knownKit = ((baseline['kit'] as Map<String, dynamic>?) ?? const {})
      .cast<String, String>();
  final update = Platform.environment['UPDATE_COMMONMARK_BASELINE'] == '1';

  final upstream = <int>[];
  final kit = <String, String>{};
  var passed = 0;

  for (final example in examples) {
    final number = example['example'] as int;
    final section = example['section'] as String;
    final markdown = example['markdown'] as String;
    final expected = normalizeHtml(example['html'] as String);

    test('example $number ($section)', () {
      final parser = GfmMarkdownParser();
      final actual = normalizeHtml(documentToHtml(parser.parse(markdown)));
      expect(
        parser.rawTextFallbackCount,
        0,
        reason: 'degraded to raw text: ${jsonEncode(markdown)}',
      );

      final String outcome;
      if (actual == expected) {
        outcome = 'pass';
        passed++;
      } else if (normalizeHtml(_upstreamHtml(markdown)) != expected) {
        outcome = 'upstream';
        upstream.add(number);
      } else {
        outcome = 'kit';
        kit['$number'] = knownKit['$number'] ?? 'TODO: reason ($section)';
      }
      if (update) return;

      final recorded = knownUpstream.contains(number)
          ? 'upstream'
          : knownKit.containsKey('$number')
          ? 'kit'
          : 'pass';
      expect(
        outcome,
        recorded,
        reason:
            'markdown: ${jsonEncode(markdown)}\n'
            'expected: $expected\n'
            'actual:   $actual',
      );
    });
  }

  test('every markdown_kit difference in the baseline has a reason', () {
    expect(
      knownKit.entries
          .where((entry) => entry.value.startsWith('TODO'))
          .map((entry) => entry.key),
      isEmpty,
    );
  });

  tearDownAll(() {
    if (!update) return;
    baselineFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'summary': '$passed of ${examples.length} examples match; '
          '${upstream.length} differ in package:markdown, '
          '${kit.length} differ in markdown_kit.', 'upstream': upstream..sort(), 'notes': baseline['notes'] ?? <String, dynamic>{}, 'kit': Map.fromEntries(kit.entries.toList()..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key))))})}\n',
    );
  });
}
