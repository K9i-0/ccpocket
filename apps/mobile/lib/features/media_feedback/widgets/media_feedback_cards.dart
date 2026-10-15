import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../../../widgets/bubbles/image_preview.dart';
import '../../file_peek/file_peek_sheet.dart';
import '../media_feedback_scope.dart';
import '../state/media_feedback_state.dart';

class MediaFeedbackCards extends StatelessWidget {
  final MediaFeedbackBinding binding;
  final List<MediaFeedback> entries;
  const MediaFeedbackCards({
    super.key,
    required this.binding,
    required this.entries,
  });

  Future<void> _open(BuildContext context, FeedbackMedia media) async {
    final bridge = context.read<BridgeService>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaFeedbackScope(
          binding: binding,
          child: media.path != null && media.projectPath != null
              ? _FeedbackFilePreview(bridge: bridge, media: media)
              : FullScreenImageViewer(
                  url: media.url,
                  bytes: media.base64 == null
                      ? null
                      : base64Decode(media.base64!),
                  feedback: binding,
                  feedbackMedia: media,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<MediaFeedback>>{};
    for (final entry in entries) {
      groups.putIfAbsent(entry.media.key, () => []).add(entry);
    }
    if (groups.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 70,
      child: ListView(
        key: const ValueKey('media_feedback_cards_list'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: groups.values.map((items) {
          final media = items.first.media;
          return SizedBox(
            width: 240,
            child: Card(
              child: ListTile(
                dense: true,
                leading: Icon(
                  media.isVideo
                      ? Icons.video_file_outlined
                      : Icons.image_outlined,
                ),
                title: Text(
                  media.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${items.length} · ${items.first.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _open(context, media),
                trailing: IconButton(
                  tooltip: AppLocalizations.of(context).delete,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    for (final item in items) {
                      binding.cubit.remove(binding.sessionId, item.id);
                    }
                  },
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FeedbackFilePreview extends StatefulWidget {
  final BridgeService bridge;
  final FeedbackMedia media;
  const _FeedbackFilePreview({required this.bridge, required this.media});
  @override
  State<_FeedbackFilePreview> createState() => _FeedbackFilePreviewState();
}

class _FeedbackFilePreviewState extends State<_FeedbackFilePreview> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.media.label)),
    body: FilePeekContent(
      bridge: widget.bridge,
      projectPath: widget.media.projectPath!,
      filePath: widget.media.path!,
      scrollController: _scroll,
    ),
  );
}
