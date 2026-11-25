import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import '../utils/platform_helper.dart';

bool get _isMacOSNative => isMacOSPlatform;

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

/// A [SelectionArea] for read-only message text on every platform.
///
/// Wrapping plain (non-selectable) text in one selection area keeps it
/// selectable and copyable without building an [EditableText] per paragraph,
/// which is what `MarkdownBody(selectable: true)` does and which made long
/// messages slow to build and lay out.
///
/// On native macOS the context menu also offers a Google search of the
/// selection; other platforms keep their default selection toolbar.
class GoogleSearchSelectionArea extends StatefulWidget {
  final Widget child;
  final ValueChanged<SelectedContent?>? onSelectionChanged;

  const GoogleSearchSelectionArea({
    super.key,
    required this.child,
    this.onSelectionChanged,
  });

  @override
  State<GoogleSearchSelectionArea> createState() =>
      _GoogleSearchSelectionAreaState();
}

class _GoogleSearchSelectionAreaState extends State<GoogleSearchSelectionArea> {
  String? _selectedText;

  void _handleSelectionChanged(SelectedContent? content) {
    _selectedText = content?.plainText;
    widget.onSelectionChanged?.call(content);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMacOSNative) {
      return SelectionArea(
        onSelectionChanged: widget.onSelectionChanged,
        child: widget.child,
      );
    }

    return SelectionArea(
      onSelectionChanged: _handleSelectionChanged,
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
  return Localizations.of<AppLocalizations>(
        context,
        AppLocalizations,
      )?.googleSearchSelectionAction ??
      'Search with Google';
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
