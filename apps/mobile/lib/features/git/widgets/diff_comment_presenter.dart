import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../utils/diff_parser.dart';
import '../../media_feedback/media_feedback_scope.dart';
import '../../media_feedback/state/media_feedback_state.dart';
import '../diff_comments.dart';
import 'diff_comment_widgets.dart';
import 'diff_content_list.dart';

/// The comment currently open in the inline editor. The anchor is kept here
/// (not hunk indices) so the editor follows the lines across refreshes.
@immutable
class DiffCommentEditing {
  final String id;
  final String filePath;
  final CodeAnchor anchor;
  const DiffCommentEditing({
    required this.id,
    required this.filePath,
    required this.anchor,
  });
}

/// Builds diff decorations from the session's comment drafts. Created per
/// build; holds no state of its own.
class DiffCommentPresenter {
  final MediaFeedbackBinding binding;
  final String projectPath;
  final DiffSource source;
  final List<DiffFile> files;
  final DiffCommentEditing? editing;
  final ValueChanged<DiffCommentEditing?> onEditingChanged;

  DiffCommentPresenter({
    required this.binding,
    required this.projectPath,
    required this.source,
    required this.files,
    required this.editing,
    required this.onEditingChanged,
  });

  static int _sequence = 0;

  static List<MediaFeedback> commentsFor(
    MediaFeedbackBinding binding,
    MediaFeedbackState state,
    String projectPath,
    DiffSource source,
  ) =>
      (state.sessions[binding.cubit.resolveSession(binding.sessionId)] ??
              const <MediaFeedback>[])
          .where(
            (e) =>
                e.media.isCode &&
                e.media.projectPath == projectPath &&
                e.code?.source == source,
          )
          .toList();

  /// Whether the diff needs rebuilding. Typing in the open editor only changes
  /// that entry's text, which must not re-lay out the diff on every keystroke.
  static bool needsRebuild(
    MediaFeedbackBinding binding,
    MediaFeedbackState previous,
    MediaFeedbackState next,
    String projectPath,
    DiffSource source,
    String? editingId,
  ) {
    (List<MediaFeedback>, bool) signature(MediaFeedbackState state) {
      final comments = commentsFor(binding, state, projectPath, source);
      return (
        comments.where((e) => e.id != editingId).toList(),
        comments.any((e) => e.id == editingId),
      );
    }

    final (previousList, previousExists) = signature(previous);
    final (nextList, nextExists) = signature(next);
    return previousExists != nextExists || !listEquals(previousList, nextList);
  }

  late final List<MediaFeedback> _comments = commentsFor(
    binding,
    binding.cubit.state,
    projectPath,
    source,
  );
  final Map<int, FileCodeComments> _layouts = {};

  FileCodeComments _layout(int fileIdx) =>
      _layouts[fileIdx] ??= layoutCodeComments(
        files[fileIdx],
        _comments.where((e) => e.media.path == files[fileIdx].filePath),
      );

  /// Read live: the entry may have been saved after this presenter was built.
  MediaFeedback? get _editingEntry => binding.cubit
      .items(binding.sessionId)
      .where((e) => e.id == editing?.id)
      .firstOrNull;

  CodePlacement? _editingPlacement(int fileIdx) {
    final current = editing;
    if (current == null || current.filePath != files[fileIdx].filePath) {
      return null;
    }
    return locateCodeAnchor(files[fileIdx], current.anchor);
  }

  void begin(int fileIdx, int hunkIdx, int first, int last) {
    final file = files[fileIdx];
    onEditingChanged(
      DiffCommentEditing(
        id: 'code:${DateTime.now().microsecondsSinceEpoch}:${_sequence++}',
        filePath: file.filePath,
        anchor: anchorForLines(file.hunks[hunkIdx], first, last, source),
      ),
    );
  }

  void _tapLine(int fileIdx, int hunkIdx, int lineIdx) {
    final current = editing;
    final placement = _editingPlacement(fileIdx);
    if (current == null || placement == null || placement.hunkIdx != hunkIdx) {
      begin(fileIdx, hunkIdx, lineIdx, lineIdx);
      return;
    }
    if (placement.start == lineIdx && placement.end == lineIdx) {
      // Tapping the only selected line again cancels an empty comment.
      if (_editingEntry == null) onEditingChanged(null);
      return;
    }
    // Extend or shrink the open comment within the same hunk.
    final anchor = anchorForLines(
      files[fileIdx].hunks[hunkIdx],
      placement.start,
      lineIdx,
      source,
    );
    final entry = _editingEntry;
    if (entry != null) {
      binding.cubit.put(binding.sessionId, entry.copyWith(code: anchor));
    }
    onEditingChanged(
      DiffCommentEditing(
        id: current.id,
        filePath: current.filePath,
        anchor: anchor,
      ),
    );
  }

  void _save(DiffCommentEditing current, String text) {
    binding.cubit.put(
      binding.sessionId,
      MediaFeedback(
        id: current.id,
        media: codeFeedbackMedia(
          projectPath: projectPath,
          filePath: current.filePath,
          source: source,
        ),
        text: text,
        code: current.anchor,
      ),
    );
  }

  void _remove(String id) {
    binding.cubit.remove(binding.sessionId, id);
    if (editing?.id == id) onEditingChanged(null);
  }

  Widget _editor(DiffCommentEditing current) => DiffCommentEditor(
    key: ValueKey('diff_comment_editor_${current.id}'),
    initialText: _editingEntry?.text ?? '',
    anchor: current.anchor,
    onChanged: (text) => _save(current, text),
    onDone: () => onEditingChanged(null),
    onDelete: _editingEntry == null ? null : () => _remove(current.id),
  );

  Widget _card(MediaFeedback comment, DiffFile file, {bool outdated = false}) {
    final placement = outdated ? null : locateCodeAnchor(file, comment.code!);
    return DiffCommentCard(
      comment: comment,
      showExcerpt: outdated,
      currentAnchor: placement == null
          ? null
          : anchorForLines(
              file.hunks[placement.hunkIdx],
              placement.start,
              placement.end,
              source,
            ),
      onEdit: () => onEditingChanged(
        DiffCommentEditing(
          id: comment.id,
          filePath: file.filePath,
          anchor: comment.code!,
        ),
      ),
      onDelete: () => _remove(comment.id),
    );
  }

  DiffHunkComments hunkComments(int fileIdx, int hunkIdx) {
    final file = files[fileIdx];
    final placement = _editingPlacement(fileIdx);
    final editingHere = placement?.hunkIdx == hunkIdx;
    final below = <int, List<Widget>>{};
    for (final MapEntry(key: line, value: comments)
        in (_layout(fileIdx).placed[hunkIdx] ?? const {}).entries) {
      for (final comment in comments) {
        if (comment.id == editing?.id) continue;
        below.putIfAbsent(line, () => []).add(_card(comment, file));
      }
    }
    if (editingHere) {
      below.putIfAbsent(placement!.end, () => []).add(_editor(editing!));
    }
    return (
      onTapLine: (line) => _tapLine(fileIdx, hunkIdx, line),
      selectedLines: editingHere
          ? {for (var i = placement!.start; i <= placement.end; i++) i}
          : const {},
      belowLines: below,
    );
  }

  Widget? fileComments(int fileIdx) {
    final file = files[fileIdx];
    final outdated = _layout(fileIdx).outdated;
    if (outdated.isEmpty) return null;
    return DiffOutdatedComments(
      children: [
        for (final comment in outdated)
          comment.id == editing?.id
              ? _editor(editing!)
              : _card(comment, file, outdated: true),
      ],
    );
  }
}
