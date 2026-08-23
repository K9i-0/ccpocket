import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/widgets/directory_browser_sheet.dart';

class _DirectoryBrowserBridge extends BridgeService {
  final bool autoRespond;
  final _messages = StreamController<ServerMessage>.broadcast();
  final requests = <String>[];
  final requestIds = <String?>[];
  final includeHiddenRequests = <bool>[];

  _DirectoryBrowserBridge({this.autoRespond = true});

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  void requestDirectoryListing(
    String path, {
    String? requestId,
    bool includeHidden = false,
  }) {
    requests.add(path);
    requestIds.add(requestId);
    includeHiddenRequests.add(includeHidden);
    if (!autoRespond) return;
    scheduleMicrotask(() {
      if (_messages.isClosed) return;
      if (path == '/workspace/denied') {
        _messages.add(
          ErrorMessage(
            message: 'Directory path is outside the allowed roots',
            errorCode: 'directory_not_allowed',
            path: path,
            requestId: requestId,
          ),
        );
        return;
      }
      final directories = path == '/workspace'
          ? const [
              DirectoryListingEntry(name: 'alpha', path: '/workspace/alpha'),
              DirectoryListingEntry(name: 'beta', path: '/workspace/beta'),
            ]
          : const <DirectoryListingEntry>[];
      _messages.add(
        DirectoryListingMessage(
          path: path,
          directories: directories,
          requestId: requestId,
        ),
      );
    });
  }

  void emit(ServerMessage message) => _messages.add(message);

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}

Widget _testApp({required VoidCallback onOpen}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: onOpen,
          child: const Text('Open browser'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('browses child directories and returns the selected path', (
    tester,
  ) async {
    final bridge = _DirectoryBrowserBridge();
    addTearDown(bridge.dispose);
    Future<String?>? result;

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          result = showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: '/workspace',
            allowedRoots: const ['/workspace'],
          );
        },
      ),
    );

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(bridge.includeHiddenRequests, [isFalse]);
    var upButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('directory_browser_up_button')),
    );
    expect(upButton.onPressed, isNull);

    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(bridge.requests, ['/workspace', '/workspace/alpha']);
    expect(find.text('No subdirectories'), findsOneWidget);
    upButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('directory_browser_up_button')),
    );
    expect(upButton.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey('directory_browser_select_action')),
    );
    await tester.pumpAndSettle();
    expect(await result, '/workspace/alpha');
  });

  testWidgets('requests hidden directories when enabled', (tester) async {
    final bridge = _DirectoryBrowserBridge();
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: '/workspace',
            allowedRoots: const ['/workspace'],
            includeHidden: true,
          );
        },
      ),
    );

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();

    expect(bridge.includeHiddenRequests, [isTrue]);
  });

  testWidgets('shows a bridge security error and keeps selection disabled', (
    tester,
  ) async {
    final bridge = _DirectoryBrowserBridge();
    addTearDown(bridge.dispose);
    Future<String?>? result;

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          result = showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: '/workspace/denied',
            allowedRoots: const ['/workspace'],
          );
        },
      ),
    );

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    expect(
      find.text('Directory path is outside the allowed roots'),
      findsOneWidget,
    );
    final selectButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('directory_browser_select_action')),
    );
    expect(selectButton.onPressed, isNull);
    expect(result, isNotNull);
    expect(bridge.requests, ['/workspace/denied']);
  });

  testWidgets('ignores a directory response for another request', (
    tester,
  ) async {
    final bridge = _DirectoryBrowserBridge(autoRespond: false);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: '/workspace',
            allowedRoots: const ['/workspace'],
          );
        },
      ),
    );
    await tester.tap(find.text('Open browser'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(bridge.requestIds, hasLength(1));
    final requestId = bridge.requestIds.single!;

    bridge.emit(
      const DirectoryListingMessage(
        path: '/workspace',
        requestId: 'stale-request',
        directories: [
          DirectoryListingEntry(name: 'stale', path: '/workspace/stale'),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('stale'), findsNothing);

    bridge.emit(
      DirectoryListingMessage(
        path: '/workspace',
        requestId: requestId,
        directories: const [
          DirectoryListingEntry(name: 'current', path: '/workspace/current'),
        ],
      ),
    );
    await tester.pump();
    expect(find.text('current'), findsOneWidget);
  });

  testWidgets(
    'shows an update hint when a legacy bridge rejects hidden listing',
    (tester) async {
      final bridge = _DirectoryBrowserBridge(autoRespond: false);
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        _testApp(
          onOpen: () {
            showDirectoryBrowserSheet(
              context: tester.element(find.text('Open browser')),
              bridge: bridge,
              initialPath: '/workspace',
              allowedRoots: const ['/workspace'],
              includeHidden: true,
            );
          },
        ),
      );
      await tester.tap(find.text('Open browser'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(bridge.includeHiddenRequests, [isTrue]);

      bridge.emit(
        const ErrorMessage(
          message: 'another_action',
          errorCode: 'unsupported_message',
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      bridge.emit(
        const ErrorMessage(
          message: 'list_directory',
          errorCode: 'unsupported_message',
        ),
      );
      await tester.pump();
      expect(
        find.text(
          'This feature requires a newer Bridge server. '
          'Update Bridge and try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('compares UNC allowed roots case-insensitively', (tester) async {
    final bridge = _DirectoryBrowserBridge(autoRespond: false);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: r'\\server\share\project',
            allowedRoots: const [r'\\SERVER\SHARE'],
          );
        },
      ),
    );
    await tester.tap(find.text('Open browser'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(bridge.requests, [r'\\server\share\project']);
  });

  testWidgets('disables upward navigation at a UNC allowed root', (
    tester,
  ) async {
    final bridge = _DirectoryBrowserBridge(autoRespond: false);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: r'\\server\share',
            allowedRoots: const [r'\\SERVER\SHARE'],
          );
        },
      ),
    );
    await tester.tap(find.text('Open browser'));
    await tester.pump(const Duration(milliseconds: 500));

    final upButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('directory_browser_up_button')),
    );
    expect(upButton.onPressed, isNull);
  });

  testWidgets('preserves backslashes in POSIX path names', (tester) async {
    final bridge = _DirectoryBrowserBridge(autoRespond: false);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: r'/workspace\escape',
            allowedRoots: const ['/workspace'],
          );
        },
      ),
    );
    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();

    expect(bridge.requests, isEmpty);
    expect(
      find.text('Directory path is outside the allowed roots'),
      findsOneWidget,
    );
  });

  testWidgets('normalizes extended UNC allowed roots', (tester) async {
    final bridge = _DirectoryBrowserBridge(autoRespond: false);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      _testApp(
        onOpen: () {
          showDirectoryBrowserSheet(
            context: tester.element(find.text('Open browser')),
            bridge: bridge,
            initialPath: r'\\server\share\project',
            allowedRoots: const [r'\\?\UNC\SERVER\SHARE'],
          );
        },
      ),
    );
    await tester.tap(find.text('Open browser'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(bridge.requests, [r'\\server\share\project']);
  });
}
