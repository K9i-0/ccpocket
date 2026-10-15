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
  }) = _MediaFeedback;
  factory MediaFeedback.fromJson(Map<String, dynamic> json) =>
      _$MediaFeedbackFromJson(json);
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
  for (final items in groups.values) {
    final media = items.first.media;
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
  return sections.join('\n\n');
}
