import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/bridge_service.dart';
import 'explore_state.dart';

class ExploreCubit extends Cubit<ExploreState> {
  final BridgeService _bridge;
  StreamSubscription<List<String>>? _fileListSub;
  List<String> _recentPeekedFiles;

  ExploreCubit({
    required BridgeService bridge,
    required String projectPath,
    List<String> initialFiles = const [],
    String initialPath = '',
    List<String> recentPeekedFiles = const [],
  }) : _bridge = bridge,
       _recentPeekedFiles = recentPeekedFiles.take(10).toList(),
       super(ExploreState(projectPath: projectPath, currentPath: initialPath)) {
    _fileListSub = _bridge.fileList.listen(_onFileListUpdated);
    if (initialFiles.isNotEmpty) {
      _applyFiles(initialFiles);
    } else {
      _bridge.requestFileList(projectPath);
    }
  }

  void _onFileListUpdated(List<String> files) {
    _applyFiles(files);
  }

  void _applyFiles(List<String> files) {
    final normalizedPath = normalizeExplorePath(files, state.currentPath);
    final entries = buildExploreEntries(files, currentPath: normalizedPath);
    emit(
      state.copyWith(
        currentPath: normalizedPath,
        allFiles: files,
        visibleEntries: entries,
        status: switch ((files.isEmpty, entries.isEmpty)) {
          (true, _) => ExploreStatus.empty,
          (_, false) => ExploreStatus.ready,
          (_, true) => ExploreStatus.empty,
        },
        error: null,
      ),
    );
  }

  void openDirectory(String relativePath) {
    final normalizedPath = normalizeExplorePath(state.allFiles, relativePath);
    final entries = buildExploreEntries(
      state.allFiles,
      currentPath: normalizedPath,
    );
    emit(
      state.copyWith(
        currentPath: normalizedPath,
        visibleEntries: entries,
        status: entries.isEmpty ? ExploreStatus.empty : ExploreStatus.ready,
      ),
    );
  }

  bool goUp() {
    if (state.currentPath.isEmpty) return false;
    final next = parentDirectoryOf(state.currentPath);
    final entries = buildExploreEntries(state.allFiles, currentPath: next);
    emit(
      state.copyWith(
        currentPath: next,
        visibleEntries: entries,
        status: entries.isEmpty ? ExploreStatus.empty : ExploreStatus.ready,
      ),
    );
    return true;
  }

  List<String> get breadcrumbs => breadcrumbsForPath(state.currentPath);
  List<String> get recentPeekedFiles => List.unmodifiable(_recentPeekedFiles);
  List<String> get allFiles => List.unmodifiable(state.allFiles);

  void recordPeekedFile(String path) {
    _recentPeekedFiles = updateRecentFileHistory(_recentPeekedFiles, path);
  }

  void jumpToFile(String filePath) {
    openDirectory(parentDirectoryOf(filePath));
  }

  ExploreScreenResult buildResult() => ExploreScreenResult(
    currentPath: state.currentPath,
    recentPeekedFiles: recentPeekedFiles,
  );

  @override
  Future<void> close() {
    _fileListSub?.cancel();
    return super.close();
  }
}

List<ExploreEntry> buildExploreEntries(
  List<String> files, {
  required String currentPath,
}) {
  final prefix = currentPath.isEmpty ? '' : '$currentPath/';
  final directories = <String>{};
  final entries = <ExploreEntry>[];

  for (final file in files) {
    if (!file.startsWith(prefix)) continue;
    final remainder = file.substring(prefix.length);
    if (remainder.isEmpty) continue;

    final slashIndex = remainder.indexOf('/');
    if (slashIndex == -1) {
      entries.add(
        ExploreEntry(name: remainder, relativePath: file, isDirectory: false),
      );
      continue;
    }

    final dirName = remainder.substring(0, slashIndex);
    if (directories.add(dirName)) {
      final relativePath = currentPath.isEmpty
          ? dirName
          : '$currentPath/$dirName';
      entries.add(
        ExploreEntry(
          name: dirName,
          relativePath: relativePath,
          isDirectory: true,
        ),
      );
    }
  }

  entries.sort((a, b) {
    if (a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return entries;
}

String parentDirectoryOf(String currentPath) {
  final lastSlash = currentPath.lastIndexOf('/');
  if (lastSlash == -1) return '';
  return currentPath.substring(0, lastSlash);
}

String normalizeExplorePath(List<String> files, String currentPath) {
  var candidate = currentPath.trim();
  while (candidate.isNotEmpty) {
    final prefix = '$candidate/';
    if (files.any((file) => file.startsWith(prefix))) {
      return candidate;
    }
    candidate = parentDirectoryOf(candidate);
  }
  return '';
}

List<String> breadcrumbsForPath(String currentPath) {
  if (currentPath.isEmpty) return const [];
  final segments = currentPath.split('/');
  final breadcrumbs = <String>[];
  for (var i = 0; i < segments.length; i++) {
    breadcrumbs.add(segments.take(i + 1).join('/'));
  }
  return breadcrumbs;
}

List<String> updateRecentFileHistory(
  List<String> current,
  String path, {
  int limit = 10,
}) {
  final normalized = path.trim();
  if (normalized.isEmpty) return current;
  final next = [normalized, ...current.where((file) => file != normalized)];
  return next.take(limit).toList();
}
