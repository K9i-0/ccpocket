import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/git/state/git_view_cubit.dart';
import 'package:ccpocket/features/git/state/git_view_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';

const _sampleDiff = '''
diff --git a/lib/main.dart b/lib/main.dart
--- a/lib/main.dart
+++ b/lib/main.dart
@@ -1,4 +1,5 @@
 void main() {
-  print('goodbye');
+  print('hello');
+  print('world');
   runApp(App());
 }
''';

const _multiFileDiff = '''
diff --git a/file_a.dart b/file_a.dart
--- a/file_a.dart
+++ b/file_a.dart
@@ -1,2 +1,2 @@
-old
+new
 same
diff --git a/file_b.dart b/file_b.dart
--- a/file_b.dart
+++ b/file_b.dart
@@ -1,2 +1,3 @@
 first
+added
 last
diff --git a/file_c.dart b/file_c.dart
--- a/file_c.dart
+++ b/file_c.dart
@@ -1,2 +1,2 @@
-removed
+replaced
 end
''';

/// Large diff with many files for stress testing.
const _largeDiff = '''
diff --git a/a.dart b/a.dart
--- a/a.dart
+++ b/a.dart
@@ -1,1 +1,1 @@
-a
+aa
diff --git a/b.dart b/b.dart
--- a/b.dart
+++ b/b.dart
@@ -1,1 +1,1 @@
-b
+bb
diff --git a/c.dart b/c.dart
--- a/c.dart
+++ b/c.dart
@@ -1,1 +1,1 @@
-c
+cc
diff --git a/d.dart b/d.dart
--- a/d.dart
+++ b/d.dart
@@ -1,1 +1,1 @@
-d
+dd
diff --git a/e.dart b/e.dart
--- a/e.dart
+++ b/e.dart
@@ -1,1 +1,1 @@
-e
+ee
''';

/// Mock BridgeService that exposes controllable streams for diff + staging + remote.
class MockDiffBridgeService extends BridgeService {
  final _diffController = StreamController<DiffResultMessage>.broadcast();
  final _stageController = StreamController<GitStageResultMessage>.broadcast();
  final _unstageController =
      StreamController<GitUnstageResultMessage>.broadcast();
  final _unstageHunksController =
      StreamController<GitUnstageHunksResultMessage>.broadcast();
  final _fetchController = StreamController<GitFetchResultMessage>.broadcast();
  final _pullController = StreamController<GitPullResultMessage>.broadcast();
  final _remoteStatusController =
      StreamController<GitRemoteStatusResultMessage>.broadcast();
  final _branchesController =
      StreamController<GitBranchesResultMessage>.broadcast();
  final _checkoutController =
      StreamController<GitCheckoutBranchResultMessage>.broadcast();
  final _revertFileController =
      StreamController<GitRevertFileResultMessage>.broadcast();
  final _revertHunksController =
      StreamController<GitRevertHunksResultMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<DiffResultMessage> get diffResults => _diffController.stream;
  @override
  Stream<GitStageResultMessage> get gitStageResults => _stageController.stream;
  @override
  Stream<GitUnstageResultMessage> get gitUnstageResults =>
      _unstageController.stream;
  @override
  Stream<GitUnstageHunksResultMessage> get gitUnstageHunksResults =>
      _unstageHunksController.stream;
  @override
  Stream<GitFetchResultMessage> get gitFetchResults => _fetchController.stream;
  @override
  Stream<GitPullResultMessage> get gitPullResults => _pullController.stream;
  @override
  Stream<GitRemoteStatusResultMessage> get gitRemoteStatusResults =>
      _remoteStatusController.stream;
  @override
  Stream<GitBranchesResultMessage> get gitBranchesResults =>
      _branchesController.stream;
  @override
  Stream<GitCheckoutBranchResultMessage> get gitCheckoutBranchResults =>
      _checkoutController.stream;
  @override
  Stream<GitRevertFileResultMessage> get gitRevertFileResults =>
      _revertFileController.stream;
  @override
  Stream<GitRevertHunksResultMessage> get gitRevertHunksResults =>
      _revertHunksController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  void emitDiff(DiffResultMessage msg) => _diffController.add(msg);
  void emitStageResult(GitStageResultMessage msg) => _stageController.add(msg);
  void emitUnstageResult(GitUnstageResultMessage msg) =>
      _unstageController.add(msg);
  void emitUnstageHunksResult(GitUnstageHunksResultMessage msg) =>
      _unstageHunksController.add(msg);
  void emitFetchResult(GitFetchResultMessage msg) => _fetchController.add(msg);
  void emitRemoteStatus(GitRemoteStatusResultMessage msg) =>
      _remoteStatusController.add(msg);
  void emitRevertFileResult(GitRevertFileResultMessage msg) =>
      _revertFileController.add(msg);
  void emitRevertHunksResult(GitRevertHunksResultMessage msg) =>
      _revertHunksController.add(msg);

