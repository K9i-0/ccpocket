import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/diff/state/diff_view_notifier.dart';
import 'package:ccpocket/features/diff/state/diff_view_state.dart';

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

ProviderContainer _createContainer({String? initialDiff}) {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  // Access the provider to initialise it.
  container.read(
    diffViewNotifierProvider(initialDiff: initialDiff),
  );
  return container;
}

void main() {
  group('DiffViewNotifier - initialDiff mode', () {
    test('parses initial diff on build', () {
      final container = _createContainer(initialDiff: _sampleDiff);

      final state = container.read(
        diffViewNotifierProvider(initialDiff: _sampleDiff),
      );

      expect(state.files.length, 1);
      expect(state.files.first.filePath, 'lib/main.dart');
      expect(state.loading, false);
      expect(state.error, isNull);
    });

    test('returns empty files for empty diff', () {
      final container = _createContainer(initialDiff: '');

      final state = container.read(
        diffViewNotifierProvider(initialDiff: ''),
      );

      expect(state.files, isEmpty);
      expect(state.loading, false);
    });
  });

  group('DiffViewNotifier - toggleCollapse', () {
    test('adds fileIdx to collapsedFileIndices', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);

      container.read(provider.notifier).toggleCollapse(0);

      final state = container.read(provider);
      expect(state.collapsedFileIndices, contains(0));
    });

    test('removes fileIdx when already collapsed', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);
      final notifier = container.read(provider.notifier);

      notifier.toggleCollapse(1);
      expect(container.read(provider).collapsedFileIndices, contains(1));

      notifier.toggleCollapse(1);
      expect(container.read(provider).collapsedFileIndices, isNot(contains(1)));
    });

    test('toggles multiple files independently', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);
      final notifier = container.read(provider.notifier);

      notifier.toggleCollapse(0);
      notifier.toggleCollapse(2);

      final state = container.read(provider);
      expect(state.collapsedFileIndices, {0, 2});
    });
  });

  group('DiffViewNotifier - hidden file management', () {
    test('setHiddenFiles replaces all hidden indices', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);

      container.read(provider.notifier).setHiddenFiles({0, 1});

      final state = container.read(provider);
      expect(state.hiddenFileIndices, {0, 1});
    });

    test('toggleFileVisibility adds then removes', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);
      final notifier = container.read(provider.notifier);

      notifier.toggleFileVisibility(1);
      expect(container.read(provider).hiddenFileIndices, {1});

      notifier.toggleFileVisibility(1);
      expect(container.read(provider).hiddenFileIndices, isEmpty);
    });

    test('clearHidden resets all hidden files', () {
      final container = _createContainer(initialDiff: _multiFileDiff);
      final provider = diffViewNotifierProvider(initialDiff: _multiFileDiff);
      final notifier = container.read(provider.notifier);

      notifier.setHiddenFiles({0, 1, 2});
      expect(container.read(provider).hiddenFileIndices.length, 3);

      notifier.clearHidden();
      expect(container.read(provider).hiddenFileIndices, isEmpty);
    });
  });

  group('DiffViewNotifier - default state', () {
    test('returns empty state when no params provided', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(diffViewNotifierProvider());

      expect(state, const DiffViewState());
      expect(state.files, isEmpty);
      expect(state.loading, false);
      expect(state.error, isNull);
    });
  });
}
