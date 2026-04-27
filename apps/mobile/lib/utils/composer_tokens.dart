import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

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

  const ComposerTokenConfig({
    required this.provider,
    this.slashCommands = const {},
    this.skillTokens = const {},
    this.appTokens = const {},
    this.pluginTokens = const {},
    this.fileMentions = const {},
  });

  bool allowsTrigger(String trigger) {
    return switch (trigger) {
      '/' || '@' => true,
      r'$' => provider == Provider.codex,
      _ => false,
    };
  }

  @override
  bool operator ==(Object other) {
    const equality = SetEquality<String>();
    return identical(this, other) ||
        other is ComposerTokenConfig &&
            other.provider == provider &&
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
    final surface = cs.surfaceContainerHigh;
    const fileTint = Color(0xFF4C9BFF);
    const purpleTint = Color(0xFFA06BFF);
    return ComposerTokenPalette(
      slashForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      slashBackground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.14),
        surface,
      ),
      fileForeground: Color.alphaBlend(
        fileTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      fileBackground: Color.alphaBlend(
        fileTint.withValues(alpha: 0.14),
        surface,
      ),
      skillForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      skillBackground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.14),
        surface,
      ),
      appForeground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.42),
        cs.onSurfaceVariant,
      ),
      appBackground: Color.alphaBlend(
        purpleTint.withValues(alpha: 0.14),
        surface,
      ),
    );
  }

  TextStyle styleFor(TextStyle baseStyle, ComposerTokenCategory category) {
    final (foreground, background) = switch (category) {
      ComposerTokenCategory.slashCommand => (slashForeground, slashBackground),
      ComposerTokenCategory.fileMention => (fileForeground, fileBackground),
      ComposerTokenCategory.skill => (skillForeground, skillBackground),
      ComposerTokenCategory.app => (appForeground, appBackground),
      ComposerTokenCategory.plugin => (appForeground, appBackground),
    };
    return baseStyle.copyWith(
      color: foreground,
      backgroundColor: background,
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

  void updateTokenState({
    required ComposerTokenConfig config,
    required ComposerTokenPalette palette,
  }) {
    if (_config == config && _palette == palette) {
      return;
    }
    _config = config;
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
      return TextSpan(style: baseStyle, text: text);
    }

    final composingRange =
        withComposing && value.composing.isValid && !value.composing.isCollapsed
        ? TextRange(
            start: value.composing.start.clamp(0, text.length),
            end: value.composing.end.clamp(0, text.length),
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
          ),
        );
      }
      children.addAll(
        _buildSegmentSpans(
          text: text,
          start: token.start,
          end: token.end,
          style: _palette!.styleFor(baseStyle, token.category),
          composingRange: composingRange,
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
  required TextRange? composingRange,
}) {
  if (start >= end) return const [];

  if (composingRange == null ||
      composingRange.isCollapsed ||
      end <= composingRange.start ||
      start >= composingRange.end) {
    return [TextSpan(text: text.substring(start, end), style: style)];
  }

  final spans = <TextSpan>[];
  if (start < composingRange.start) {
    spans.add(
      TextSpan(text: text.substring(start, composingRange.start), style: style),
    );
  }

  final composingStart = start > composingRange.start
      ? start
      : composingRange.start;
  final composingEnd = end < composingRange.end ? end : composingRange.end;
  spans.add(
    TextSpan(
      text: text.substring(composingStart, composingEnd),
      style: style.merge(const TextStyle(decoration: TextDecoration.underline)),
    ),
  );

  if (composingEnd < end) {
    spans.add(TextSpan(text: text.substring(composingEnd, end), style: style));
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
      config.provider == Provider.codex
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
