import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../features/file_peek/file_path_syntax.dart';
import '../features/file_peek/markdown_link_handler.dart';
import '../l10n/app_localizations.dart';
import '../providers/bridge_cubits.dart';
import '../theme/app_theme.dart';
import '../theme/markdown_style.dart';
import 'google_search_text_selection.dart';
import 'workspace_pane_chrome.dart';
import 'link_hover_underline.dart';

/// Shows a full-screen bottom sheet with the complete plan text.
Future<void> showPlanDetailSheet(
  BuildContext context,
  String planText, {
  FilePathTapCallback? onFileTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: macOSModalBottomSheetConstraints(context),
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _PlanDetailContent(planText: planText, onFileTap: onFileTap),
  );
}

class _PlanDetailContent extends StatelessWidget {
  final String planText;
  final FilePathTapCallback? onFileTap;

  const _PlanDetailContent({required this.planText, this.onFileTap});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final cs = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: appColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Icon(Icons.assignment, size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Implementation Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                _PlanCopyButton(planText: planText),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          Expanded(
            child: _PlanViewMode(planText: planText, onFileTap: onFileTap),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _PlanCopyButton extends StatefulWidget {
  final String planText;

  const _PlanCopyButton({required this.planText});

  @override
  State<_PlanCopyButton> createState() => _PlanCopyButtonState();
}

class _PlanCopyButtonState extends State<_PlanCopyButton> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.planText));
    HapticFeedback.lightImpact();
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.copied), duration: const Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return IconButton(
      key: const ValueKey('plan_detail_copy_button'),
      icon: Icon(_copied ? Icons.check : Icons.copy_outlined, size: 18),
      color: _copied ? Theme.of(context).colorScheme.primary : null,
      tooltip: _copied ? (l?.copied ?? 'Copied') : (l?.copy ?? 'Copy'),
      onPressed: _copy,
    );
  }
}

class _PlanViewMode extends StatelessWidget {
  final String planText;
  final FilePathTapCallback? onFileTap;

  const _PlanViewMode({required this.planText, this.onFileTap});

  @override
  Widget build(BuildContext context) {
    final fileSuffixes = onFileTap != null
        ? FilePathSyntax.cachedSuffixSet(context.watch<FileListCubit>().state)
        : const <String>{};
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GoogleSearchSelectionArea(
        child: LinkHoverUnderline(
          child: MarkdownBody(
            data: planText,
            selectable: false,
            styleSheet: buildMarkdownStyle(context),
            onTapLink: buildChatMarkdownLinkHandler(
              context,
              onFileTap: onFileTap,
              knownPathSuffixes: fileSuffixes,
            ),
            inlineSyntaxes: [
              if (onFileTap != null) ...[
                FilePathSyntax(knownPathSuffixes: fileSuffixes),
                BareFilePathSyntax(knownPathSuffixes: fileSuffixes),
              ],
              ...colorCodeInlineSyntaxes,
              ...localhostAutolinkInlineSyntaxes,
            ],
            builders: {
              if (onFileTap != null)
                'filePath': FilePathBuilder(onTap: onFileTap),
              ...markdownBuilders,
            },
          ),
        ),
      ),
    );
  }
}
