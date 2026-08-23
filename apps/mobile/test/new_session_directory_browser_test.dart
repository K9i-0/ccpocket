import 'dart:async';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DirectoryBrowserBridge extends BridgeService {
  final _messages = StreamController<ServerMessage>.broadcast();
  final includeHiddenRequests = <bool>[];

  @override
  List<String> get allowedDirs => const ['/workspace'];

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  void requestDirectoryListing(
    String path, {
    String? requestId,
    bool includeHidden = false,
  }) {
    includeHiddenRequests.add(includeHidden);
    scheduleMicrotask(() {
      if (_messages.isClosed) return;
      _messages.add(
        DirectoryListingMessage(
          path: path,
          directories: path == '/workspace'
              ? const [
                  DirectoryListingEntry(
                    name: 'ccpocket',
                    path: '/workspace/ccpocket',
                  ),
                ]
              : const [],
          requestId: requestId,
        ),
      );
    });
  }

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}

void main() {
  testWidgets('selects a project path from the new session browser', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final bridge = _DirectoryBrowserBridge();
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: const [],
                  initialParams: NewSessionParams(
                    projectPath: '/workspace',
                    provider: Provider.codex,
                  ),
                  showHiddenDirectories: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('dialog_project_path_browse_button')),
    );
    await tester.pumpAndSettle();
    expect(bridge.includeHiddenRequests, [isTrue]);
    await tester.tap(find.text('ccpocket'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('directory_browser_select_action')),
    );
    await tester.pumpAndSettle();

    final pathField = tester.widget<TextField>(
      find.byKey(const ValueKey('dialog_project_path')),
    );
    expect(pathField.controller?.text, '/workspace/ccpocket');
  });
}
