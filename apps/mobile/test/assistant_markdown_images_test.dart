import 'package:ccpocket/features/generated_image_preview/generated_image_preview_mapper.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/markdown_image_chip.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pathA = '/Users/example/project/out/title_a.png';
const _pathB = '/Users/example/project/out/title_b.png';

Map<String, dynamic> _imageJson(String path, {String? alt}) => {
  'id': _id,
  'url': '/images/$_id',
  'thumbnailUrl': '/images/$_id?variant=thumbnail',
  'mimeType': 'image/png',
  'path': path,
  'alt': ?alt,
};

void main() {
  group('markdownLocalImagePath', () {
    test('returns local paths and skips remote images', () {
      expect(markdownLocalImagePath(Uri.parse(_pathA)), _pathA);
      expect(markdownLocalImagePath(Uri.parse('out/a%20b.png')), 'out/a b.png');
      expect(
        markdownLocalImagePath(Uri.parse('file:///tmp/shot.png')),
        '/tmp/shot.png',
      );
      expect(
        markdownLocalImagePath(Uri.parse('https://example.com/a.png')),
        isNull,
      );
      expect(
        markdownLocalImagePath(Uri.parse('data:image/png;base64,AAAA')),
        isNull,
      );
    });
  });

  group('assistant message images', () {
    test('are parsed from live and past messages', () {
      final live = ServerMessage.fromJson({
        'type': 'assistant',
        'message': {
          'id': 'm1',
          'role': 'assistant',
          'content': [
            {'type': 'text', 'text': '![案A]($_pathA)'},
          ],
          'model': 'claude',
        },
        'images': [_imageJson(_pathA, alt: '案A')],
      });
      expect(live, isA<AssistantServerMessage>());
      final image = (live as AssistantServerMessage).images.single;
      expect(image.path, _pathA);
      expect(image.alt, '案A');

      final legacy = ServerMessage.fromJson({
        'type': 'assistant',
        'message': {
          'id': 'm2',
          'role': 'assistant',
          'content': <dynamic>[],
          'model': 'claude',
        },
      });
      expect((legacy as AssistantServerMessage).images, isEmpty);

      final update = ChatMessageHandler().handle(
        PastHistoryMessage(
          claudeSessionId: 's1',
          messages: [
            PastMessage.fromJson({
              'role': 'assistant',
              'uuid': 'u1',
              'content': [
                {'type': 'text', 'text': '![案A]($_pathA)'},
              ],
              'images': [_imageJson(_pathA, alt: '案A')],
            }),
          ],
        ),
        isBackground: false,
      );
      final entry = update.entriesToPrepend.single as ServerChatEntry;
      expect(
        (entry.message as AssistantServerMessage).images.single.path,
        _pathA,
      );
    });

    test('map to labelled preview items', () {
      final items = generatedImageItemsFromAssistantImages(
        [
          ImageRef.fromJson(_imageJson(_pathA, alt: '案A')),
          ImageRef.fromJson(_imageJson(_pathB)),
        ],
        messageKey: 'm1',
        httpBaseUrl: 'http://bridge:8765',
      );
      expect(items, hasLength(2));
      expect(items[0].url, 'http://bridge:8765/images/$_id');
      expect(
        items[0].thumbnailUrl,
        'http://bridge:8765/images/$_id?variant=thumbnail',
      );
      expect(items[0].caption, '案A');
      expect(items[0].title, 'title_a.png');
      expect(items[0].savedPath, _pathA);
      expect(items[1].caption, 'title_b.png');
      expect(items[0].id, isNot(items[1].id));

      expect(
        generatedImageItemsFromAssistantImages(
          [ImageRef.fromJson(_imageJson(_pathA))],
          messageKey: 'm1',
          httpBaseUrl: null,
        ),
        isEmpty,
      );
    });
  });

  group('AssistantBubble', () {
    testWidgets('shows attached images as a captioned gallery', (tester) async {
      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          AssistantBubble(
            httpBaseUrl: 'http://bridge:8765',
            onFileTap: (path) => openedPath = path,
            message: AssistantServerMessage(
              message: const AssistantMessage(
                id: 'm1',
                role: 'assistant',
                content: [
                  TextContent(
                    text: 'どちらにしますか。\n\n![案A]($_pathA)\n![案B]($_pathB)',
                  ),
                ],
                model: 'claude',
              ),
              images: [
                ImageRef.fromJson(_imageJson(_pathA, alt: '案A')),
                ImageRef.fromJson(_imageJson(_pathB, alt: '案B')),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('generated_image_chat_group')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('generated_image_chat_caption_0')),
            )
            .data,
        '案A',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('generated_image_chat_caption_1')),
            )
            .data,
        '案B',
      );

      // The markdown itself renders tappable labels, not broken images.
      final chips = find.byKey(const ValueKey('markdown_image_chip'));
      expect(chips, findsNWidgets(2));
      await tester.tap(chips.last);
      expect(openedPath, _pathB);
    });

    testWidgets('renders a label without a gallery when nothing is attached', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AssistantBubble(
            httpBaseUrl: 'http://bridge:8765',
            message: AssistantServerMessage(
              message: AssistantMessage(
                id: 'm1',
                role: 'assistant',
                content: [TextContent(text: 'See ![shot]($_pathA) here.')],
                model: 'claude',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('generated_image_chat_group')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('markdown_image_chip')), findsOneWidget);
      expect(find.text('shot'), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: BlocProvider<FileListCubit>(
      create: (_) => FileListCubit(const [], const Stream.empty()),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
