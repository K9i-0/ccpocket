import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';

import '../models/messages.dart';

enum ComposerTokenCategory { slashCommand, fileMention, skill, app, plugin }

@immutable
class ComposerToken {
  final int start;
  final int end;
  final String rawText;
  final ComposerTokenCategory category;
  final bool isValid;

  const ComposerToken({
    required this.start,
    required this.end,
    required this.rawText,
    required this.category,
    required this.isValid,
  });
}

@immutable
class ComposerTokenConfig {
  final Provider provider;
  final Set<String> slashCommands;
  final Set<String> skillTokens;
  final Set<String> appTokens;
  final Set<String> pluginTokens;
  final Set<String> fileMentions;

  /// Whether `$` tokens are recognized. Defaults to Codex only; Claude enables
  /// it when the user lets skills be typed as `$name`.
  final bool? dollarTrigger;

  const ComposerTokenConfig({
    required this.provider,
    this.dollarTrigger,
    this.slashCommands = const {},
    this.skillTokens = const {},
    this.appTokens = const {},
    this.pluginTokens = const {},
    this.fileMentions = const {},
  });

  bool get allowsDollarTrigger => dollarTrigger ?? provider == Provider.codex;

  bool allowsTrigger(String trigger) {
    return switch (trigger) {
      '/' || '@' => true,
      r'$' => allowsDollarTrigger,
      _ => false,
    };
  }

  @override
  bool operator ==(Object other) {
    const equality = SetEquality<String>();
    return identical(this, other) ||
        other is ComposerTokenConfig &&
            other.provider == provider &&
            other.allowsDollarTrigger == allowsDollarTrigger &&
            equality.equals(other.slashCommands, slashCommands) &&
            equality.equals(other.skillTokens, skillTokens) &&
            equality.equals(other.appTokens, appTokens) &&
            equality.equals(other.pluginTokens, pluginTokens) &&
            equality.equals(other.fileMentions, fileMentions);
  }

  @override
  int get hashCode {
    const equality = SetEquality<String>();
    return Object.hash(
      provider,
      allowsDollarTrigger,
      equality.hash(slashCommands),
      equality.hash(skillTokens),
      equality.hash(appTokens),
      equality.hash(pluginTokens),
      equality.hash(fileMentions),
    );
  }
}

@immutable
class ComposerTokenPalette {
  final Color slashForeground;
  final Color slashBackground;
  final Color fileForeground;
  final Color fileBackground;
  final Color skillForeground;
  final Color skillBackground;
  final Color appForeground;
  final Color appBackground;

  const ComposerTokenPalette({
    required this.slashForeground,
    required this.slashBackground,
    required this.fileForeground,
    required this.fileBackground,
    required this.skillForeground,
    required this.skillBackground,
    required this.appForeground,
    required this.appBackground,
  });

