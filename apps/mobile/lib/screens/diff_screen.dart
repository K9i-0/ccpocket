import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../providers/bridge_providers.dart';
import '../theme/app_theme.dart';
import '../utils/diff_parser.dart';

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
                  _HunkWidget(hunk: file.hunks[index], appColors: appColors),
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
          return _buildFileHeader(file, fileIdx, appColors);
        }
        if (file.isBinary) {
          return _buildBinaryNotice(appColors);
        }
        return _HunkWidget(
          hunk: file.hunks[localIdx - 1],
          appColors: appColors,
        );
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

  Widget _buildFileHeader(DiffFile file, int fileIndex, AppColors appColors) {
    final stats = file.stats;
    final collapsed = _collapsedFileIndices.contains(fileIndex);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (collapsed) {
            _collapsedFileIndices.remove(fileIndex);
          } else {
            _collapsedFileIndices.add(fileIndex);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: appColors.codeBackground,
          border: Border(bottom: BorderSide(color: appColors.codeBorder)),
        ),
        child: Row(
          children: [
            Icon(
              file.isNewFile
                  ? Icons.add_circle_outline
                  : file.isDeleted
                  ? Icons.remove_circle_outline
                  : Icons.edit_note,
              size: 16,
              color: appColors.subtleText,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.filePath,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: appColors.toolResultTextExpanded,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (stats.added > 0)
              Text(
                '+${stats.added}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appColors.diffAdditionText,
                ),
              ),
            if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 6),
            if (stats.removed > 0)
              Text(
                '-${stats.removed}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appColors.diffDeletionText,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 20,
              color: appColors.subtleText,
            ),
          ],
        ),
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
                          secondary: _StatsBadge(
                            file: file,
                            appColors: appColors,
                          ),
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

// ---------------------------------------------------------------------------
// Hunk widget
// ---------------------------------------------------------------------------

class _HunkWidget extends StatelessWidget {
  final DiffHunk hunk;
  final AppColors appColors;

  const _HunkWidget({required this.hunk, required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Hunk header
        if (hunk.header.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: appColors.codeBackground,
            child: Text(
              hunk.header,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: appColors.subtleText,
              ),
            ),
          ),
        // Diff lines
        for (final line in hunk.lines)
          _DiffLineWidget(line: line, appColors: appColors),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual diff line
// ---------------------------------------------------------------------------

class _DiffLineWidget extends StatelessWidget {
  final DiffLine line;
  final AppColors appColors;

  const _DiffLineWidget({required this.line, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor, prefix) = switch (line.type) {
      DiffLineType.addition => (
        appColors.diffAdditionBackground,
        appColors.diffAdditionText,
        '+',
      ),
      DiffLineType.deletion => (
        appColors.diffDeletionBackground,
        appColors.diffDeletionText,
        '-',
      ),
      DiffLineType.context => (
        Colors.transparent,
        appColors.toolResultTextExpanded,
        ' ',
      ),
    };

    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: line.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Line copied'),
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Old line number
            SizedBox(
              width: 40,
              child: Text(
                line.oldLineNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ),
            // New line number
            SizedBox(
              width: 40,
              child: Text(
                line.newLineNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: appColors.subtleText,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Prefix
            SizedBox(
              width: 12,
              child: Text(
                prefix,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ),
            // Content — horizontal scroll for long lines
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  line.content,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: textColor,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats badge (used in file selector popup)
// ---------------------------------------------------------------------------

class _StatsBadge extends StatelessWidget {
  final DiffFile file;
  final AppColors appColors;

  const _StatsBadge({required this.file, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final stats = file.stats;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (stats.added > 0)
          Text(
            '+${stats.added}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffAdditionText,
            ),
          ),
        if (stats.added > 0 && stats.removed > 0) const SizedBox(width: 4),
        if (stats.removed > 0)
          Text(
            '-${stats.removed}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.diffDeletionText,
            ),
          ),
        if (file.isBinary)
          Text(
            'binary',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: appColors.subtleText,
            ),
          ),
      ],
    );
  }
}
