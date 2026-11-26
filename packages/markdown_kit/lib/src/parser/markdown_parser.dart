import 'dart:collection';

import 'package:meta/meta.dart';

import '../ast/markdown_ast.dart';
import 'inline_scanner.dart';

/// Configuration options controlling Markdown parsing extensions.
@immutable
class MarkdownParserOptions {
  /// Creates parser options. Alerts, HTML tags, footnotes and
  /// backslash-delimited LaTeX are on by default.
  const MarkdownParserOptions({
    this.enableAlerts = true,
    this.enableHtml = true,
    this.enableFootnotes = true,
    this.enableLatex = true,
    this.enableDollarLatex = false,
    this.softBreakAsHardBreak = false,
    this.inlineRules = const [],
  });

  /// Enables GitHub-Flavored Markdown alert callouts (`> [!NOTE]`, etc.).
  final bool enableAlerts;

  /// Enables common HTML tags (`<br>`, `<details>/<summary>`, `<b>`/`<strong>`,
  /// `<i>`/`<em>`, `<u>`, `<s>`/`<del>`, `<sub>`, `<sup>`, `<kbd>`, `<a>`,
  /// `<img>`).
  final bool enableHtml;

  /// Enables footnote references (`[^1]`) and definitions (`[^1]: ...`).
  final bool enableFootnotes;

  /// Enables LaTeX delimiters `\(...\)` (inline) and `\[...\]` (display).
  final bool enableLatex;

  /// Opt-in support for `$...$` (inline) and `$$...$$` (display) LaTeX syntax.
  ///
  /// Defaults to `false` so currency expressions like `$5 and $10` are not
  /// misclassified as math in general chat prose.
  final bool enableDollarLatex;

  /// Whether soft line breaks within paragraphs become hard line breaks.
  final bool softBreakAsHardBreak;

  /// Post-parse inline scanner rules applied to plain text nodes.
  final List<MarkdownInlineRule> inlineRules;

  /// Returns a copy of these options with the given fields replaced.
  MarkdownParserOptions copyWith({
    bool? enableAlerts,
    bool? enableHtml,
    bool? enableFootnotes,
    bool? enableLatex,
    bool? enableDollarLatex,
    bool? softBreakAsHardBreak,
    List<MarkdownInlineRule>? inlineRules,
  }) {
    return MarkdownParserOptions(
      enableAlerts: enableAlerts ?? this.enableAlerts,
      enableHtml: enableHtml ?? this.enableHtml,
      enableFootnotes: enableFootnotes ?? this.enableFootnotes,
      enableLatex: enableLatex ?? this.enableLatex,
      enableDollarLatex: enableDollarLatex ?? this.enableDollarLatex,
      softBreakAsHardBreak: softBreakAsHardBreak ?? this.softBreakAsHardBreak,
      inlineRules: inlineRules ?? this.inlineRules,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MarkdownParserOptions ||
        other.enableAlerts != enableAlerts ||
        other.enableHtml != enableHtml ||
        other.enableFootnotes != enableFootnotes ||
        other.enableLatex != enableLatex ||
        other.enableDollarLatex != enableDollarLatex ||
        other.softBreakAsHardBreak != softBreakAsHardBreak ||
        other.inlineRules.length != inlineRules.length) {
      return false;
    }
    for (var i = 0; i < inlineRules.length; i++) {
      if (other.inlineRules[i] != inlineRules[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    enableAlerts,
    enableHtml,
    enableFootnotes,
    enableLatex,
    enableDollarLatex,
    softBreakAsHardBreak,
    Object.hashAll(inlineRules),
  );
}

/// Pluggable Markdown parser contract producing an immutable [MarkdownDocument].
abstract interface class MarkdownParser {
  /// Parses [markdown] into a [MarkdownDocument].
  ///
  /// When [isStreaming] is `true`, incomplete trailing constructs (such as
  /// partial code fences) are guarded against flicker and block-level caching
  /// avoids re-parsing completed prefix chunks.
  MarkdownDocument parse(String markdown, {bool isStreaming = false});
}

/// Bounded O(1) least-recently-used cache backed by [LinkedHashMap].
class BoundedLruCache<K, V> {
  /// Creates a cache holding at most [maxEntries] entries.
  BoundedLruCache({this.maxEntries = 256}) : assert(maxEntries >= 0);

  /// Maximum number of entries kept. `0` turns the cache off.
  final int maxEntries;
  final LinkedHashMap<K, V> _entries = LinkedHashMap<K, V>();

  /// Number of entries currently stored.
  int get length => _entries.length;

  /// Whether [key] is stored. Does not count as a use of the entry.
  bool containsKey(K key) => _entries.containsKey(key);

  /// Returns the value stored for [key] and marks it as most recently used, or
  /// returns null when there is none.
  V? get(K key) {
    if (maxEntries == 0) return null;
    final value = _entries.remove(key);
    if (value != null) {
      _entries[key] = value;
    }
    return value;
  }

  /// Stores [value] for [key] as the most recently used entry, evicting the
  /// least recently used entries beyond [maxEntries].
  void put(K key, V value) {
    if (maxEntries == 0) return;
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Removes every entry.
  void clear() => _entries.clear();
}
