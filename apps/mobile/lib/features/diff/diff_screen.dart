import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/bridge_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import 'state/diff_view_cubit.dart';
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
///
/// Returns a [String] (reconstructed diff) via [Navigator.pop] when the user
/// selects hunks and taps the send-to-chat FAB.
class DiffScreen extends StatelessWidget {
  /// Raw diff text for immediate display (individual tool result).
  final String? initialDiff;

  /// Project path — triggers `git diff` request on init.
  final String? projectPath;

  /// Display title (e.g. file path for individual diff).
  final String? title;

  const DiffScreen({super.key, this.initialDiff, this.projectPath, this.title});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => DiffViewCubit(
        bridge: ctx.read<BridgeService>(),
        initialDiff: initialDiff,
        projectPath: projectPath,
      ),
      child: _DiffScreenBody(title: title),
    );
  }
}

class _DiffScreenBody extends StatelessWidget {
  final String? title;

  const _DiffScreenBody({this.title});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DiffViewCubit>().state;
    final cubit = context.read<DiffViewCubit>();
    final appColors = Theme.of(context).extension<AppColors>()!;

    final screenTitle =
        title ??
        (state.files.length == 1 ? state.files.first.filePath : 'Changes');

    return Scaffold(
      appBar: AppBar(
        title: Text(screenTitle, overflow: TextOverflow.ellipsis),
        actions: [
          // Selection mode toggle
          if (state.files.isNotEmpty)
            IconButton(
              icon: Icon(
                state.selectionMode
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
              ),
              tooltip: state.selectionMode ? 'Cancel selection' : 'Select',
              onPressed: cubit.toggleSelectionMode,
            ),
          // Filter (hidden during selection mode)
          if (state.files.length > 1 && !state.selectionMode)
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter files',
              onPressed: () =>
                  _showFilterBottomSheet(context, appColors, cubit),
            ),
        ],
      ),
      floatingActionButton: state.selectionMode && cubit.hasAnySelection
          ? FloatingActionButton.extended(
              key: const ValueKey('send_to_chat_fab'),
              onPressed: () {
                final diffText = reconstructDiff(
                  state.files,
                  state.selectedHunkKeys,
                );
                Navigator.pop<String>(context, diffText);
              },
              icon: const Icon(Icons.send),
              label: Text('Send (${state.selectedHunkKeys.length})'),
            )
          : null,
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
              onToggleCollapse: cubit.toggleCollapse,
              onClearHidden: cubit.clearHidden,
              selectionMode: state.selectionMode,
              selectedHunkKeys: state.selectedHunkKeys,
              onToggleFileSelection: cubit.toggleFileSelection,
              onToggleHunkSelection: cubit.toggleHunkSelection,
              isFileFullySelected: cubit.isFileFullySelected,
              isFilePartiallySelected: cubit.isFilePartiallySelected,
            ),
    );
  }

  void _showFilterBottomSheet(
    BuildContext context,
    AppColors appColors,
    DiffViewCubit cubit,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return BlocBuilder<DiffViewCubit, DiffViewState>(
          bloc: cubit,
          builder: (context, state) {
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
                          onPressed: cubit.clearHidden,
                          child: const Text('All'),
                        ),
                        TextButton(
                          onPressed: () => cubit.setHiddenFiles(
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
                          onChanged: (_) => cubit.toggleFileVisibility(index),
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
