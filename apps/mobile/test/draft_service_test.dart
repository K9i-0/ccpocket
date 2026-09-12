import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/services/draft_service.dart';

void main() {
  late DraftService draftService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    draftService = DraftService(prefs);
  });

  group('Text draft persistence', () {
    test('saveDraft stores and getDraft retrieves text', () {
      draftService.saveDraft('session-1', 'Hello world');
      expect(draftService.getDraft('session-1'), 'Hello world');
    });

    test('getDraft returns null for unknown session', () {
      expect(draftService.getDraft('unknown'), isNull);
    });

    test('saveDraft with empty text deletes the draft', () {
      draftService.saveDraft('session-1', 'some text');
      expect(draftService.getDraft('session-1'), 'some text');
      draftService.saveDraft('session-1', '');
      expect(draftService.getDraft('session-1'), isNull);
    });

    test('deleteDraft removes the draft', () {
      draftService.saveDraft('session-1', 'draft text');
      draftService.deleteDraft('session-1');
      expect(draftService.getDraft('session-1'), isNull);
    });

    test('migrateDraft moves draft from old to new session ID', () {
      draftService.saveDraft('pending_123', 'migrated text');
      draftService.migrateDraft('pending_123', 'real_456');
      expect(draftService.getDraft('pending_123'), isNull);
      expect(draftService.getDraft('real_456'), 'migrated text');
    });

    test('migrateDraft does nothing when old ID has no draft', () {
      draftService.migrateDraft('nonexistent', 'real_456');
      expect(draftService.getDraft('real_456'), isNull);
    });
  });

  group('Text draft survives reload', () {
    test(
      'draft is available after creating new DraftService from same prefs',
      () async {
        // Save via first instance
        draftService.saveDraft('session-1', 'persistent text');

        // Create second instance with same underlying prefs
        final prefs = await SharedPreferences.getInstance();
        final draftService2 = DraftService(prefs);

        expect(draftService2.getDraft('session-1'), 'persistent text');
      },
    );

    test('migrated draft persists across reload', () async {
      draftService.saveDraft('pending_1', 'will migrate');
      draftService.migrateDraft('pending_1', 'real_1');

      final prefs = await SharedPreferences.getInstance();
      final draftService2 = DraftService(prefs);

      expect(draftService2.getDraft('pending_1'), isNull);
      expect(draftService2.getDraft('real_1'), 'will migrate');
    });
  });

  group('Image draft persistence', () {
    test('saveImageDraft stores and getImageDraft retrieves images', () {
      final images = [
        (bytes: Uint8List.fromList([1, 2, 3]), mimeType: 'image/png'),
      ];
      draftService.saveImageDraft('session-1', images);
      final result = draftService.getImageDraft('session-1');
      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result[0].mimeType, 'image/png');
      expect(result[0].bytes, [1, 2, 3]);
    });

    test('saveImageDraft with empty list deletes the draft', () {
      final images = [
        (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
      ];
      draftService.saveImageDraft('session-1', images);
      draftService.saveImageDraft('session-1', []);
      expect(draftService.getImageDraft('session-1'), isNull);
    });

    test('migrateImageDraft moves images from old to new session ID', () {
      final images = [
        (bytes: Uint8List.fromList([4, 5]), mimeType: 'image/jpeg'),
      ];
      draftService.saveImageDraft('pending_1', images);
      draftService.migrateImageDraft('pending_1', 'real_1');
      expect(draftService.getImageDraft('pending_1'), isNull);
      final result = draftService.getImageDraft('real_1');
      expect(result, isNotNull);
      expect(result![0].mimeType, 'image/jpeg');
    });
  });

  group('Editable sketch image drafts', () {
    const document = '{"strokes":[{"points":[1,2,3]}]}';

    test('mixed attachments preserve sketch indexes across reload', () async {
      draftService.saveImageDraft(
        'session-1',
        [
          (bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg'),
          (bytes: Uint8List.fromList([2, 3]), mimeType: 'image/png'),
        ],
        sketchDocuments: {1: document},
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = jsonDecode(prefs.getString('draft_image_v1_session-1')!);
      expect(stored[0].containsKey('sketch'), isFalse);
      expect(stored[1]['sketch'], document);

      final reloaded = DraftService(prefs);
      expect(reloaded.getImageDraft('session-1')![0].bytes, [1]);
      expect(reloaded.getImageDraft('session-1')![1].bytes, [2, 3]);
      expect(reloaded.getSketchDocuments('session-1'), {1: document});
      expect(reloaded.getSketchDocuments('unknown'), isEmpty);
    });

    test('caller mutations cannot change a saved draft snapshot', () async {
      final bytes = Uint8List.fromList([1, 2]);
      final images = [(bytes: bytes, mimeType: 'image/png')];
      final documents = {0: document};
      draftService.saveImageDraft(
        'session-1',
        images,
        sketchDocuments: documents,
      );

      bytes[0] = 99;
      images.clear();
      documents[0] = '{"changed":true}';

      final saved = draftService.getImageDraft('session-1')!;
      expect(saved.single.bytes, [1, 2]);
      expect(draftService.getSketchDocuments('session-1'), {0: document});
      expect(() => saved.clear(), throwsUnsupportedError);
      expect(() => saved.single.bytes[0] = 42, throwsUnsupportedError);
      expect(
        () => draftService.getSketchDocuments('session-1')[0] = 'changed',
        throwsUnsupportedError,
      );

      final reloaded = DraftService(await SharedPreferences.getInstance());
      expect(reloaded.getImageDraft('session-1')!.single.bytes, [1, 2]);
      expect(reloaded.getSketchDocuments('session-1'), {0: document});
      expect(
        () => reloaded.getImageDraft('session-1')!.single.bytes[0] = 42,
        throwsUnsupportedError,
      );
      expect(
        () => reloaded.getSketchDocuments('session-1').clear(),
        throwsUnsupportedError,
      );
    });

    test(
      'metadata must have a nonempty document and a matching index',
      () async {
        draftService.saveImageDraft(
          'session-1',
          [
            (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
            (bytes: Uint8List.fromList([2]), mimeType: 'image/png'),
          ],
          sketchDocuments: {-1: document, 0: '', 1: document, 2: document},
        );

        expect(draftService.getSketchDocuments('session-1'), {1: document});
        final reloaded = DraftService(await SharedPreferences.getInstance());
        expect(reloaded.getSketchDocuments('session-1'), {1: document});
        expect(reloaded.getImageDraft('session-1'), hasLength(2));
      },
    );

    test(
      'replacing images without metadata clears previous documents',
      () async {
        final images = [
          (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
        ];
        draftService.saveImageDraft(
          'session-1',
          images,
          sketchDocuments: {0: document},
        );
        draftService.saveImageDraft('session-1', images);

        expect(draftService.getSketchDocuments('session-1'), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        final stored = jsonDecode(prefs.getString('draft_image_v1_session-1')!);
        expect(stored[0].containsKey('sketch'), isFalse);
        expect(DraftService(prefs).getSketchDocuments('session-1'), isEmpty);
      },
    );

    test(
      'migration moves images and documents together across reload',
      () async {
        draftService.saveImageDraft(
          'pending_1',
          [
            (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
          ],
          sketchDocuments: {0: document},
        );
        draftService.migrateImageDraft('pending_1', 'real_1');

        expect(draftService.getImageDraft('pending_1'), isNull);
        expect(draftService.getSketchDocuments('pending_1'), isEmpty);
        expect(draftService.getSketchDocuments('real_1'), {0: document});
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('draft_image_v1_pending_1'), isFalse);
        final reloaded = DraftService(prefs);
        expect(reloaded.getImageDraft('pending_1'), isNull);
        expect(reloaded.getSketchDocuments('pending_1'), isEmpty);
        expect(reloaded.getImageDraft('real_1')!.single.bytes, [1]);
        expect(reloaded.getSketchDocuments('real_1'), {0: document});
      },
    );

    for (final useEmptySave in [false, true]) {
      test(
        '${useEmptySave ? 'saving empty images' : 'deleting images'} removes documents across reload',
        () async {
          draftService.saveImageDraft(
            'session-1',
            [
              (bytes: Uint8List.fromList([1]), mimeType: 'image/png'),
            ],
            sketchDocuments: {0: document},
          );
          if (useEmptySave) {
            draftService.saveImageDraft(
              'session-1',
              [],
              sketchDocuments: {0: document},
            );
          } else {
            draftService.deleteImageDraft('session-1');
          }

          expect(draftService.getSketchDocuments('session-1'), isEmpty);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.containsKey('draft_image_v1_session-1'), isFalse);
          final reloaded = DraftService(prefs);
          expect(reloaded.getImageDraft('session-1'), isNull);
          expect(reloaded.getSketchDocuments('session-1'), isEmpty);
        },
      );
    }

    test('legacy and plain JSON image drafts still load and migrate', () async {
      final encoded = base64Encode([1, 2, 3]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_image_v1_legacy', '$encoded|image/jpeg');
      await prefs.setString(
        'draft_image_v1_json',
        jsonEncode([
          {'b64': encoded, 'mime': 'image/png'},
        ]),
      );
      final loaded = DraftService(prefs);
      for (final sessionId in ['legacy', 'json']) {
        expect(loaded.getImageDraft(sessionId)!.single.bytes, [1, 2, 3]);
        expect(loaded.getSketchDocuments(sessionId), isEmpty);
        loaded.migrateImageDraft(sessionId, 'migrated_$sessionId');
      }

      final reloaded = DraftService(prefs);
      expect(
        reloaded.getImageDraft('migrated_legacy')!.single.mimeType,
        'image/jpeg',
      );
      expect(
        reloaded.getImageDraft('migrated_json')!.single.mimeType,
        'image/png',
      );
      expect(reloaded.getSketchDocuments('migrated_legacy'), isEmpty);
      expect(reloaded.getSketchDocuments('migrated_json'), isEmpty);
    });

    test('corrupt optional metadata does not discard valid images', () async {
      final invalidDocuments = [null, 42, true, <String, dynamic>{}, [], ''];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'draft_image_v1_session-1',
        jsonEncode([
          for (final invalid in invalidDocuments)
            {'b64': 'AQ==', 'mime': 'image/png', 'sketch': invalid},
          {'b64': 'Ag==', 'mime': 'image/png', 'sketch': document},
        ]),
      );

      final loaded = DraftService(prefs);
      expect(
        loaded.getImageDraft('session-1'),
        hasLength(invalidDocuments.length + 1),
      );
      expect(loaded.getSketchDocuments('session-1'), {
        invalidDocuments.length: document,
      });
      expect(loaded.getImageDraft('session-1')!.last.bytes, [2]);
    });
  });
}