  factory ComposerTokenPalette.fromTheme(ThemeData theme) {
    final cs = theme.colorScheme;
    const fileTint = Color(0xFF4C9BFF);
    const purpleTint = Color(0xFFA06BFF);
    return ComposerTokenPalette(
      slashForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      slashBackground: purpleTint.withValues(alpha: 0.14),
      fileForeground: Color.alphaBlend(
        fileTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      fileBackground: fileTint.withValues(alpha: 0.14),
      skillForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      skillBackground: purpleTint.withValues(alpha: 0.14),
      appForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      appBackground: purpleTint.withValues(alpha: 0.14),
    );
  }

  TextStyle styleFor(
    TextStyle baseStyle,
    ComposerTokenCategory category, {
    bool includeBackground = true,
  }) {
    final (foreground, background) = switch (category) {
      ComposerTokenCategory.slashCommand => (slashForeground, slashBackground),
      ComposerTokenCategory.fileMention => (fileForeground, fileBackground),
      ComposerTokenCategory.skill => (skillForeground, skillBackground),
      ComposerTokenCategory.app => (appForeground, appBackground),
      ComposerTokenCategory.plugin => (appForeground, appBackground),
    };
    return baseStyle.copyWith(
      color: foreground,
      backgroundColor: includeBackground ? background : null,
      fontWeight: FontWeight.w600,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ComposerTokenPalette &&
            other.slashForeground == slashForeground &&
            other.slashBackground == slashBackground &&
            other.fileForeground == fileForeground &&
            other.fileBackground == fileBackground &&
            other.skillForeground == skillForeground &&
            other.skillBackground == skillBackground &&
            other.appForeground == appForeground &&
            other.appBackground == appBackground;
  }

  @override
  int get hashCode => Object.hash(
    slashForeground,
    slashBackground,
    fileForeground,
    fileBackground,
    skillForeground,
    skillBackground,
    appForeground,
    appBackground,
  );
}

List<ComposerToken> parseComposerTokens(
  String text,
  ComposerTokenConfig config,
) {
  if (text.isEmpty) return const [];

  final tokens = <ComposerToken>[];
  var index = 0;
  while (index < text.length) {
    final char = text[index];
    if (!config.allowsTrigger(char) || !_isTokenBoundary(text, index)) {
      index++;
      continue;
    }

    final end = _findTokenEnd(text, index);
    if (end <= index + 1) {
      index++;
      continue;
    }

    final rawText = text.substring(index, end);
    final category = _resolveCategory(rawText, config);
    if (category == null) {
      index++;
      continue;
    }

    tokens.add(
      ComposerToken(
        start: index,
        end: end,
        rawText: rawText,
        category: category,
        isValid: _isTokenValid(rawText, category, config),
      ),
    );
    index = end;
  }
  return tokens;
}

class ComposerTextEditingController extends TextEditingController {
  ComposerTokenConfig _config = const ComposerTokenConfig(
    provider: Provider.claude,
  );
  ComposerTokenPalette? _palette;
  final Set<String> _browserReferences = {};

  /// Insert an explicit reference while preserving the draft and selection.
  void insertFileReference(String path) {
    final token =
        '@${RegExp(r'[\s"\\]').hasMatch(path) ? jsonEncode(path) : path}';
    _browserReferences.add(token.substring(1));
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final prefix = start > 0 && !RegExp(r'\s').hasMatch(text[start - 1])
        ? ' '
        : '';
    final inserted = '$prefix$token ';
    value = TextEditingValue(
      text: text.replaceRange(start, end, inserted),
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
  }

  void updateTokenState({
    required ComposerTokenConfig config,
    required ComposerTokenPalette palette,
  }) {
    if (_config == config &&
        _palette == palette &&
        _config.fileMentions.containsAll(_browserReferences)) {
      return;
    }
    _config = ComposerTokenConfig(
      provider: config.provider,
      dollarTrigger: config.allowsDollarTrigger,
      slashCommands: config.slashCommands,
      skillTokens: config.skillTokens,
      appTokens: config.appTokens,
      pluginTokens: config.pluginTokens,
      fileMentions: {...config.fileMentions, ..._browserReferences},
    );
    _palette = palette;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    if (_palette == null) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final tokens = parseComposerTokens(
      text,
      _config,
    ).where((token) => token.isValid).toList();
    if (tokens.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final composingRange =
        withComposing && value.composing.isValid && !value.composing.isCollapsed
        ? TextRange(
            start: value.composing.start.clamp(0, text.length),
            end: value.composing.end.clamp(0, text.length),
          )
        : null;
    final selectionRange =
        value.selection.isValid && !value.selection.isCollapsed
        ? TextRange(
            start: value.selection.start.clamp(0, text.length),
            end: value.selection.end.clamp(0, text.length),
          )
        : null;

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final token in tokens) {
      if (cursor < token.start) {
        children.addAll(
          _buildSegmentSpans(
            text: text,
            start: cursor,
            end: token.start,
            style: baseStyle,
            composingRange: composingRange,
            selectionRange: selectionRange,
          ),
        );
      }
      children.addAll(
        _buildSegmentSpans(
          text: text,
          start: token.start,
          end: token.end,
          style: _palette!.styleFor(baseStyle, token.category),
          selectedStyle: _palette!.styleFor(
            baseStyle,
            token.category,
            includeBackground: false,
          ),
          composingRange: composingRange,
          selectionRange: selectionRange,
        ),
      );
      cursor = token.end;
    }
    if (cursor < text.length) {
      children.addAll(
        _buildSegmentSpans(
          text: text,
          start: cursor,
          end: text.length,
          style: baseStyle,
          composingRange: composingRange,
          selectionRange: selectionRange,
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

List<TextSpan> _buildSegmentSpans({
  required String text,
  required int start,
  required int end,
  required TextStyle style,
  TextStyle? selectedStyle,
  required TextRange? composingRange,
  required TextRange? selectionRange,
}) {
  if (start >= end) return const [];

  final boundaries = <int>{start, end};
  if (composingRange != null && !composingRange.isCollapsed) {
    if (composingRange.start > start && composingRange.start < end) {
      boundaries.add(composingRange.start);
    }
    if (composingRange.end > start && composingRange.end < end) {
      boundaries.add(composingRange.end);
    }
  }
  if (selectedStyle != null &&
      selectionRange != null &&
      !selectionRange.isCollapsed) {
    if (selectionRange.start > start && selectionRange.start < end) {
      boundaries.add(selectionRange.start);
    }
    if (selectionRange.end > start && selectionRange.end < end) {
      boundaries.add(selectionRange.end);
    }
  }

  final points = boundaries.toList()..sort();
  final spans = <TextSpan>[];
  for (var i = 0; i < points.length - 1; i++) {
    final segStart = points[i];
    final segEnd = points[i + 1];
    if (segStart >= segEnd) continue;

    final isSelected =
        selectedStyle != null &&
        selectionRange != null &&
        !selectionRange.isCollapsed &&
        segStart >= selectionRange.start &&
        segEnd <= selectionRange.end;
    final isComposing =
        composingRange != null &&
        !composingRange.isCollapsed &&
        segStart >= composingRange.start &&
        segEnd <= composingRange.end;

    var segStyle = isSelected ? selectedStyle : style;
    if (isComposing) {
      segStyle = segStyle.merge(
        const TextStyle(decoration: TextDecoration.underline),
      );
    }
    spans.add(
      TextSpan(text: text.substring(segStart, segEnd), style: segStyle),
    );
  }

  return spans;
}

ComposerTokenCategory? _resolveCategory(
  String rawText,
  ComposerTokenConfig config,
) {
  return switch (rawText[0]) {
    '/' => ComposerTokenCategory.slashCommand,
    '@' =>
      config.pluginTokens.contains(rawText)
          ? ComposerTokenCategory.plugin
          : ComposerTokenCategory.fileMention,
    r'$' =>
      config.allowsDollarTrigger
          ? resolveDollarTokenCategory(rawText, config)
          : null,
    _ => null,
  };
}

bool _isTokenValid(
  String rawText,
  ComposerTokenCategory category,
  ComposerTokenConfig config,
) {
  return switch (category) {
    ComposerTokenCategory.slashCommand => config.slashCommands.contains(
      rawText,
    ),
    ComposerTokenCategory.fileMention => config.fileMentions.contains(
      rawText.substring(1),
    ),
    ComposerTokenCategory.skill => config.skillTokens.contains(rawText),
    ComposerTokenCategory.app => config.appTokens.contains(rawText),
    ComposerTokenCategory.plugin => config.pluginTokens.contains(rawText),
  };
}

int _findTokenEnd(String text, int start) {
  var cursor = start + 1;
  if (text[start] == '@' && cursor < text.length && text[cursor] == '"') {
    cursor++;
    while (cursor < text.length) {
      if (text[cursor] == '\\') {
        cursor += 2;
        continue;
      }
      if (text[cursor] == '"') return cursor + 1;
      cursor++;
    }
    return text.length;
  }
  while (cursor < text.length && !_isWhitespace(text[cursor])) {
    cursor++;
  }
  return cursor;
}

bool _isTokenBoundary(String text, int index) {
  if (index == 0) return true;
  final previous = text[index - 1];
  return _isWhitespace(previous) || RegExp(r'[\(\[\{:,;]').hasMatch(previous);
}

bool _isWhitespace(String value) => RegExp(r'\s').hasMatch(value);

ComposerTokenCategory? resolveDollarTokenCategory(
  String rawText,
  ComposerTokenConfig config,
) {
  if (config.skillTokens.contains(rawText)) return ComposerTokenCategory.skill;
  if (config.appTokens.contains(rawText)) return ComposerTokenCategory.app;
  return null;
}
