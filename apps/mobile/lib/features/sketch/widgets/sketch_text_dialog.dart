import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class SketchTextDialog extends StatefulWidget {
  const SketchTextDialog({super.key, this.initialText = ''});

  final String initialText;

  @override
  State<SketchTextDialog> createState() => _SketchTextDialogState();
}

class _SketchTextDialogState extends State<SketchTextDialog> {
  late final _controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sketchText),
      content: TextField(
        key: const ValueKey('sketch_text_field'),
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        maxLength: 1000,
        decoration: InputDecoration(hintText: l10n.sketchTextHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.sketchCancel),
        ),
        TextButton(
          key: const ValueKey('sketch_text_confirm_button'),
          onPressed: _submit,
          child: Text(l10n.sketchAddText),
        ),
      ],
    );
  }
}
