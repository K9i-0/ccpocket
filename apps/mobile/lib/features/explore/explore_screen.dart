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

  const ExploreScreen({
    super.key,
    required this.sessionId,
    required this.projectPath,
    this.initialFiles = const [],
    this.initialPath = '',
    this.recentPeekedFiles = const [],
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
      child: _ExploreScreenBody(sessionId: sessionId, projectPath: projectPath),
    );
  }
}

class _ExploreScreenBody extends StatefulWidget {
  final String sessionId;
  final String projectPath;

  const _ExploreScreenBody({
    required this.sessionId,
    required this.projectPath,
  });

  @override
  State<_ExploreScreenBody> createState() => _ExploreScreenBodyState();
}

class _ExploreScreenBodyState extends State<_ExploreScreenBody> {
  final GlobalKey _highlightedEntryKey = GlobalKey();
  String? _highlightedFilePath;

  void _closeExplorer() {
    Navigator.of(context).pop(context.read<ExploreCubit>().buildResult());
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
        currentPath: cubit.state.currentPath,
        recentFiles: cubit.recentPeekedFiles,
        availableFiles: cubit.allFiles.toSet(),
      ),
    );
    if (!mounted || picked == null) return;
    switch (picked) {
      case _RecentFilesSheet.currentLocationValue:
        return;
      case _RecentFilesSheet.projectRootValue:
        setState(() => _highlightedFilePath = null);
        cubit.openDirectory('');
        return;
      default:
        setState(() => _highlightedFilePath = picked);
        cubit.jumpToFile(picked);
    }
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

        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _closeExplorer();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Explorer'),
              leading: IconButton(
                onPressed: _closeExplorer,
                icon: const BackButtonIcon(),
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
                  },
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          ),
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
              return;
            }
            showFilePeekSheet(
              context,
              bridge: context.read<BridgeService>(),
              projectPath: widget.projectPath,
              filePath: entry.relativePath,
              onOpened: () {
                context.read<ExploreCubit>().recordPeekedFile(
                  entry.relativePath,
                );
                setState(() => _highlightedFilePath = entry.relativePath);
              },
            );
          },
        );
    }
  }
}

class _RecentFilesSheet extends StatelessWidget {
  static const currentLocationValue = '__current__';
  static const projectRootValue = '__root__';

  final String currentPath;
  final List<String> recentFiles;
  final Set<String> availableFiles;

  const _RecentFilesSheet({
    required this.currentPath,
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
          ListTile(
            leading: const Icon(Icons.navigation_outlined),
            title: const Text('Current location'),
            subtitle: Text(
              currentPath.isEmpty ? '/' : currentPath,
              style: TextStyle(fontFamily: 'monospace', color: subtle),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => Navigator.of(context).pop(currentLocationValue),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Project root'),
            subtitle: Text(
              '/',
              style: TextStyle(fontFamily: 'monospace', color: subtle),
            ),
            onTap: () => Navigator.of(context).pop(projectRootValue),
          ),
          const Divider(height: 1),
          if (recentFiles.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Text('No recent files yet'),
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
