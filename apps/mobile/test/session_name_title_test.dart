import 'dart:async';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/session_name_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;

class _TitleBridgeService extends BridgeService {
  _TitleBridgeService({
    required this.initialProjects,
    this.initialSessions = const [],
  });

  final ProjectsMessage initialProjects;
  final List<SessionInfo> initialSessions;
  final projectsController = StreamController<ProjectsMessage>.broadcast();
  final sessionsController = StreamController<List<SessionInfo>>.broadcast();

  @override
  ProjectsMessage get projectsState => initialProjects;

  @override
  Stream<ProjectsMessage> get projectsStream => projectsController.stream;

  @override
  List<SessionInfo> get sessions => initialSessions;

  @override
  Stream<List<SessionInfo>> get sessionList => sessionsController.stream;

  @override
  void dispose() {
    projectsController.close();
    sessionsController.close();
    super.dispose();
  }
}

void main() {
  testWidgets('uses the current custom Project name before the session list', (
    tester,
  ) async {
    final bridge = _TitleBridgeService(
      initialProjects: const ProjectsMessage(
        projects: [
          WorkspaceProject(
            id: 'project-1',
            name: 'Flutter apps',
            rootPaths: ['/workspace/ccpocket', '/workspace/api'],
            createdAt: '',
            updatedAt: '',
          ),
        ],
      ),
    );
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      provider.Provider<BridgeService>.value(
        value: bridge,
        child: const MaterialApp(
          home: Scaffold(
            body: SessionNameTitle(
              sessionId: 'pending-1',
              provider: Provider.claude,
              projectPath: '/workspace/ccpocket',
              workspace: SessionWorkspaceInfo(
                kind: 'project',
                projectId: 'project-1',
                projectName: 'Old name',
                rootPaths: ['/workspace/ccpocket', '/workspace/api'],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Flutter apps'), findsOneWidget);
    expect(find.text('ccpocket'), findsNothing);
  });

  testWidgets('keeps the Project name snapshot after catalog removal', (
    tester,
  ) async {
    final bridge = _TitleBridgeService(
      initialProjects: const ProjectsMessage(projects: []),
    );
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      provider.Provider<BridgeService>.value(
        value: bridge,
        child: const MaterialApp(
          home: Scaffold(
            body: SessionNameTitle(
              sessionId: 'pending-1',
              provider: Provider.claude,
              projectPath: '/workspace/ccpocket',
              workspace: SessionWorkspaceInfo(
                kind: 'project',
                projectId: 'project-removed',
                projectName: 'Removed workspace',
                rootPaths: ['/workspace/ccpocket', '/workspace/api'],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Removed workspace'), findsOneWidget);
    expect(find.text('ccpocket'), findsNothing);
  });

  group('title color follows the provider accent', () {
    Future<Color?> pumpTitle(
      WidgetTester tester, {
      required Provider titleProvider,
      required Brightness brightness,
      String? sessionName,
    }) async {
      final bridge = _TitleBridgeService(
        initialProjects: const ProjectsMessage(projects: []),
        initialSessions: [
          if (sessionName != null)
            SessionInfo(
              id: 'session-1',
              provider: titleProvider.value,
              projectPath: '/workspace/ccpocket',
              status: 'idle',
              createdAt: '',
              lastActivityAt: '',
              name: sessionName,
            ),
        ],
      );
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        provider.Provider<BridgeService>.value(
          value: bridge,
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
            home: Scaffold(
              body: SessionNameTitle(
                sessionId: 'session-1',
                provider: titleProvider,
                projectPath: '/workspace/ccpocket',
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text(sessionName ?? 'ccpocket'));
      return text.style?.color;
    }

    for (final brightness in Brightness.values) {
      for (final sessionName in [null, 'Fix login']) {
        final label = sessionName == null ? 'project name' : 'session name';

        testWidgets('Claude $label uses primary (${brightness.name})', (
          tester,
        ) async {
          final color = await pumpTitle(
            tester,
            titleProvider: Provider.claude,
            brightness: brightness,
            sessionName: sessionName,
          );
          final scheme = brightness == Brightness.dark
              ? AppTheme.darkTheme.colorScheme
              : AppTheme.lightTheme.colorScheme;
          expect(color, scheme.primary);
        });

        testWidgets('Codex $label uses secondary (${brightness.name})', (
          tester,
        ) async {
          final color = await pumpTitle(
            tester,
            titleProvider: Provider.codex,
            brightness: brightness,
            sessionName: sessionName,
          );
          final scheme = brightness == Brightness.dark
              ? AppTheme.darkTheme.colorScheme
              : AppTheme.lightTheme.colorScheme;
          expect(color, scheme.secondary);
        });
      }
    }
  });
}
