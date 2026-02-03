import 'package:flutter/material.dart';

import '../../../models/messages.dart';
import '../../../widgets/message_bubble.dart';

class ChatMessageList extends StatelessWidget {
  final GlobalKey<AnimatedListState> listKey;
  final ScrollController scrollController;
  final List<ChatEntry> entries;
  final bool bulkLoading;
  final String? httpBaseUrl;
  final ValueChanged<ChatEntry> onRetryMessage;
  final bool collapseToolResults;

  const ChatMessageList({
    super.key,
    required this.listKey,
    required this.scrollController,
    required this.entries,
    required this.bulkLoading,
    required this.httpBaseUrl,
    required this.onRetryMessage,
    required this.collapseToolResults,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        FocusScope.of(context).unfocus();
        return false;
      },
      child: AnimatedList(
        key: listKey,
        controller: scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        initialItemCount: entries.length,
        itemBuilder: (context, index, animation) {
          final entry = entries[index];
          final previous = index > 0 ? entries[index - 1] : null;
          final child = ChatEntryWidget(
            entry: entry,
            previous: previous,
            httpBaseUrl: httpBaseUrl,
            onRetryMessage: onRetryMessage,
            collapseToolResults: collapseToolResults,
          );
          if (bulkLoading || animation.isCompleted) return child;
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }
}
