import 'dart:async';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/widgets/ios_image_paste_context_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ccpocket/image_paste_menu');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Completer<Map<String, dynamic>?> result;
  late List<MethodCall> calls;
  late List<String> received;

  setUp(() {
    result = Completer();
    calls = [];
    received = [];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return call.method == 'show' ? result.future : Future.value();
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> openMenu(WidgetTester tester) async {
    result = Completer();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: TextField(
            contextMenuBuilder: (context, editable) => IOSImagePasteContextMenu(
              editableTextState: editable,
              onImage: (bytes, mime) => received.add('$mime:${bytes.length}'),
              fallback: const Text('Legacy menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'Text');
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    editable.showToolbar();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'one native menu tap delivers image without another paste sheet',
    (tester) async {
      await openMenu(tester);
      expect(calls.single.method, 'show');
      expect((calls.single.arguments as Map)['title'], 'Paste Image');
      expect(find.byType(BottomSheet), findsNothing);
      result.complete({
        'bytes': Uint8List.fromList([1, 2]),
        'mimeType': 'image/png',
      });
      await tester.pumpAndSettle();
      expect(received, ['image/png:2']);
      expect(find.byType(IOSImagePasteContextMenu), findsNothing);
    },
  );

  testWidgets('native dismissal closes toolbar without attaching anything', (
    tester,
  ) async {
    await openMenu(tester);
    result.complete(null);
    await tester.pumpAndSettle();
    expect(received, isEmpty);
    expect(find.byType(IOSImagePasteContextMenu), findsNothing);
  });

  testWidgets('disposing sends matching cancellation and ignores late image', (
    tester,
  ) async {
    await openMenu(tester);
    final requestId = (calls.single.arguments as Map)['requestId'];
    await tester.pumpWidget(const SizedBox());
    expect(calls.last.method, 'cancel');
    expect((calls.last.arguments as Map)['requestId'], requestId);
    result.complete({
      'bytes': Uint8List.fromList([1]),
      'mimeType': 'image/png',
    });
    await tester.pump();
    expect(received, isEmpty);
  });

  testWidgets('old runner uses existing system context menu', (tester) async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => throw MissingPluginException(),
    );
    await openMenu(tester);
    expect(find.text('Legacy menu'), findsOneWidget);
    expect(received, isEmpty);
  });

  testWidgets('read error does not silently open a second paste UI', (
    tester,
  ) async {
    await openMenu(tester);
    result.completeError(PlatformException(code: 'image_read_failed'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to read clipboard'), findsOneWidget);
    expect(find.text('Legacy menu'), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
    expect(received, isEmpty);
  });
}
