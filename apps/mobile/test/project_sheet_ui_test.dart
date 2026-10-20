import 'dart:async';

import 'package:ccpocket/features/project_setup/widgets/new_project_sheet.dart';
import 'package:ccpocket/features/projects/widgets/project_manager_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/widgets/project_sheet_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bridge extends BridgeService {
  final events = StreamController<ServerMessage>.broadcast();
  final browsed = <String>[];
  @override
  List<String> get allowedDirs => ['/workspace'];
  @override
  Stream<ServerMessage> get messages => events.stream;
  @override
  void requestProjects() {}
  @override
  void requestDirectoryListing(
    String path, {
    String? requestId,
    bool includeHidden = false,
  }) {
    browsed.add(path);
    scheduleMicrotask(
      () => events.add(
        DirectoryListingMessage(
          path: path,
          directories: const [],
          requestId: requestId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

Widget host(VoidCallback Function(BuildContext) action) => MaterialApp(
  theme: ThemeData.dark(),
  locale: const Locale('ja'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: action(context), child: const Text('Open')),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'creation has separated fields and a usable default source path',
    (tester) async {
      final bridge = _Bridge();
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        host(
          (context) =>
              () => showNewProjectSheet(context, bridge, []),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final name = find.byKey(const ValueKey('new_project_name_field'));
      final parent = find.byKey(const ValueKey('new_project_parent_field'));
      expect(
        tester.getTopLeft(parent).dy - tester.getBottomLeft(name).dy,
        greaterThanOrEqualTo(20),
      );
      expect(
        tester.widget<TextFormField>(parent).controller!.text,
        '/workspace',
      );
      final browse = find.byKey(
        const ValueKey('new_project_source_browse_button'),
      );
      await tester.ensureVisible(browse);
      await tester.tap(browse);
      await tester.pumpAndSettle();
      expect(bridge.browsed, ['/workspace']);
      expect(find.text('選択'), findsOneWidget);
      expect(find.text('ディレクトリを選択'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('directory_browser_select_action')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .state<FormFieldState<String>>(
              find.byKey(const ValueKey('new_project_source_field')),
            )
            .value,
        '/workspace',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small sheet dismisses keyboard on drag and keeps action visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final bridge = _Bridge();
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        host(
          (context) =>
              () => showNewProjectSheet(context, bridge, []),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('new_project_name_field')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('new_project_create_button')),
            )
            .dy,
        lessThanOrEqualTo(524),
      );
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.drag(
        find.byKey(const ValueKey('project_sheet_scroll')),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'multi-project manager and editor are sheets without automatic keyboard',
    (tester) async {
      final bridge = _Bridge();
      addTearDown(bridge.dispose);
      final cubit = WorkspaceProjectsCubit(
        const ProjectsMessage(projects: []),
        const Stream.empty(),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: host(
            (context) =>
                () => showProjectManagerSheet(
                  context: context,
                  bridge: bridge,
                  showHiddenDirectories: false,
                ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectSheetLayout), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      await tester.tap(find.byKey(const ValueKey('project_create_button')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(const ValueKey('project_name_field')), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const ValueKey('project_name_field')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.drag(
        find.byKey(const ValueKey('project_sheet_scroll')).last,
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('project_save_button')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('project_sheet_close_button')).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('project_create_button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
