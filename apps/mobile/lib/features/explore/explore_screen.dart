import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/bridge_service.dart';
import '../file_peek/file_peek_sheet.dart';
import 'state/explore_cubit.dart';
import 'state/explore_state.dart';
import 'widgets/explore_breadcrumbs.dart';
import 'widgets/explore_empty_state.dart';
import 'widgets/explore_file_list.dart';

@RoutePage()
class ExploreScreen extends StatelessWidget {
  final String sessionId;
  final String projectPath;
  final List<String> initialFiles;
  final String initialPath;
  final List<String> recentPeekedFiles;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<ExploreScreenResult>? onResultChanged;

  const ExploreScreen({
    super.key,
    required this.sessionId,
    required this.projectPath,
    this.initialFiles = const [],
    this.initialPath = '',
    this.recentPeekedFiles = const [],
    this.embedded = false,
    this.onClose,
    this.onResultChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExploreCubit(
        bridge: context.read<BridgeService>(),
        projectPath: projectPath,
        initialFiles: initialFiles,
        initialPath: initialPath,
        recentPeekedFiles: recentPeekedFiles,
      ),
      child: _ExploreScreenBody(
        sessionId: sessionId,
        projectPath: projectPath,
        embedded: embedded,
        onClose: onClose,
        onResultChanged: onResultChanged,
      ),
    );
  }
}

class _ExploreScreenBody extends StatefulWidget {
  final String sessionId;
  final String projectPath;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<ExploreScreenResult>? onResultChanged;

  const _ExploreScreenBody({
    required this.sessionId,
    required this.projectPath,
    this.embedded = false,
    this.onClose,
    this.onResultChanged,
  });

  @override
  State<_ExploreScreenBody> createState() => _ExploreScreenBodyState();
}

class _ExploreScreenBodyState extends State<_ExploreScreenBody> {
  final GlobalKey _highlightedEntryKey = GlobalKey();
  String? _highlightedFilePath;

  void _closeExplorer() {
    final result = context.read<ExploreCubit>().buildResult();
    widget.onResultChanged?.call(result);
    if (widget.embedded) {
      widget.onClose?.call();
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _notifyResultChanged(ExploreCubit cubit) {
    widget.onResultChanged?.call(cubit.buildResult());
  }

  Future<void> _openRecentFilesSheet(ExploreCubit cubit) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _RecentFilesSheet(
        recentFiles: cubit.recentPeekedFiles,
        availableFiles: cubit.allFiles.toSet(),
      ),
    );
    if (!mounted || picked == null) return;
    await _openFilePeek(cubit, picked, navigateToFileDirectory: true);
  }

  Future<void> _openFilePeek(
    ExploreCubit cubit,
    String filePath, {
    bool navigateToFileDirectory = false,
  }) async {
    setState(() => _highlightedFilePath = filePath);
    if (navigateToFileDirectory) {
      cubit.jumpToFile(filePath);
      _notifyResultChanged(cubit);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await showFilePeekSheet(
      context,
      bridge: context.read<BridgeService>(),
      projectPath: widget.projectPath,
      filePath: filePath,
      onOpened: () {
        cubit.recordPeekedFile(filePath);
        _notifyResultChanged(cubit);
        if (mounted) {
          setState(() => _highlightedFilePath = filePath);
        }
      },
    );
  }

  void _ensureHighlightedVisible() {
    final currentContext = _highlightedEntryKey.currentContext;
    if (_highlightedFilePath == null || currentContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highlightedFilePath == null) return;
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 220),
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreCubit, ExploreState>(
      builder: (context, state) {
        _ensureHighlightedVisible();
        final cubit = context.read<ExploreCubit>();
        final scaffold = Scaffold(
          appBar: AppBar(
            title: const Text('Explorer'),
            automaticallyImplyLeading: !widget.embedded,
            leading: IconButton(
              key: ValueKey(
                widget.embedded
                    ? 'close_explore_pane_button'
                    : 'close_explore_screen_button',
              ),
              onPressed: _closeExplorer,
              icon: Icon(widget.embedded ? Icons.close : Icons.arrow_back),
            ),
            actions: [
              IconButton(
                key: const ValueKey('explore_recent_files_button'),
                onPressed: () => _openRecentFilesSheet(cubit),
                icon: const Icon(Icons.history),
                tooltip: 'Recent files',
              ),
            ],
          ),
          body: Column(
            children: [
              ExploreBreadcrumbs(
                projectName: widget.projectPath.split('/').last,
                currentPath: state.currentPath,
                breadcrumbs: cubit.breadcrumbs,
                onTapCrumb: (crumb) {
                  setState(() => _highlightedFilePath = null);
                  if (crumb == state.currentPath) return;
                  cubit.openDirectory(crumb);
                  _notifyResultChanged(cubit);
                },
              ),
              Expanded(child: _buildBody(context, state)),
            ],
          ),
        );

        if (widget.embedded) {
          return scaffold;
        }

        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _closeExplorer();
          },
          child: scaffold,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ExploreState state) {
    switch (state.status) {
      case ExploreStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ExploreStatus.empty:
        return const ExploreEmptyState();
      case ExploreStatus.error:
        return Center(child: Text(state.error ?? 'Failed to load files'));
      case ExploreStatus.ready:
        return ExploreFileList(
          entries: state.visibleEntries,
          highlightedFilePath: _highlightedFilePath,
          highlightedEntryKey: _highlightedEntryKey,
          onTapEntry: (entry) {
            if (entry.isDirectory) {
              setState(() => _highlightedFilePath = null);
              context.read<ExploreCubit>().openDirectory(entry.relativePath);
              _notifyResultChanged(context.read<ExploreCubit>());
              return;
            }
            _openFilePeek(context.read<ExploreCubit>(), entry.relativePath);
          },
        );
    }
  }
}

class _RecentFilesSheet extends StatelessWidget {
  final List<String> recentFiles;
  final Set<String> availableFiles;

  const _RecentFilesSheet({
    required this.recentFiles,
    required this.availableFiles,
  });

  @override
  Widget build(BuildContext context) {
    final subtle = Theme.of(context).colorScheme.onSurfaceVariant;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: subtle.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent open files',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (recentFiles.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Text('No recent open files yet'),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: recentFiles.length,
                itemBuilder: (context, index) {
                  final path = recentFiles[index];
                  final exists = availableFiles.contains(path);
                  final fileName = path.split('/').last;
                  final dir = parentDirectoryOf(path);
                  return ListTile(
                    enabled: exists,
                    leading: Icon(
                      exists ? Icons.description_outlined : Icons.error_outline,
                    ),
                    title: Text(fileName),
                    subtitle: Text(
                      dir.isEmpty ? '/' : dir,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: subtle,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: exists
                        ? () => Navigator.of(context).pop(path)
                        : null,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
