import 'package:freezed_annotation/freezed_annotation.dart';

part 'explore_state.freezed.dart';

enum ExploreStatus { loading, ready, empty, error }

class ExploreScreenResult {
  final String currentPath;
  final List<String> recentPeekedFiles;

  const ExploreScreenResult({
    required this.currentPath,
    required this.recentPeekedFiles,
  });
}

class ExploreEntry {
  final String name;
  final String relativePath;
  final bool isDirectory;

  const ExploreEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
  });
}

@freezed
abstract class ExploreState with _$ExploreState {
  const factory ExploreState({
    required String projectPath,
    @Default('') String currentPath,
    @Default([]) List<String> allFiles,
    @Default([]) List<ExploreEntry> visibleEntries,
    @Default(ExploreStatus.loading) ExploreStatus status,
    String? error,
  }) = _ExploreState;
}
