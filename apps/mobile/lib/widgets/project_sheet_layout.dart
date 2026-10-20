import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shared bounded layout for project creation, management, and editing.
class ProjectSheetLayout extends StatelessWidget {
  const ProjectSheetLayout({
    super.key,
    required this.title,
    required this.children,
    required this.footer,
    this.canClose = true,
  });

  final String title;
  final List<Widget> children;
  final Widget footer;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          top: false,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (keyboard > 0)
                        IconButton(
                          key: const ValueKey('project_sheet_keyboard_button'),
                          tooltip: AppLocalizations.of(context).dismissKeyboard,
                          onPressed: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          icon: const Icon(Icons.keyboard_hide),
                        ),
                      IconButton(
                        key: const ValueKey('project_sheet_close_button'),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                        onPressed: canClose
                            ? () => Navigator.pop(context)
                            : null,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('project_sheet_scroll'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(width: double.infinity, child: footer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
