import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import 'widgets/diff_content_list.dart';
import 'widgets/diff_empty_state.dart';
import 'widgets/diff_error_state.dart';
import 'widgets/diff_stats_badge.dart';

/// Dedicated screen for viewing unified diffs.
///
/// Two modes:
/// - **Individual diff**: Pass [initialDiff] with raw diff text (from tool_result).
/// - **Session-wide diff**: Pass [projectPath] to request `git diff` from Bridge.
class DiffScreen extends ConsumerStatefulWidget {
  /// Raw diff text for immediate display (individual tool result).
  final String? initialDiff;

  /// Project path — triggers `git diff` request on init.
  final String? projectPath;

  /// Display title (e.g. file path for individual diff).
  final String? title;

  const DiffScreen({super.key, this.initialDiff, this.projectPath, this.title});

  @override
  ConsumerState<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends ConsumerState<DiffScreen> {
  List<DiffFile> _diffFiles = [];
  Set<int> _hiddenFileIndices = {};
  Set<int> _collapsedFileIndices = {};
  bool _loading = false;
  String? _error;
  StreamSubscription<DiffResultMessage>? _diffSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialDiff != null) {
      _diffFiles = parseDiff(widget.initialDiff!);
    } else if (widget.projectPath != null) {
      _requestSessionDiff();
    }
  }

  @override
  void dispose() {
    _diffSub?.cancel();
    super.dispose();
  }

  void _requestSessionDiff() {
    setState(() => _loading = true);
    final bridge = ref.read(bridgeServiceProvider);
    _diffSub = bridge.diffResults.listen((result) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (result.error != null) {
          _error = result.error;
        } else if (result.diff.trim().isEmpty) {
          _diffFiles = [];
        } else {
          _diffFiles = parseDiff(result.diff);
        }
      });
    });
    bridge.send(ClientMessage.getDiff(widget.projectPath!));
  }

  String get _screenTitle {
    if (widget.title != null) return widget.title!;
    if (_diffFiles.length == 1) return _diffFiles.first.filePath;
    return 'Changes';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (_diffFiles.length > 1)
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter files',
              onPressed: () => _showFilterBottomSheet(appColors),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? DiffErrorState(error: _error!)
          : _diffFiles.isEmpty
          ? const DiffEmptyState()
          : DiffContentList(
              files: _diffFiles,
              hiddenFileIndices: _hiddenFileIndices,
              collapsedFileIndices: _collapsedFileIndices,
              onToggleCollapse: (fileIdx) {
                setState(() {
                  if (_collapsedFileIndices.contains(fileIdx)) {
                    _collapsedFileIndices.remove(fileIdx);
                  } else {
                    _collapsedFileIndices.add(fileIdx);
                  }
                });
              },
              onClearHidden: () => setState(() => _hiddenFileIndices.clear()),
            ),
    );
  }

  void _showFilterBottomSheet(AppColors appColors) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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
                          onPressed: () {
                            setSheetState(() => _hiddenFileIndices.clear());
                            setState(() {});
                          },
                          child: const Text('All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _hiddenFileIndices = Set<int>.from(
                                List.generate(_diffFiles.length, (i) => i),
                              );
                            });
                            setState(() {});
                          },
                          child: const Text('None'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _diffFiles.length,
                      itemBuilder: (context, index) {
                        final file = _diffFiles[index];
                        final visible = !_hiddenFileIndices.contains(index);
                        return CheckboxListTile(
                          value: visible,
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                _hiddenFileIndices.remove(index);
                              } else {
                                _hiddenFileIndices.add(index);
                              }
                            });
                            setState(() {});
                          },
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
