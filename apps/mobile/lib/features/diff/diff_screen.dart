import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'state/diff_view_notifier.dart';
import 'state/diff_view_state.dart';
import 'widgets/diff_content_list.dart';
import 'widgets/diff_empty_state.dart';
import 'widgets/diff_error_state.dart';
import 'widgets/diff_stats_badge.dart';

/// Dedicated screen for viewing unified diffs.
///
/// Two modes:
/// - **Individual diff**: Pass [initialDiff] with raw diff text (from tool_result).
/// - **Session-wide diff**: Pass [projectPath] to request `git diff` from Bridge.
class DiffScreen extends ConsumerWidget {
  /// Raw diff text for immediate display (individual tool result).
  final String? initialDiff;

  /// Project path — triggers `git diff` request on init.
  final String? projectPath;

  /// Display title (e.g. file path for individual diff).
  final String? title;

  const DiffScreen({super.key, this.initialDiff, this.projectPath, this.title});

  DiffViewNotifierProvider get _provider => diffViewNotifierProvider(
    initialDiff: initialDiff,
    projectPath: projectPath,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);
    final appColors = Theme.of(context).extension<AppColors>()!;

    final screenTitle =
        title ??
        (state.files.length == 1 ? state.files.first.filePath : 'Changes');

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (state.files.length > 1)
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter files',
              onPressed: () =>
                  _showFilterBottomSheet(context, appColors, state, notifier),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? DiffErrorState(error: state.error!)
          : state.files.isEmpty
          ? const DiffEmptyState()
          : DiffContentList(
              files: state.files,
              hiddenFileIndices: state.hiddenFileIndices,
              collapsedFileIndices: state.collapsedFileIndices,
              onToggleCollapse: notifier.toggleCollapse,
              onClearHidden: notifier.clearHidden,
            ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    AppColors appColors,
    DiffViewState currentState,
    DiffViewNotifier notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        // Use Consumer to reactively rebuild when hidden indices change.
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(_provider);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                    child: Row(
                      children: [
                        Text(
                          'Filter Files',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appColors.toolResultTextExpanded,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: notifier.clearHidden,
                          child: const Text('All'),
                        ),
                        TextButton(
                          onPressed: () => notifier.setHiddenFiles(
                            Set<int>.from(
                              List.generate(state.files.length, (i) => i),
                            ),
                          ),
                          child: const Text('None'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: state.files.length,
                      itemBuilder: (context, index) {
                        final file = state.files[index];
                        final visible = !state.hiddenFileIndices.contains(
                          index,
                        );
                        return CheckboxListTile(
                          value: visible,
                          onChanged: (_) =>
                              notifier.toggleFileVisibility(index),
                          title: Text(
                            file.filePath,
                            style: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: DiffStatsBadge(file: file),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
