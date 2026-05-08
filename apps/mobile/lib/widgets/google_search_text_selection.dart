import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';

bool get _isMacOSNative =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get googleSearchSelectionMenuEnabled => _isMacOSNative;

Widget googleSearchSelectableTextContextMenuBuilder(
  BuildContext context,
  EditableTextState editableTextState,
) {
  if (!_isMacOSNative) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  final selectedText = editableTextState.textEditingValue.selection
      .textInside(editableTextState.textEditingValue.text)
      .trim();
  final items = _withGoogleSearchItem(
    context: context,
    items: editableTextState.contextMenuButtonItems,
    selectedText: selectedText,
    hideToolbar: editableTextState.hideToolbar,
  );

  return AdaptiveTextSelectionToolbar.buttonItems(
    buttonItems: items,
    anchors: editableTextState.contextMenuAnchors,
  );
}

class GoogleSearchSelectionArea extends StatefulWidget {
  final Widget child;

  const GoogleSearchSelectionArea({super.key, required this.child});

  @override
  State<GoogleSearchSelectionArea> createState() =>
      _GoogleSearchSelectionAreaState();
}

class _GoogleSearchSelectionAreaState extends State<GoogleSearchSelectionArea> {
  String? _selectedText;

  @override
  Widget build(BuildContext context) {
    if (!_isMacOSNative) return widget.child;

    return SelectionArea(
      onSelectionChanged: (content) {
        _selectedText = content?.plainText;
      },
      contextMenuBuilder: (context, selectableRegionState) {
        final items = _withGoogleSearchItem(
          context: context,
          items: selectableRegionState.contextMenuButtonItems,
          selectedText: _selectedText?.trim() ?? '',
          hideToolbar: selectableRegionState.hideToolbar,
        );
        return AdaptiveTextSelectionToolbar.buttonItems(
          buttonItems: items,
          anchors: selectableRegionState.contextMenuAnchors,
        );
      },
      child: widget.child,
    );
  }
}

List<ContextMenuButtonItem> _withGoogleSearchItem({
  required BuildContext context,
  required List<ContextMenuButtonItem> items,
  required String selectedText,
  required VoidCallback hideToolbar,
}) {
  final result = List<ContextMenuButtonItem>.of(items);
  if (selectedText.isEmpty) return result;

  final insertIndex = result.indexWhere(
    (item) => item.type == ContextMenuButtonType.selectAll,
  );
  final searchItem = ContextMenuButtonItem(
    label: _searchWithGoogleLabel(context),
    onPressed: () {
      hideToolbar();
      unawaited(_openGoogleSearch(selectedText));
    },
  );

  if (insertIndex == -1) {
    result.add(searchItem);
  } else {
    result.insert(insertIndex, searchItem);
  }
  return result;
}

String _searchWithGoogleLabel(BuildContext context) {
  return AppLocalizations.of(context).googleSearchSelectionAction;
}

Future<void> _openGoogleSearch(String selectedText) async {
  final query = selectedText.trim();
  if (query.isEmpty) return;

  final uri = Uri.https('www.google.com', '/search', {'q': query});
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      logger.error('Failed to open Google search: $uri');
    }
  } catch (error, stackTrace) {
    logger.error('Failed to open Google search', error, stackTrace);
  }
}
