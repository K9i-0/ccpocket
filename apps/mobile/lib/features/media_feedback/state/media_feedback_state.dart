import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_feedback_state.freezed.dart';
part 'media_feedback_state.g.dart';

/// Stable identity and the information needed to reopen or send a media item.
@freezed
abstract class FeedbackMedia with _$FeedbackMedia {
  const factory FeedbackMedia({
    required String key,
    required String label,
    @Default(false) bool isVideo,

    /// A changed file in the Git diff. Code comments carry a [CodeAnchor].
    @Default(false) bool isCode,
    String? path,
    String? projectPath,
    String? url,
    String? base64,
    @Default('image/png') String mimeType,
    int? modifiedAt,
  }) = _FeedbackMedia;
  factory FeedbackMedia.fromJson(Map<String, dynamic> json) =>
      _$FeedbackMediaFromJson(json);
}

@freezed
abstract class MediaFeedback with _$MediaFeedback {
  const factory MediaFeedback({
    required String id,
    required FeedbackMedia media,
    required String text,
    int? positionMs,
    CodeAnchor? code,
  }) = _MediaFeedback;
  factory MediaFeedback.fromJson(Map<String, dynamic> json) =>
      _$MediaFeedbackFromJson(json);
}

enum DiffSource { working, staged }

enum DiffSide { newSide, oldSide }

/// Where a code comment was made. Indices into the diff are never persisted
/// because they change on every refresh, stage, and edit; [excerpt] is used to
/// re-locate the lines and is always sent so the comment remains meaningful.
@freezed
abstract class CodeAnchor with _$CodeAnchor {
  const factory CodeAnchor({
    required DiffSource source,
    required DiffSide side,
    required int startLine,
    required int endLine,
    required int lineCount,
    required String hunkHeader,
    required String excerpt,
  }) = _CodeAnchor;
  factory CodeAnchor.fromJson(Map<String, dynamic> json) =>
      _$CodeAnchorFromJson(json);
}

@freezed
abstract class MediaFeedbackState with _$MediaFeedbackState {
  const factory MediaFeedbackState({
    @Default({}) Map<String, List<MediaFeedback>> sessions,
  }) = _MediaFeedbackState;
}

String feedbackTimestamp(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Appended once, immediately before sending. Source identity is never inferred
/// from the current page number or from a transient selection in the UI.
String appendMediaFeedback(
  String prompt,
  List<MediaFeedback> feedback, {
  Map<String, int> attachmentIndices = const {},
}) {
  final groups = <String, List<MediaFeedback>>{};
  for (final item in feedback) {
    if (item.text.trim().isEmpty) continue;
    groups.putIfAbsent(item.media.key, () => []).add(item);
  }
  final sections = <String>[if (prompt.isNotEmpty) prompt];
  final codeSections = <String>[];
  for (final items in groups.values) {
    final media = items.first.media;
    if (media.isCode) {
      codeSections.add(_codeSection(media, items));
      continue;
    }
    final target = media.path ?? media.label;
    final lines = <String>[
      '${media.isVideo ? 'Video' : 'Image'}: $target',
      if (media.path != null && media.projectPath != null)
        'Project: ${media.projectPath}',
      if (media.path == null)
        'Reference: ${media.key} (attached image ${attachmentIndices[media.key] ?? '?'})',
      if (media.modifiedAt != null) 'Source modified at: ${media.modifiedAt}',
    ];
    final sorted = [...items]
      ..sort((a, b) => (a.positionMs ?? -1).compareTo(b.positionMs ?? -1));
    for (final item in sorted) {
      lines.add(
        item.positionMs == null
            ? item.text.trim()
            : '- ${feedbackTimestamp(item.positionMs!)} — ${item.text.trim()}',
      );
    }
    sections.add(lines.join('\n'));
  }
  if (codeSections.isNotEmpty) {
    sections.add(['Code review comments:', ...codeSections].join('\n\n'));
  }
  return sections.join('\n\n');
}

String codeLineLabel(CodeAnchor anchor) {
  final range = anchor.startLine == anchor.endLine
      ? 'L${anchor.startLine}'
      : 'L${anchor.startLine}-${anchor.endLine}';
  return anchor.side == DiffSide.oldSide ? '$range (old)' : range;
}

String _codeSection(FeedbackMedia media, List<MediaFeedback> items) {
  final anchored = items.where((e) => e.code != null).toList()
    ..sort((a, b) => a.code!.startLine.compareTo(b.code!.startLine));
  final source = anchored.firstOrNull?.code?.source == DiffSource.staged
      ? 'staged diff'
      : 'working tree diff';
  final lines = <String>[
    'File: ${media.path ?? media.label} ($source)',
    if (media.projectPath != null) 'Project: ${media.projectPath}',
  ];
  String indent(String text) =>
      text.split('\n').map((line) => '  $line').join('\n');
  for (final item in items.where((e) => e.code == null)) {
    lines.add('- ${item.text.trim()}');
  }
  for (final item in anchored) {
    final anchor = item.code!;
    lines
      ..add('- ${codeLineLabel(anchor)}:')
      ..add(indent('```diff\n${anchor.excerpt}\n```'))
      ..add(indent(item.text.trim()));
  }
  return lines.join('\n');
}
