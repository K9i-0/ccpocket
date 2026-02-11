import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/diff/state/diff_view_cubit.dart';
import 'package:ccpocket/features/diff/state/diff_view_state.dart';
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

/// Mock BridgeService that exposes a controllable diffResults stream.
class MockDiffBridgeService extends BridgeService {
  final _diffController = StreamController<DiffResultMessage>.broadcast();
  final sentMessages = <ClientMessage>[];

  @override
  Stream<DiffResultMessage> get diffResults => _diffController.stream;

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  void emitDiff(DiffResultMessage msg) => _diffController.add(msg);

  @override
  void dispose() => _diffController.close();
}

DiffViewCubit _createCubit({String? initialDiff}) {
  return DiffViewCubit(bridge: BridgeService(), initialDiff: initialDiff);
}

void main() {
  group('DiffViewCubit - initialDiff mode', () {
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

  group('DiffViewCubit - toggleCollapse', () {
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

  group('DiffViewCubit - hidden file management', () {
    test('setHiddenFiles replaces all hidden indices', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.setHiddenFiles({0, 1});

      expect(cubit.state.hiddenFileIndices, {0, 1});
    });

    test('toggleFileVisibility adds then removes', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleFileVisibility(1);
      expect(cubit.state.hiddenFileIndices, {1});

      cubit.toggleFileVisibility(1);
      expect(cubit.state.hiddenFileIndices, isEmpty);
    });

    test('clearHidden resets all hidden files', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.setHiddenFiles({0, 1, 2});
      expect(cubit.state.hiddenFileIndices.length, 3);

      cubit.clearHidden();
      expect(cubit.state.hiddenFileIndices, isEmpty);
    });
  });

  group('DiffViewCubit - default state', () {
    test('returns empty state when no params provided', () {
      final cubit = DiffViewCubit(bridge: BridgeService());
      addTearDown(cubit.close);

      expect(cubit.state, const DiffViewState());
      expect(cubit.state.files, isEmpty);
      expect(cubit.state.loading, false);
      expect(cubit.state.error, isNull);
    });
  });

  group('DiffViewCubit - initialDiff edge cases', () {
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

  group('DiffViewCubit - projectPath mode', () {
    test('starts in loading state when projectPath provided', () {
      final mockBridge = MockDiffBridgeService();
      final cubit = DiffViewCubit(
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

    test('sends getDiff message to bridge', () {
      final mockBridge = MockDiffBridgeService();
      final cubit = DiffViewCubit(
        bridge: mockBridge,
        projectPath: '/home/user/project',
      );
      addTearDown(() {
        cubit.close();
        mockBridge.dispose();
      });

      expect(mockBridge.sentMessages, hasLength(1));
    });

    test('updates state when diff result arrives', () async {
      final mockBridge = MockDiffBridgeService();
      final cubit = DiffViewCubit(
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
      final cubit = DiffViewCubit(
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
      final cubit = DiffViewCubit(
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
      final cubit = DiffViewCubit(
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

  group('DiffViewCubit - collapse and visibility combined', () {
    test('collapsed and hidden states are independent', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleCollapse(0);
      cubit.toggleFileVisibility(1);

      expect(cubit.state.collapsedFileIndices, {0});
      expect(cubit.state.hiddenFileIndices, {1});
    });

    test('clearHidden does not affect collapsed state', () {
      final cubit = _createCubit(initialDiff: _multiFileDiff);
      addTearDown(cubit.close);

      cubit.toggleCollapse(0);
      cubit.toggleFileVisibility(1);
      cubit.clearHidden();

      expect(cubit.state.collapsedFileIndices, {0});
      expect(cubit.state.hiddenFileIndices, isEmpty);
    });
  });
}
