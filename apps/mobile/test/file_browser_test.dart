import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/features/file_browser/file_browser_history.dart';
import 'package:ccpocket/features/file_browser/file_browser_reference.dart';
import 'package:ccpocket/features/file_browser/file_browser_view.dart';
import 'package:ccpocket/features/file_browser/state/file_browser_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/utils/composer_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class BrowserTestBridge extends BridgeService {
  final events = StreamController<ServerMessage>.broadcast(sync: true);
  final contents = StreamController<FileContentMessage>.broadcast(sync: true);
  final indexes = StreamController<FileListMessage>.broadcast(sync: true);
  final sent = <ClientMessage>[];
  @override
  Stream<ServerMessage> get messages => events.stream;
  @override
  Stream<FileContentMessage> get fileContent => contents.stream;
  @override
  Stream<FileListMessage> fileListMessagesForProject(String project) =>
      indexes.stream;
  @override
  void send(ClientMessage message) => sent.add(message);
  String get directoryRequest =>
      jsonDecode(
            sent
                .lastWhere(
                  (m) => jsonDecode(m.toJson())['type'] == 'list_directory',
                )
                .toJson(),
          )['requestId']
          as String;
  void directory(
    String path, {
    List<String> files = const [],
    List<String> directories = const [],
    String? id,
  }) {
    events.add(
      DirectoryListingMessage(
        path: '/project${path.isEmpty ? '' : '/$path'}',
        requestId: id ?? directoryRequest,
        directories: directories
            .map(
              (name) => DirectoryListingEntry(
                name: name,
                path: '/project/$path/$name'.replaceAll('//', '/'),
              ),
            )
            .toList(),
        files: files
            .map(
              (name) => DirectoryListingEntry(
                name: name,
                path: '/project/$path/$name'.replaceAll('//', '/'),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  void dispose() {
    events.close();
    contents.close();
    indexes.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'normalizes absolute, relative, trailing slash, Windows and outside paths',
    () {
      expect(normalizeBrowserPath('/project', '/project/lib/'), 'lib');
      expect(normalizeBrowserPath('/project', './lib/../assets'), 'assets');
      expect(normalizeBrowserPath('/project', '../other'), '/other');
      expect(normalizeBrowserPath(r'C:\repo', r'C:\repo\lib\'), 'lib');
      expect(isBrowserRelative(r'C:\other\foo'), false);
    },
  );
  test('searches multiple terms and disambiguates paths including folders', () {
    final results = searchBrowserEntries([
      'lib/chat/cubit.dart',
      'test/chat/cubit.dart',
      'lib/chat/view.dart',
      'empty/',
    ], 'chat cubit');
    expect(results.map((e) => e.relativePath), [
      'lib/chat/cubit.dart',
      'test/chat/cubit.dart',
    ]);
    expect(searchBrowserEntries(['empty/'], 'empty').single.isDirectory, true);
  });

  group('browser navigation and responses', () {
    late BrowserTestBridge bridge;
    late FileBrowserCubit cubit;
    setUp(() {
      bridge = BrowserTestBridge();
      cubit = FileBrowserCubit(
        bridge: bridge,
        projectPath: '/project',
        initialFiles: ['lib/chat/cubit.dart', 'test/chat/cubit.dart'],
      );
    });
    tearDown(() async {
      await cubit.close();
      bridge.dispose();
    });
    test('uses real contents including empty and unindexed directories', () {
      bridge.directory(
        '',
        directories: ['empty', '.cache'],
        files: ['ignored.txt'],
      );
      expect(cubit.state.entries.map((e) => e.name), [
        'empty',
        '.cache',
        'ignored.txt',
      ]);
      cubit.openDirectory('empty');
      bridge.directory('empty');
      expect(cubit.state.location.directory, 'empty');
      expect(cubit.state.entries, isEmpty);
      expect(cubit.state.loading, false);
    });
    test('ignores old replies after rapid navigation', () {
      final first = bridge.directoryRequest;
      cubit.openDirectory('lib');
      bridge.directory('', files: ['wrong.txt'], id: first);
      expect(cubit.state.location.directory, 'lib');
      expect(cubit.state.entries.any((e) => e.name == 'wrong.txt'), false);
      bridge.directory('lib', files: ['right.txt']);
      expect(cubit.state.entries.single.name, 'right.txt');
    });
    test('returns through parent, preview, search and original directory', () {
      bridge.directory('');
      cubit.setQuery('chat cubit');
      cubit.openFile('lib/chat/cubit.dart');
      cubit.showParent();
      expect(cubit.state.location.directory, 'lib/chat');
      expect(cubit.back(), true);
      expect(cubit.state.location.file, 'lib/chat/cubit.dart');
      cubit.back();
      expect(cubit.state.location.query, 'chat cubit');
      expect(cubit.state.location.file, null);
      expect(cubit.state.entries.length, 2);
      cubit.back();
      expect(cubit.state.location.query, '');
      expect(cubit.state.location.directory, '');
    });
    test('resolves an unknown file by directory stat without guessing its extension', () {
      cubit.openTarget('unindexed/LICENSE');
      bridge.events.add(
        ErrorMessage(
          message: 'Selected path is not a directory',
          errorCode: 'not_a_directory',
          requestId: bridge.directoryRequest,
        ),
      );
      expect(cubit.state.location.file, 'unindexed/LICENSE');
    });
    test('legacy unsupported replies stop loading and keep index fallback', () {
      bridge.events.add(
        const ErrorMessage(
          message: 'list_directory',
          errorCode: 'unsupported_message',
        ),
      );
      expect(cubit.state.loading, false);
      expect(cubit.state.legacyListing, true);
      expect(cubit.state.entries, isNotEmpty);
    });
    test(
      'missing files field never pretends to be a complete empty listing',
      () {
        bridge.events.add(
          DirectoryListingMessage(
            path: '/project',
            directories: const [],
            requestId: bridge.directoryRequest,
          ),
        );
        expect(cubit.state.legacyListing, true);
      },
    );
    test('legacy target probing still opens unindexed files', () {
      cubit.openTarget('ignored/LICENSE');
      bridge.events.add(
        const ErrorMessage(
          message: 'list_directory',
          errorCode: 'unsupported_message',
        ),
      );
      final request = jsonDecode(bridge.sent.last.toJson());
      expect(request.containsKey('includeFiles'), false);
      bridge.events.add(
        ErrorMessage(
          message: 'not directory',
          errorCode: 'not_a_directory',
          requestId: bridge.directoryRequest,
        ),
      );
      expect(cubit.state.location.file, 'ignored/LICENSE');
      expect(cubit.state.location.directory, 'ignored');
      expect(
        cubit.state.entries.any((entry) => entry.relativePath == 'lib'),
        false,
      );
    });
    test(
      'direct preview fetches siblings and ignores late file-directory probe',
      () async {
        final preview = FileBrowserCubit(
          bridge: bridge,
          projectPath: '/project',
          initialFiles: ['lib/main.dart'],
          initialTarget: 'lib/main.dart:42',
        );
        expect(preview.state.location.line, 42);
        bridge.directory(
          'lib',
          directories: ['empty'],
          files: ['main.dart', 'ignored.txt'],
        );
        expect(preview.state.entries.map((entry) => entry.name), [
          'empty',
          'main.dart',
          'ignored.txt',
        ]);
        expect(preview.state.location.file, 'lib/main.dart');
        await preview.close();
      },
    );
    test('parent cannot escape the current project', () {
      cubit.openDirectory('../private');
      expect(cubit.state.error, 'directory_not_allowed');
      expect(cubit.state.location.directory, '');
    });
    test('recent files are shared between entry points and isolated by project/bridge', () {
      cubit.openFile('lib/chat/cubit.dart');
      expect(FileBrowserHistory.forProject(bridge, '/project').value, [
        'lib/chat/cubit.dart',
      ]);
      expect(FileBrowserHistory.forProject(bridge, '/other').value, isEmpty);
      final other = BrowserTestBridge();
      expect(FileBrowserHistory.forProject(other, '/project').value, isEmpty);
      other.dispose();
    });
  });

  test('captured references never reach a replacement composer', () {
    final bridge = BrowserTestBridge();
    final first = <String>[];
    final second = <String>[];
    final unregister = FileBrowserReferences.register(
      bridge,
      'session',
      first.add,
    );
    final captured = FileBrowserReferences.capture(bridge, 'session')!;
    unregister();
    FileBrowserReferences.register(bridge, 'session', second.add);
    captured('wrong.dart');
    expect(first, isEmpty);
    expect(second, isEmpty);
    bridge.dispose();
  });
  testWidgets(
    'inserting an unindexed reference refreshes same-config token decoration',
    (tester) async {
      final controller = ComposerTextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.updateTokenState(
                config: const ComposerTokenConfig(provider: Provider.codex),
                palette: ComposerTokenPalette.fromTheme(Theme.of(context)),
              );
              return Scaffold(body: TextField(controller: controller));
            },
          ),
        ),
      );
      controller.insertFileReference('new folder/');
      await tester.pump();
      // Controller renders the explicit browser reference using the file palette.
      final context = tester.element(find.byType(TextField));
      controller.updateTokenState(
        config: const ComposerTokenConfig(provider: Provider.codex),
        palette: ComposerTokenPalette.fromTheme(Theme.of(context)),
      );
      final span = controller.buildTextSpan(
        context: context,
        withComposing: false,
      );
      expect(span.children, isNotEmpty);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  test('reference insertion preserves draft and quotes whitespace', () {
    final controller = ComposerTextEditingController()
      ..text = 'Please review this';
    controller.selection = const TextSelection.collapsed(offset: 7);
    controller.insertFileReference('docs/my file.md');
    expect(controller.text, 'Please @"docs/my file.md" review this');
    final tokens = parseComposerTokens(
      controller.text,
      const ComposerTokenConfig(
        provider: Provider.codex,
        fileMentions: {'"docs/my file.md"'},
      ),
    );
    expect(tokens.single.rawText, '@"docs/my file.md"');
    expect(tokens.single.isValid, true);
    controller.dispose();
  });

  testWidgets('directory timeout retries and rejects the expired response', (
    tester,
  ) async {
    final bridge = BrowserTestBridge();
    final cubit = FileBrowserCubit(
      bridge: bridge,
      projectPath: '/project',
      requestTimeout: const Duration(seconds: 1),
    );
    final expired = bridge.directoryRequest;
    await tester.pump(const Duration(seconds: 2));
    expect(cubit.state.error, 'timeout');
    cubit.retry();
    expect(bridge.directoryRequest, isNot(expired));
    bridge.directory('', files: ['late.txt'], id: expired);
    expect(cubit.state.entries, isEmpty);
    bridge.directory('', files: ['fresh.txt']);
    expect(cubit.state.entries.single.name, 'fresh.txt');
    unawaited(cubit.close());
    await tester.pump();
    bridge.dispose();
  });

  testWidgets(
    'narrow Explorer keeps deep breadcrumbs and close controls usable',
    (tester) async {
      tester.view.physicalSize = const Size(236, 402);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = BrowserTestBridge();
      final cubit = FileBrowserCubit(
        bridge: bridge,
        projectPath: '/project',
        initialDirectory: 'src/components/checkout/payment',
        initialFiles: ['src/components/checkout/payment/main.dart'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: FileBrowserView(
              embedded: true,
              onClose: () {},
              onAddToChat: (_) {},
              onUpload: () {},
            ),
          ),
        ),
      );
      bridge.directory('src/components/checkout/payment', files: ['main.dart']);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('close_explore_pane_button')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find
            .byKey(
              const ValueKey(
                'explore_entry_src/components/checkout/payment/main.dart',
              ),
            )
            .hitTestable(),
        findsOneWidget,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.enterText(
        find.byKey(const ValueKey('browser_search_field')),
        'main',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find
            .byKey(
              const ValueKey(
                'explore_entry_src/components/checkout/payment/main.dart',
              ),
            )
            .hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      unawaited(cubit.close());
      await tester.pump();
      bridge.dispose();
    },
  );

  testWidgets(
    'folder history restores list position and header close is explicit',
    (tester) async {
      final bridge = BrowserTestBridge();
      // Most entries are not present in the search index.
      final files = ['folder20/file.txt'];
      final cubit = FileBrowserCubit(
        bridge: bridge,
        projectPath: '/project',
        initialFiles: files,
      );
      var closed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: FileBrowserView(onClose: () => closed = true),
          ),
        ),
      );
      bridge.directory(
        '',
        directories: [for (var i = 0; i < 60; i++) 'folder$i'],
      );
      await tester.pump();
      await tester.drag(
        find.byKey(const ValueKey('explore_list')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      final before = tester
          .widget<ListView>(find.byKey(const ValueKey('explore_list')))
          .controller!
          .offset;
      expect(before, greaterThan(0));
      cubit.openDirectory('folder20');
      bridge.directory('folder20', files: ['file.txt']);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('explore_list')))
            .controller!
            .offset,
        0,
      );
      cubit.back();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('explore_list')))
            .controller!
            .offset,
        before,
      );
      bridge.directory(
        '',
        directories: [for (var i = 0; i < 60; i++) 'folder$i'],
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListView>(find.byKey(const ValueKey('explore_list')))
            .controller!
            .offset,
        before,
      );
      await tester.drag(
        find.byKey(const ValueKey('browser_header')),
        const Offset(0, 100),
      );
      await tester.pump();
      expect(closed, false);
      await tester.tap(find.byKey(const ValueKey('file_peek_close_button')));
      expect(closed, true);
      await tester.pumpWidget(const SizedBox());
      unawaited(cubit.close());
      await tester.pump();
      bridge.dispose();
    },
  );

  testWidgets(
    'file loading timeout exposes retry and renders the requested line',
    (tester) async {
      final bridge = BrowserTestBridge();
      final cubit = FileBrowserCubit(
        bridge: bridge,
        projectPath: '/project',
        initialFiles: ['main.dart'],
        initialTarget: 'main.dart:45',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: FileBrowserView(onClose: () {}),
          ),
        ),
      );
      bridge.directory('', files: ['main.dart']);
      await tester.pump(const Duration(seconds: 21));
      expect(
        find.byKey(const ValueKey('file_peek_retry_button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('file_peek_retry_button')));
      await tester.pump();
      bridge.contents.add(
        FileContentMessage(
          filePath: 'main.dart',
          content: List.generate(100, (i) => 'line ${i + 1}').join('\n'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('file_peek_retry_button')),
        findsNothing,
      );
      final scroller = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView).first,
      );
      expect(scroller.controller!.offset, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      unawaited(cubit.close());
      await tester.pump();
      bridge.dispose();
    },
  );

  for (final width in [390.0, 1100.0]) {
    testWidgets('search preview back and close at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = BrowserTestBridge();
      final cubit = FileBrowserCubit(
        bridge: bridge,
        projectPath: '/project',
        initialFiles: ['lib/main.dart'],
      );
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: FileBrowserView(onClose: () => closed++),
          ),
        ),
      );
      bridge.directory('', directories: ['lib']);
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('browser_search_field')),
        'main',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('explore_entry_lib/main.dart')),
      );
      await tester.pump();
      expect(cubit.state.location.file, 'lib/main.dart');
      expect(
        find.byKey(const ValueKey('file_peek_close_button')),
        findsOneWidget,
      );
      final closeRect = tester.getRect(
        find.byKey(const ValueKey('file_peek_close_button')),
      );
      final headerRect = tester.getRect(
        find.byKey(const ValueKey('browser_header')),
      );
      expect(closeRect.left, headerRect.left);
      expect(closeRect.center.dy, headerRect.center.dy);
      expect(tester.takeException(), null);
      await tester.tap(find.byKey(const ValueKey('browser_back_button')));
      await tester.pump();
      expect(cubit.state.location.query, 'main');
      expect(
        find.byKey(const ValueKey('explore_entry_lib/main.dart')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('file_peek_close_button')));
      await tester.pump();
      expect(closed, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(closed, 2);
      await tester.pumpWidget(const SizedBox());
      unawaited(cubit.close());
      await tester.pump();
      bridge.dispose();
    });
  }
}
