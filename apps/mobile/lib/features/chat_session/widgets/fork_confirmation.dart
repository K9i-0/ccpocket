import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Confirms branching the conversation into a new session.
Future<bool> confirmForkConversation(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l.forkConversationTitle),
        content: Text(l.forkConversationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('fork_confirm_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.fork),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}