  @override
  void dispose() {
    _diffController.close();
    _stageController.close();
    _unstageController.close();
    _unstageHunksController.close();
    _fetchController.close();
    _pullController.close();
    _remoteStatusController.close();
    _branchesController.close();
    _checkoutController.close();
    _revertFileController.close();
    _revertHunksController.close();
  }
}

GitViewCubit _createCubit({String? initialDiff}) {
  return GitViewCubit(bridge: BridgeService(), initialDiff: initialDiff);
}

void main() {
  group('GitViewCubit - initialDiff mode', () {
    test('parses initial diff on build', () {
      final cubit = _createCubit(initialDiff: _sampleDiff);
      addTearDown(cubit.close);

      expect(cubit.state.files.length, 1);
      expect(cubit.state.files.first.filePath, 'lib/main.dart');
      expect(cubit.state.loading, false);
      expect(cubit.state.error, isNull);
    });

    test('returns empty files for empty diff', () {
      final cubit = _createCubit(initialDiff: '');
      addTearDown(cubit.close);

      expect(cubit.state.files, isEmpty);
      expect(cubit.state.loading, false);
    });
  });

  group('GitViewCubit - toggleCollapse', () {
    test('adds fileIdx to collapsedFileIndices', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleCollapse(0);

      expect(cubit.state.collapsedFileIndices, contains(0));
    });

    test('removes fileIdx when already collapsed', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleCollapse(1);
      expect(cubit.state.collapsedFileIndices, contains(1));

      cubit.toggleCollapse(1);
      expect(cubit.state.collapsedFileIndices, isNot(contains(1)));
    });

    test('toggles multiple files independently', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleCollapse(0);
      cubit.toggleCollapse(2);

      expect(cubit.state.collapsedFileIndices, {0, 2});
    });
  });

  group('GitViewCubit - default state', () {
    test('returns empty state when no params provided', () {
      final cubit = GitViewCubit(bridge: BridgeService());
      addTearDown(cubit.close);

      expect(cubit.state, const GitViewState());
      expect(cubit.state.files, isEmpty);
      expect(cubit.state.loading, false);
      expect(cubit.state.lineWrapEnabled, isTrue);
      expect(cubit.state.error, isNull);
    });
  });

  group('GitViewCubit - initialDiff edge cases', () {
    test('parses whitespace-only diff as empty', () {
      final cubit = _createCubit(initialDiff: '   \n\n  ');
      addTearDown(cubit.close);

      expect(cubit.state.files, isEmpty);
    });

    test('parses multi-file diff correctly', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      expect(cubit.state.files, hasLength(3));
      expect(cubit.state.files[0].filePath, 'file_a.dart');
      expect(cubit.state.files[1].filePath, 'file_b.dart');
      expect(cubit.state.files[2].filePath, 'file_c.dart');
    });

    test('parses large diff with many files', () {
      final cubit = _createCubit(initialDiff: _largeDiff);
      addTearDown(cubit.close);

      expect(cubit.state.files, hasLength(5));
      expect(cubit.state.loading, false);
      expect(cubit.state.error, isNull);
    });
  });

  group('GitViewCubit - projectPath mode', () {
    test('starts in loading state when projectPath provided', () {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      expect(cubit.state.loading, true);
      expect(cubit.state.files, isEmpty);
    });

    test('sends getDiff, gitFetch, and gitBranches on init', () {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      // getDiff + gitFetch + gitBranches on init
      expect(mockBridge.sentMessages, hasLength(3));
      expect(mockBridge.sentMessages[0].type, 'get_diff');
      expect(mockBridge.sentMessages[1].type, 'git_fetch');
      expect(mockBridge.sentMessages[2].type, 'git_branches');
    });

    test('updates state when diff result arrives', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _sampleDiff));
      await Future.microtask(() {});

      expect(cubit.state.loading, false);
      expect(cubit.state.files, hasLength(1));
      expect(cubit.state.error, isNull);
    });

    test('handles error in diff result', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(
        const DiffResultMessage(diff: '', error: 'git not found'),
      );
      await Future.microtask(() {});

      expect(cubit.state.loading, false);
      expect(cubit.state.error, 'git not found');
    });

    test('handles empty diff result', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: ''));
      await Future.microtask(() {});

      expect(cubit.state.loading, false);
      expect(cubit.state.files, isEmpty);
      expect(cubit.state.error, isNull);
    });

    test('handles whitespace-only diff result', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: '   \n  '));
      await Future.microtask(() {});

      expect(cubit.state.loading, false);
      expect(cubit.state.files, isEmpty);
    });
  });

  group('GitViewCubit - staging mode', () {
    test('switchMode emits viewMode change and requests staged diff', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      // Initial: getDiff + gitFetch
      final initCount = mockBridge.sentMessages.length;

      cubit.switchMode(GitViewMode.staged);

      expect(cubit.state.viewMode, GitViewMode.staged);
      expect(cubit.state.loading, isTrue);
      // Should send getDiff(staged) + gitFetch
      final newMessages = mockBridge.sentMessages.sublist(initCount);
      final getDiffMsg = newMessages.firstWhere((m) => m.type == 'get_diff');
      final json = jsonDecode(getDiffMsg.toJson()) as Map<String, dynamic>;
      expect(json['staged'], isTrue);
    });

    test('switchMode to same mode is a no-op', () {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      final initCount = mockBridge.sentMessages.length;
      cubit.switchMode(GitViewMode.unstaged); // same as default
      // Should not send additional messages
      expect(mockBridge.sentMessages.length, initCount);
    });

    test('stageFile sends git_stage with file path', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      // Simulate diff result to populate files
      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.stageFile(1); // file_b.dart
      expect(cubit.state.staging, isTrue);

      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_stage');
      expect(json['files'], ['file_b.dart']);
    });

    test('stageAll sends git_stage with all file paths', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.stageAll();
      expect(cubit.state.staging, isTrue);

      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_stage');
      expect((json['files'] as List).cast<String>().toSet(), {
        'file_a.dart',
        'file_b.dart',
        'file_c.dart',
      });
    });

    test('successful stage result triggers refresh', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.stageAll();
      mockBridge.emitStageResult(const GitStageResultMessage(success: true));
      await Future.microtask(() {});

      expect(cubit.state.staging, isFalse);
      // Should have sent a refresh getDiff
      expect(
        mockBridge.sentMessages.where((m) => m.type == 'get_diff').length,
        greaterThanOrEqualTo(2),
      );
    });

    test('failed stage result shows error', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.stageFile(0);
      mockBridge.emitStageResult(
        const GitStageResultMessage(success: false, error: 'staging failed'),
      );
      await Future.microtask(() {});

      expect(cubit.state.staging, isFalse);
      expect(cubit.state.error, 'staging failed');
    });

    test('unstageAll sends git_unstage with all file paths', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.unstageAll();
      expect(cubit.state.staging, isTrue);

      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_unstage');
      expect((json['files'] as List).cast<String>().toSet(), {
        'file_a.dart',
        'file_b.dart',
        'file_c.dart',
      });
    });

    test('revertAll sends git_revert_file with all file paths', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.revertAll();
      expect(cubit.state.staging, isTrue);

      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_revert_file');
      expect((json['files'] as List).cast<String>().toSet(), {
        'file_a.dart',
        'file_b.dart',
        'file_c.dart',
      });
    });

    test('switchMode to unstaged requests unstaged diff explicitly', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      cubit.switchMode(GitViewMode.staged);
      final countAfterStaged = mockBridge.sentMessages.length;

      cubit.switchMode(GitViewMode.unstaged);

      final newMessages = mockBridge.sentMessages.sublist(countAfterStaged);
      final getDiffMsg = newMessages.firstWhere((m) => m.type == 'get_diff');
      final json = jsonDecode(getDiffMsg.toJson()) as Map<String, dynamic>;
      expect(json['staged'], isFalse);
    });

    test('unstageHunk sends git_unstage_hunks', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.unstageHunk(0, 0);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_unstage_hunks');
      expect(json['hunks'], [
        {'file': 'file_a.dart', 'hunkIndex': 0},
      ]);
    });

    test('revertHunk sends git_revert_hunks', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = GitViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
      await Future.microtask(() {});

      cubit.revertHunk(1, 0);
      final json =
          jsonDecode(mockBridge.sentMessages.last.toJson())
              as Map<String, dynamic>;
      expect(json['type'], 'git_revert_hunks');
      expect(json['hunks'], [
        {'file': 'file_b.dart', 'hunkIndex': 0},
      ]);
    });

    test(
      'successful local git operation refreshes diff without git_fetch',
      () async {
        final mockBridge = MockDiffBridgeService();
        final cubit = GitViewCubit(
          bridge: mockBridge,
          projectPath: '/home/user/project',
        );
        addTearDown(() {
          cubit.close();
          mockBridge.dispose();
        });

        mockBridge.emitDiff(const DiffResultMessage(diff: _multiFileDiff));
        await Future.microtask(() {});
        final baselineFetchCount = mockBridge.sentMessages
            .where((m) => m.type == 'git_fetch')
            .length;

        cubit.revertHunk(0, 0);
        mockBridge.emitRevertHunksResult(
          const GitRevertHunksResultMessage(success: true),
        );
        await Future.microtask(() {});

        expect(
          mockBridge.sentMessages.where((m) => m.type == 'git_fetch').length,
          baselineFetchCount,
        );
        expect(
          mockBridge.sentMessages.where((m) => m.type == 'get_diff').length,
          greaterThanOrEqualTo(2),
        );
      },
    );
  });
}
