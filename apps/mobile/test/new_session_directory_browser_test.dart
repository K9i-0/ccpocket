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
  final _projects = StreamController<ProjectsMessage>.broadcast();
  final includeHiddenRequests = <bool>[];
  ProjectsMessage _projectsState = const ProjectsMessage(projects: []);

  @override
  List<String> get allowedDirs => const ['/workspace'];

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  Stream<ProjectsMessage> get projectsStream => _projects.stream;

  @override
  ProjectsMessage get projectsState => _projectsState;

  @override
  void requestProjects() {}

  void emitProjects(ProjectsMessage state) {
    _projectsState = state;
    _projects.add(state);
  }

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
    _projects.close();
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

  testWidgets('restores a delayed Project selection by identity', (
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
    NewSessionParams? result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: const [],
                  initialParams: NewSessionParams(
                    projectPath: '/workspace/old-primary',
                    projectId: 'project-1',
                    workspaceKind: 'project',
                    provider: Provider.codex,
                  ),
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
    bridge.emitProjects(
      const ProjectsMessage(
        projects: [
          WorkspaceProject(
            id: 'project-1',
            name: 'Multi root',
            rootPaths: ['/workspace/primary', '/workspace/secondary'],
            createdAt: '2026-09-01T00:00:00.000Z',
            updatedAt: '2026-09-01T00:00:00.000Z',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final pathField = tester.widget<TextField>(
      find.byKey(const ValueKey('dialog_project_path')),
    );
    expect(pathField.controller?.text, '/workspace/primary');
    final projectTile = find.byKey(
      const ValueKey('workspace_project_project-1_tile'),
    );
    expect(projectTile, findsOneWidget);
    expect(
      find.descendant(
        of: projectTile,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );

    final startButton = find.byKey(const ValueKey('dialog_start_button'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    expect(result?.projectId, 'project-1');
    expect(result?.workspaceKind, 'project');
    expect(result?.projectPath, '/workspace/primary');
    expect(result?.additionalWritableRoots, ['/workspace/secondary']);
  });

  testWidgets('merges ccpocket Projects into recent projects', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final bridge = _DirectoryBrowserBridge();
    addTearDown(bridge.dispose);
    NewSessionParams? result;
    bridge.emitProjects(
      const ProjectsMessage(
        projects: [
          WorkspaceProject(
            id: 'project-1',
            name: 'Multi root',
            rootPaths: ['/workspace/primary', '/workspace/secondary'],
            createdAt: '2026-09-01T00:00:00.000Z',
            updatedAt: '2026-09-01T00:00:00.000Z',
          ),
        ],
      ),
    );
    final recentProjects = [
      for (var index = 0; index < 21; index++)
        (
          path: '/workspace/secondary/generated-$index',
          name: 'generated-$index',
        ),
      (path: '/workspace/primary', name: 'primary'),
      (path: '/workspace/plain', name: 'plain'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: recentProjects,
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

    expect(find.text('Recent Projects'), findsOneWidget);
    expect(find.text('Workspace'), findsNothing);
    final workspaceProjectTile = find.byKey(
      const ValueKey('workspace_project_project-1_tile'),
    );
    final recentFolderTile = find.byKey(
      const ValueKey('recent_project_/workspace/plain_tile'),
    );
    final primaryFolderTile = find.byKey(
      const ValueKey('workspace_primary_project-1_tile'),
    );
    expect(workspaceProjectTile, findsOneWidget);
    expect(primaryFolderTile, findsOneWidget);
    expect(recentFolderTile, findsOneWidget);
    expect(
      find.descendant(
        of: workspaceProjectTile,
        matching: find.byIcon(Icons.folder_copy_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: recentFolderTile,
        matching: find.byIcon(Icons.folder_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: primaryFolderTile,
        matching: find.byIcon(Icons.folder_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('recent_project_/workspace/secondary/generated-0_tile'),
      ),
      findsNothing,
    );

    await tester.tap(workspaceProjectTile);
    await tester.pumpAndSettle();
    final pathField = tester.widget<TextField>(
      find.byKey(const ValueKey('dialog_project_path')),
    );
    expect(pathField.controller?.text, '/workspace/primary');

    await tester.tap(primaryFolderTile);
    await tester.pumpAndSettle();
    final selectedPathField = tester.widget<TextField>(
      find.byKey(const ValueKey('dialog_project_path')),
    );
    expect(selectedPathField.controller?.text, '/workspace/primary');

    final startButton = find.byKey(const ValueKey('dialog_start_button'));
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();
    expect(result?.projectPath, '/workspace/primary');
    expect(result?.projectId, isNull);
    expect(result?.workspaceKind, isNull);
    expect(result?.additionalWritableRoots, isEmpty);
  });
}
