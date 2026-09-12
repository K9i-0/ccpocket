import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_input_with_overlays.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/sketch/sketch_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_screen/helpers/chat_test_helpers.dart' show MockBridgeService;

const _document =
    '{"version":1,"width":600,"height":800,"background":4294967295,'
    '"drawing":{"schemaVersion":1,"drawables":[]}}';
const _editedDocument =
    '{"version":1,"width":600,"height":800,"background":4278190080,'
    '"drawing":{"schemaVersion":1,"drawables":[]}}';

final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aBVkAAAAASUVORK5CYII=',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  const nativePasteChannel = MethodChannel('ccpocket/native_paste_bridge');
  late MockBridgeService bridge;
  late DraftService drafts;
  late SharedPreferences prefs;
  late TextEditingController input;
  late ValueNotifier<String> sessionId;
  late GlobalKey<NavigatorState> navigator;
  late StreamingStateCubit streaming;
  late Map<String, ChatSessionCubit> sessions;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'settings_open_gallery_directly': true,
    });
    prefs = await SharedPreferences.getInstance();
    drafts = DraftService(prefs);
    bridge = MockBridgeService();
    input = TextEditingController();
    sessionId = ValueNotifier('session-a');
    navigator = GlobalKey<NavigatorState>();
    streaming = StreamingStateCubit();
    sessions = {
      for (final id in ['session-a', 'session-b'])
        id: ChatSessionCubit(
          sessionId: id,
          bridge: bridge,
          streamingCubit: streaming,
        ),
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativePasteChannel, (_) async => null);
  });

  tearDown(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pickerChannel, null);
    messenger.setMockMethodCallHandler(nativePasteChannel, null);
    for (final cubit in sessions.values) {
      await cubit.close();
    }
    await streaming.close();
    bridge.dispose();
    input.dispose();
    sessionId.dispose();
  });

  void saveImages(
    String id,
    int count, {
    Map<int, String> sketchDocuments = const {},
  }) {
    drafts.saveImageDraft(id, [
      for (var index = 0; index < count; index++)
        (bytes: Uint8List.fromList(_pngBytes), mimeType: 'image/png'),
    ], sketchDocuments: sketchDocuments);
  }

  Future<void> pumpComposer(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<BridgeService>.value(value: bridge),
            RepositoryProvider<DraftService>.value(value: drafts),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(prefs)),
              BlocProvider<FileListCubit>(
                create: (_) => FileListCubit(const [], bridge.fileList),
              ),
            ],
            child: ValueListenableBuilder<String>(
              valueListenable: sessionId,
              builder: (_, id, _) => BlocProvider<ChatSessionCubit>.value(
                value: sessions[id]!,
                child: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: ChatInputWithOverlays(
                      sessionId: id,
                      status: ProcessStatus.idle,
                      onGoToLatest: () {},
                      inputController: input,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ChatInputBar composer(WidgetTester tester) =>
      tester.widget<ChatInputBar>(find.byType(ChatInputBar));

  Future<void> returnSketch(WidgetTester tester) async {
    navigator.currentState!.pop<SketchResult>((
      bytes: Uint8List.fromList(_pngBytes),
      documentJson: _editedDocument,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'restored sketch follows removal and keeps its document when a photo is added',
    (tester) async {
      saveImages('session-a', 3, sketchDocuments: {1: _document});
      // Recreate the service to exercise persisted attachment restoration.
      drafts = DraftService(prefs);
      await pumpComposer(tester);
      expect(composer(tester).editableSketchIndices, {1});

      await tester.tap(find.byKey(const ValueKey('remove_attached_image_0')));
      await tester.pumpAndSettle();
      expect(composer(tester).attachedImages, hasLength(2));
      expect(composer(tester).editableSketchIndices, {0});
      expect(drafts.getSketchDocuments('session-a'), {0: _document});

      final directory = Directory.systemTemp.createTempSync('sketch-gallery-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final photo = File('${directory.path}/photo.png')
        ..writeAsBytesSync(_pngBytes);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pickerChannel, (call) async {
            expect(call.method, 'pickMultiImage');
            return [photo.path];
          });
      final pickImage =
          composer(tester).onAttachImage! as Future<void> Function();
      await tester.runAsync(pickImage);
      await tester.pumpAndSettle();
      expect(composer(tester).attachedImages, hasLength(3));
      expect(composer(tester).editableSketchIndices, {0});
      expect(DraftService(prefs).getSketchDocuments('session-a'), {
        0: _document,
      });

      await tester.tap(find.byKey(const ValueKey('attached_image_0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SketchScreen>(find.byType(SketchScreen))
            .initialDocumentJson,
        _document,
      );
      await returnSketch(tester);
      expect(composer(tester).attachedImages, hasLength(3));
      expect(drafts.getSketchDocuments('session-a'), {0: _editedDocument});
      expect(bridge.sentMessages, isEmpty);
    },
  );

  testWidgets('five attachments allow editing a sketch but block a sixth', (
    tester,
  ) async {
    saveImages('session-a', 5, sketchDocuments: {0: _document});
    await pumpComposer(tester);

    await tester.tap(find.byKey(const ValueKey('attached_image_0')));
    await tester.pumpAndSettle();
    expect(find.byType(SketchScreen), findsOneWidget);
    await returnSketch(tester);
    expect(composer(tester).attachedImages, hasLength(5));
    expect(drafts.getSketchDocuments('session-a'), {0: _editedDocument});

    composer(tester).onShowAttachmentOptions!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach_sketch')));
    await tester.pumpAndSettle();
    expect(find.byType(SketchScreen), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(composer(tester).attachedImages, hasLength(5));
    expect(drafts.getSketchDocuments('session-a'), {0: _editedDocument});
  });

  for (final removedIndex in [0, 1]) {
    testWidgets(
      'pending removal of attachment $removedIndex cannot update the wrong image',
      (tester) async {
        saveImages('session-a', 2, sketchDocuments: {1: _document});
        await pumpComposer(tester);
        // Model a removal already pending when the editor opens.
        final removeAttachment = composer(tester).onClearImage!;
        await tester.tap(find.byKey(const ValueKey('attached_image_1')));
        await tester.pumpAndSettle();

        removeAttachment(removedIndex);
        await tester.pump();
        await returnSketch(tester);
        expect(composer(tester).attachedImages, hasLength(1));
        expect(
          drafts.getSketchDocuments('session-a'),
          removedIndex == 0 ? {0: _editedDocument} : isEmpty,
        );
        expect(
          composer(tester).editableSketchIndices,
          removedIndex == 0 ? {0} : isEmpty,
        );
      },
    );
  }

  testWidgets(
    'an edit result is ignored after the composer switches sessions',
    (tester) async {
      saveImages('session-a', 1, sketchDocuments: {0: _document});
      saveImages('session-b', 2, sketchDocuments: {1: _editedDocument});
      await pumpComposer(tester);
      await tester.tap(find.byKey(const ValueKey('attached_image_0')));
      await tester.pumpAndSettle();

      sessionId.value = 'session-b';
      await tester.pumpAndSettle();
      await returnSketch(tester);
      expect(composer(tester).attachedImages, hasLength(2));
      expect(composer(tester).editableSketchIndices, {1});
      expect(drafts.getSketchDocuments('session-a'), {0: _document});
      expect(drafts.getSketchDocuments('session-b'), {1: _editedDocument});

      sessionId.value = 'session-a';
      await tester.pumpAndSettle();
      expect(composer(tester).attachedImages, hasLength(1));
      expect(composer(tester).editableSketchIndices, {0});
      await tester.tap(find.byKey(const ValueKey('attached_image_0')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SketchScreen>(find.byType(SketchScreen))
            .initialDocumentJson,
        _document,
      );
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'new sketch stays attached without sending until send is tapped',
    (tester) async {
      await pumpComposer(tester);
      composer(tester).onShowAttachmentOptions!();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attach_sketch')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SketchScreen>(find.byType(SketchScreen))
            .initialDocumentJson,
        isNull,
      );
      await returnSketch(tester);
      expect(composer(tester).attachedImages.single.mimeType, 'image/png');
      expect(drafts.getSketchDocuments('session-a'), {0: _editedDocument});
      expect(bridge.sentMessages, isEmpty);

      await tester.tap(find.byKey(const ValueKey('send_button')));
      await tester.pumpAndSettle();
      final sent = bridge.sentMessages
          .map(
            (message) => jsonDecode(message.toJson()) as Map<String, dynamic>,
          )
          .where((message) => message['type'] == 'input')
          .single;
      expect(sent['images'], [
        {'base64': base64Encode(_pngBytes), 'mimeType': 'image/png'},
      ]);
      expect(sent.containsKey('sketchDocuments'), isFalse);
      expect(composer(tester).attachedImages, isEmpty);
      expect(composer(tester).editableSketchIndices, isEmpty);
      expect(drafts.getImageDraft('session-a'), isNull);
      expect(drafts.getSketchDocuments('session-a'), isEmpty);
    },
  );
}
