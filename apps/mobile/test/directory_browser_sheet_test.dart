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

  _DirectoryBrowserBridge({this.autoRespond = true});

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  void requestDirectoryListing(String path, {String? requestId}) {
    requests.add(path);
    requestIds.add(requestId);
    if (!autoRespond) return;
    scheduleMicrotask(() {
      if (_messages.isClosed) return;
      if (path == '/outside') {
        _messages.add(
          const ErrorMessage(
            message: 'Directory path is outside the allowed roots',
            errorCode: 'directory_not_allowed',
            path: '/outside',
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

    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();
    expect(bridge.requests, ['/workspace', '/workspace/alpha']);
    expect(find.text('No subdirectories'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('directory_browser_select_action')),
    );
    await tester.pumpAndSettle();
    expect(await result, '/workspace/alpha');
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
            initialPath: '/outside',
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
    expect(bridge.requests, isEmpty);
  });

  testWidgets(
    'ignores a directory response for another request',
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
            );
          },
        ),
      );
      await tester.tap(find.text('Open browser'));
      await tester.pumpAndSettle();
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
    },
  );
}
