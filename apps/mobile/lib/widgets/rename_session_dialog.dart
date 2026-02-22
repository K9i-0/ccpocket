import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shows a dialog to rename a session. Returns the new name, empty string
/// to clear the name, or null if cancelled.
Future<String?> showRenameSessionDialog(
  BuildContext context, {
  String? currentName,
}) async {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController(text: currentName ?? '');
  // Select all text for easy replacement
  controller.selection = TextSelection(
    baseOffset: 0,
    extentOffset: controller.text.length,
  );

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.renameSession),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: l.sessionNameHint,
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, size: 18),
            tooltip: l.clearName,
            onPressed: () => controller.clear(),
          ),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(l.save),
        ),
      ],
    ),
  );
}
