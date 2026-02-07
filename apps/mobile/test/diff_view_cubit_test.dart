import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/diff/state/diff_view_cubit.dart';
import 'package:ccpocket/features/diff/state/diff_view_state.dart';
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
}
