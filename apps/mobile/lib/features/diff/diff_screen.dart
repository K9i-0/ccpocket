import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/messages.dart';
import '../../providers/bridge_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/diff_parser.dart';
import 'widgets/diff_file_header.dart';
import 'widgets/diff_hunk_widget.dart';
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
      body: _buildBody(appColors),
    );
  }

  Widget _buildBody(AppColors appColors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildError(appColors);
    }
    if (_diffFiles.isEmpty) {
      return _buildEmpty(appColors);
    }
    return _buildDiffContent(appColors);
  }

  Widget _buildError(AppColors appColors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: appColors.errorText),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: appColors.errorText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppColors appColors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: appColors.toolIcon),
          const SizedBox(height: 12),
          Text(
            'No changes',
            style: TextStyle(fontSize: 16, color: appColors.subtleText),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffContent(AppColors appColors) {
    // Single-file mode: no header needed
    if (_diffFiles.length == 1) {
      final file = _diffFiles.first;
      return file.isBinary
          ? _buildBinaryNotice(appColors)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: file.hunks.length,
              itemBuilder: (context, index) =>
                  DiffHunkWidget(hunk: file.hunks[index]),
            );
    }

    // Multi-file mode: all visible files in one scrollable list
    final visibleFiles = <int>[];
    for (var i = 0; i < _diffFiles.length; i++) {
      if (!_hiddenFileIndices.contains(i)) visibleFiles.add(i);
    }

    if (visibleFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 48, color: appColors.subtleText),
            const SizedBox(height: 12),
            Text(
              'All files filtered out',
              style: TextStyle(fontSize: 16, color: appColors.subtleText),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _hiddenFileIndices.clear()),
              child: const Text('Show all'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _countListItems(visibleFiles),
      itemBuilder: (context, index) =>
          _buildListItem(index, visibleFiles, appColors),
    );
  }

  /// Count total items: for each visible file, header + hunks (if expanded) + divider (except last).
  int _countListItems(List<int> visibleFiles) {
    var count = 0;
    for (var i = 0; i < visibleFiles.length; i++) {
      final fileIdx = visibleFiles[i];
      final file = _diffFiles[fileIdx];
      final collapsed = _collapsedFileIndices.contains(fileIdx);
      count += 1; // header
      if (!collapsed) {
        count += file.isBinary ? 1 : file.hunks.length;
      }
      if (i < visibleFiles.length - 1) count += 1; // divider
    }
    return count;
  }

  /// Map a flat list index to the appropriate widget.
  Widget _buildListItem(
    int index,
    List<int> visibleFiles,
    AppColors appColors,
  ) {
    var offset = 0;
    for (var i = 0; i < visibleFiles.length; i++) {
      final fileIdx = visibleFiles[i];
      final file = _diffFiles[fileIdx];
      final collapsed = _collapsedFileIndices.contains(fileIdx);
      final contentCount = collapsed
          ? 0
          : (file.isBinary ? 1 : file.hunks.length);
      final sectionSize = 1 + contentCount; // header + content

      if (index < offset + sectionSize) {
        final localIdx = index - offset;
        if (localIdx == 0) {
          return DiffFileHeader(
            file: file,
            collapsed: collapsed,
            onToggleCollapse: () {
              setState(() {
                if (collapsed) {
                  _collapsedFileIndices.remove(fileIdx);
                } else {
                  _collapsedFileIndices.add(fileIdx);
                }
              });
            },
          );
        }
        if (file.isBinary) {
          return _buildBinaryNotice(appColors);
        }
        return DiffHunkWidget(hunk: file.hunks[localIdx - 1]);
      }

      offset += sectionSize;

      // Divider between files
      if (i < visibleFiles.length - 1) {
        if (index == offset) {
          return Divider(height: 24, thickness: 1, color: appColors.codeBorder);
        }
        offset += 1;
      }
    }
    return const SizedBox.shrink();
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

  Widget _buildBinaryNotice(AppColors appColors) {
    return Center(
      child: Text(
        'Binary file — diff not available',
        style: TextStyle(color: appColors.subtleText),
      ),
    );
  }
}
