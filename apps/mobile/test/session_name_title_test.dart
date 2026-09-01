import 'dart:async';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/widgets/session_name_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart' as provider;

class _TitleBridgeService extends BridgeService {
  _TitleBridgeService({required this.initialProjects});

  final ProjectsMessage initialProjects;
  final projectsController = StreamController<ProjectsMessage>.broadcast();
  final sessionsController = StreamController<List<SessionInfo>>.broadcast();

  @override
  ProjectsMessage get projectsState => initialProjects;

  @override
  Stream<ProjectsMessage> get projectsStream => projectsController.stream;

  @override
  List<SessionInfo> get sessions => const [];

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
}
