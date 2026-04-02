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
  final String projectPath;
  final List<String> initialFiles;

  const ExploreScreen({
    super.key,
    required this.projectPath,
    this.initialFiles = const [],
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExploreCubit(
        bridge: context.read<BridgeService>(),
        projectPath: projectPath,
        initialFiles: initialFiles,
      ),
      child: _ExploreScreenBody(projectPath: projectPath),
    );
  }
}

class _ExploreScreenBody extends StatelessWidget {
  final String projectPath;

  const _ExploreScreenBody({required this.projectPath});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExploreCubit, ExploreState>(
      builder: (context, state) {
        final cubit = context.read<ExploreCubit>();
        final currentLabel = state.currentPath.isEmpty
            ? projectPath.split('/').last
            : state.currentPath;

        return PopScope<void>(
          canPop: state.currentPath.isEmpty,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (cubit.goUp()) return;
            Navigator.of(context).maybePop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                currentLabel.isEmpty ? 'Explore' : currentLabel,
                overflow: TextOverflow.ellipsis,
              ),
              leading: IconButton(
                onPressed: () {
                  if (!cubit.goUp()) {
                    Navigator.of(context).maybePop();
                  }
                },
                icon: const BackButtonIcon(),
              ),
            ),
            body: Column(
              children: [
                ExploreBreadcrumbs(
                  projectName: projectPath.split('/').last,
                  currentPath: state.currentPath,
                  breadcrumbs: cubit.breadcrumbs,
                  onTapCrumb: (crumb) {
                    if (crumb.isEmpty) {
                      while (cubit.goUp()) {}
                      return;
                    }
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
          onTapEntry: (entry) {
            if (entry.isDirectory) {
              context.read<ExploreCubit>().openDirectory(entry.relativePath);
              return;
            }
            showFilePeekSheet(
              context,
              bridge: context.read<BridgeService>(),
              projectPath: projectPath,
              filePath: entry.relativePath,
            );
          },
        );
    }
  }
}
