import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../media_feedback_scope.dart';
import '../state/media_feedback_cubit.dart';
import '../state/media_feedback_state.dart';

class MediaFeedbackEditor extends StatefulWidget {
  final MediaFeedbackBinding binding;
  final FeedbackMedia media;
  final Duration Function()? position;
  final VoidCallback? onPause;
  final ValueChanged<Duration>? onSeek;
  const MediaFeedbackEditor({
    super.key,
    required this.binding,
    required this.media,
    this.position,
    this.onPause,
    this.onSeek,
  });
  @override
  State<MediaFeedbackEditor> createState() => _MediaFeedbackEditorState();
}

class _MediaFeedbackEditorState extends State<MediaFeedbackEditor> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  String? _editingId;
  int? _positionMs;
  static int _sequence = 0;

  List<MediaFeedback> get _entries =>
      widget.binding.cubit
          .items(widget.binding.sessionId)
          .where((e) => e.media.key == widget.media.key)
          .toList()
        ..sort((a, b) => (a.positionMs ?? -1).compareTo(b.positionMs ?? -1));

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(MediaFeedbackEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.key != widget.media.key ||
        oldWidget.binding.cubit != widget.binding.cubit ||
        oldWidget.binding.cubit.resolveSession(oldWidget.binding.sessionId) !=
            widget.binding.cubit.resolveSession(widget.binding.sessionId)) {
      _restore();
    }
  }

  void _restore() {
    _text.clear();
    _editingId = null;
    _positionMs = null;
    if (!widget.media.isVideo) {
      _editingId = 'image:${widget.media.key}';
      _text.text =
          _entries.where((e) => e.id == _editingId).firstOrNull?.text ?? '';
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save(String text) {
    _editingId ??=
        'comment:${DateTime.now().microsecondsSinceEpoch}:${_sequence++}';
    final original = _entries.where((e) => e.id == _editingId).firstOrNull;
    widget.binding.cubit.put(
      widget.binding.sessionId,
      MediaFeedback(
        id: _editingId!,
        // Editing text does not implicitly accept a changed source version.
        media: original?.media ?? widget.media,
        text: text,
        positionMs: _positionMs,
      ),
    );
  }

  void _begin() {
    widget.onPause?.call();
    setState(() {
      _editingId = null;
      _text.clear();
      _positionMs = widget.position?.call().inMilliseconds;
    });
    _focus.requestFocus();
  }

  void _edit(MediaFeedback entry) {
    widget.onPause?.call();
    setState(() {
      _editingId = entry.id;
      _positionMs = entry.positionMs;
      _text.text = entry.text;
    });
    _focus.requestFocus();
  }

  void _remove(MediaFeedback entry) {
    widget.binding.cubit.remove(widget.binding.sessionId, entry.id);
    if (_editingId == entry.id) {
      setState(() {
        _editingId = null;
        _positionMs = null;
        _text.clear();
      });
    }
  }

  void _finish() {
    _focus.unfocus();
    if (widget.media.isVideo) {
      setState(() {
        _editingId = null;
        _positionMs = null;
        _text.clear();
      });
    }
  }

  void _clearPosition() {
    setState(() => _positionMs = null);
    _save(_text.text);
  }

  void _acceptSource() {
    for (final entry in _entries) {
      widget.binding.cubit.put(
        widget.binding.sessionId,
        entry.copyWith(media: widget.media),
      );
    }
  }

  void _syncEditor(BuildContext context, MediaFeedbackState state) {
    if (_editingId == null) return;
    final entry = _entries.where((e) => e.id == _editingId).firstOrNull;
    if (entry == null && _text.text.isNotEmpty) {
      setState(() {
        _text.clear();
        _positionMs = null;
        if (widget.media.isVideo) _editingId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: BlocConsumer<MediaFeedbackCubit, MediaFeedbackState>(
          bloc: widget.binding.cubit,
          listener: _syncEditor,
          builder: (context, state) {
            final entries = _entries;
            final changedSource = entries.any(
              (entry) =>
                  entry.media.modifiedAt != null &&
                  widget.media.modifiedAt != null &&
                  entry.media.modifiedAt != widget.media.modifiedAt,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (changedSource)
                  _ChangedSourceNotice(onAccept: _acceptSource),
                if (widget.media.isVideo)
                  _VideoFeedbackComments(
                    entries: entries,
                    onBegin: _begin,
                    onEdit: _edit,
                    onRemove: _remove,
                    onSeek: widget.onSeek,
                  ),
                _FeedbackComposer(
                  controller: _text,
                  focusNode: _focus,
                  isVideo: widget.media.isVideo,
                  positionMs: _positionMs,
                  onChanged: _save,
                  onDone: _finish,
                  onClearPosition: _clearPosition,
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ChangedSourceNotice extends StatelessWidget {
  final VoidCallback onAccept;
  const _ChangedSourceNotice({required this.onAccept});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l.mediaFeedbackSourceChanged),
        TextButton(
          key: const ValueKey('media_feedback_accept_source_button'),
          onPressed: onAccept,
          child: Text(l.mediaFeedbackConfirmSource),
        ),
      ],
    );
  }
}

class _VideoFeedbackComments extends StatelessWidget {
  final List<MediaFeedback> entries;
  final VoidCallback onBegin;
  final ValueChanged<MediaFeedback> onEdit;
  final ValueChanged<MediaFeedback> onRemove;
  final ValueChanged<Duration>? onSeek;
  const _VideoFeedbackComments({
    required this.entries,
    required this.onBegin,
    required this.onEdit,
    required this.onRemove,
    this.onSeek,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text('${l.mediaFeedbackComments} (${entries.length})'),
            TextButton.icon(
              key: const ValueKey('media_feedback_timestamp_button'),
              onPressed: onBegin,
              icon: const Icon(Icons.add_comment_outlined),
              label: Text(l.mediaFeedbackAtTime),
            ),
          ],
        ),
        if (entries.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .16,
            ),
            child: ListView.builder(
              key: const ValueKey('media_feedback_comments_list'),
              primary: false,
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (context, index) => _FeedbackCommentTile(
                entry: entries[index],
                onEdit: onEdit,
                onRemove: onRemove,
                onSeek: onSeek,
              ),
            ),
          ),
      ],
    );
  }
}

class _FeedbackCommentTile extends StatelessWidget {
  final MediaFeedback entry;
  final ValueChanged<MediaFeedback> onEdit;
  final ValueChanged<MediaFeedback> onRemove;
  final ValueChanged<Duration>? onSeek;
  const _FeedbackCommentTile({
    required this.entry,
    required this.onEdit,
    required this.onRemove,
    this.onSeek,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      key: ValueKey('media_feedback_comment_${entry.id}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: TextButton(
        key: ValueKey('media_feedback_seek_${entry.id}_button'),
        onPressed: entry.positionMs == null
            ? null
            : () => onSeek?.call(Duration(milliseconds: entry.positionMs!)),
        child: Text(
          entry.positionMs == null
              ? l.mediaFeedbackWhole
              : feedbackTimestamp(entry.positionMs!),
        ),
      ),
      title: Text(entry.text, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: () => onEdit(entry),
      trailing: IconButton(
        key: ValueKey('media_feedback_delete_${entry.id}_button'),
        tooltip: l.delete,
        icon: const Icon(Icons.close),
        onPressed: () => onRemove(entry),
      ),
    );
  }
}

class _FeedbackComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isVideo;
  final int? positionMs;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;
  final VoidCallback onClearPosition;
  const _FeedbackComposer({
    required this.controller,
    required this.focusNode,
    required this.isVideo,
    required this.positionMs,
    required this.onChanged,
    required this.onDone,
    required this.onClearPosition,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (positionMs != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InputChip(
                  key: const ValueKey('media_feedback_time_chip'),
                  label: Text(feedbackTimestamp(positionMs!)),
                  onDeleted: onClearPosition,
                ),
              ),
            Expanded(
              child: TextField(
                key: const ValueKey('media_feedback_input'),
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 3,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: isVideo
                      ? l.mediaFeedbackVideoHint
                      : l.mediaFeedbackImageHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('media_feedback_done_button'),
              tooltip: l.mediaFeedbackDone,
              icon: const Icon(Icons.check),
              onPressed: onDone,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.mediaFeedbackSendHint,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      ],
    );
  }
}
