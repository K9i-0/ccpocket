import 'package:ccpocket/features/workspace/state/workspace_destination.dart';
import 'package:ccpocket/features/workspace/state/workspace_navigation_cubit.dart';
import 'package:ccpocket/features/workspace/state/workspace_navigation_state.dart';
import 'package:ccpocket/features/workspace/widgets/workspace_pane_navigator.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live identity and reveal preserve the session entry and tool', () {
    final navigation = WorkspaceNavigationCubit();
    addTearDown(navigation.close);
    navigation.selectSession(
      const WorkspaceSessionSelection(
        sessionId: 'pending',
        provider: Provider.codex,
        isPending: true,
      ),
    );
    final entry = navigation.state.sessionEntry;
    navigation.openTool(const GalleryToolPaneData(sessionId: 'live'));
    navigation.updateLiveSession('pending', 'live');
    navigation.openOverlay(WorkspaceCenterOverlay.settings);
    navigation.selectSession(
      const WorkspaceSessionSelection(
        sessionId: 'live',
        provider: Provider.codex,
      ),
    );
    expect(navigation.state.sessionEntry, entry);
    expect(navigation.state.selection!.sessionId, 'pending');
    expect(navigation.state.liveSessionId, 'live');
    expect(navigation.state.overlay, WorkspaceCenterOverlay.none);
    expect(navigation.state.tool, isA<GalleryToolPaneData>());
    expect(navigation.state.centerInFront, isTrue);
  });

  test(
    'late removal of a replaced or reset route cannot close its successor',
    () {
      final navigation = WorkspaceNavigationCubit();
      addTearDown(navigation.close);
      navigation.selectSession(const WorkspaceSessionSelection(sessionId: 'a'));
      final a = navigation.state.sessionEntry;
      navigation.reset();
      navigation.selectSession(const WorkspaceSessionSelection(sessionId: 'b'));
      navigation.closeSession(entry: a);
      expect(navigation.state.selection!.sessionId, 'b');
      navigation.openTool(const GalleryToolPaneData(sessionId: 'a'));
      final tool = navigation.state.toolEntry;
      navigation.openTool(const GalleryToolPaneData(sessionId: 'b'));
      navigation.closeTool(entry: tool);
      expect(navigation.state.tool!.sessionId, 'b');
      navigation.openOverlay(WorkspaceCenterOverlay.settings);
      final overlay = navigation.state.overlayEntry;
      navigation.openOverlay(WorkspaceCenterOverlay.globalGallery);
      navigation.closeOverlay(entry: overlay);
      expect(navigation.state.overlay, WorkspaceCenterOverlay.globalGallery);
      navigation.updateLiveSession('a', 'stale');
      expect(navigation.state.liveSessionId, 'b');
    },
  );

  testWidgets(
    'permanent pane retains editor state, selection and focus across widths and overlays',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_Harness(key: key));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'unsent draft');
      final editor = tester.widget<TextField>(find.byType(TextField));
      editor.controller!.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      editor.focusNode!.requestFocus();
      await tester.pump();
      for (final compact in [false, true, false, true]) {
        key.currentState!.change(compact: compact);
        await tester.pumpAndSettle();
        final current = tester.widget<TextField>(find.byType(TextField));
        expect(identical(current.controller, editor.controller), isTrue);
        expect(current.controller!.text, 'unsent draft');
        expect(
          current.controller!.selection,
          const TextSelection(baseOffset: 2, extentOffset: 7),
        );
        expect(current.focusNode!.hasFocus, isTrue);
      }
      key.currentState!.change(overlay: true);
      await tester.pumpAndSettle();
      key.currentState!.change(compact: false);
      await tester.pumpAndSettle();
      key.currentState!.change(overlay: false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(editor.controller),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact swipe can cancel and complete without replacing editor',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_Harness(key: key));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'retain on cancel');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-90, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(controller),
      );
      await tester.dragFrom(const Offset(1, 200), const Offset(650, 0));
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, isFalse);
      expect(find.text('sessions'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'wide-created route uses a real compact pop animation after resize',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_Harness(key: key, initialCompact: false));
      await tester.pumpAndSettle();
      key.currentState!.change(compact: true);
      await tester.pumpAndSettle();
      key.currentState!.navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resize during a canceled back gesture keeps route and releases gesture',
    (tester) async {
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_Harness(key: key));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(1, 200));
      await gesture.moveBy(const Offset(70, 0));
      await tester.pump();
      key.currentState!.change(compact: false);
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, isTrue);
      expect(
        key.currentState!.navigator.currentState!.userGestureInProgress,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final compact in [true, false]) {
      testWidgets(
        'system back resolves nested pages on $platform with compact=$compact',
        (tester) async {
          final key = GlobalKey<_HarnessState>();
          await tester.pumpWidget(
            _Harness(key: key, initialCompact: compact, platform: platform),
          );
          await tester.pumpAndSettle();
          key.currentState!.change(overlay: true);
          await tester.pumpAndSettle();
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(key.currentState!.overlay, isFalse);
          expect(key.currentState!.selected, isTrue);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(key.currentState!.selected, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _Harness extends StatefulWidget {
  const _Harness({
    super.key,
    this.initialCompact = true,
    this.platform = TargetPlatform.iOS,
  });
  final TargetPlatform platform;
  final bool initialCompact;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final navigator = GlobalKey<NavigatorState>();
  late bool compact = widget.initialCompact;
  bool selected = true;
  bool overlay = false;
  void change({bool? compact, bool? overlay}) => setState(() {
    this.compact = compact ?? this.compact;
    this.overlay = overlay ?? this.overlay;
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData(platform: widget.platform),
    home: Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Colors.white, child: Text('sessions')),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          left: compact ? 0 : 260,
          right: 0,
          child: WorkspacePaneNavigator(
            navigatorKey: navigator,
            compact: compact,
            active: selected || overlay,
            pages: [
              if (selected)
                WorkspacePanePage(
                  key: const ValueKey('editor'),
                  compact: compact,
                  child: const _Editor(),
                ),
              if (overlay)
                WorkspacePanePage(
                  key: const ValueKey('overlay'),
                  compact: compact,
                  child: const Scaffold(body: Text('settings')),
                ),
            ],
            onDidRemovePage: (page) => setState(() {
              if (page.key == const ValueKey('editor')) selected = false;
              if (page.key == const ValueKey('overlay')) overlay = false;
            }),
          ),
        ),
      ],
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor();
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final controller = TextEditingController();
  final focus = FocusNode();
  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextField(controller: controller, focusNode: focus),
    ),
  );
}
