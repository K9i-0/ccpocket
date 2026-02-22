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
}
