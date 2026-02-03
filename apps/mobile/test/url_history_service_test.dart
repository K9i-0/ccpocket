import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/services/url_history_service.dart';

void main() {
  late UrlHistoryService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    service = UrlHistoryService(prefs);
  });

  group('UrlHistoryService', () {
    test('load returns empty list when no history', () {
      expect(service.load(), isEmpty);
    });

    test('add stores entry and load returns it', () async {
      await service.add('ws://192.168.1.10:8765', 'key123');

      final entries = service.load();
      expect(entries, hasLength(1));
      expect(entries.first.url, 'ws://192.168.1.10:8765');
      expect(entries.first.apiKey, 'key123');
    });

    test('add with empty apiKey stores empty string', () async {
      await service.add('ws://host:8765', '');

      final entries = service.load();
      expect(entries.first.apiKey, '');
    });

    test('add updates existing entry instead of duplicating', () async {
      await service.add('ws://host:8765', 'old_key');
      await service.add('ws://host:8765', 'new_key');

      final entries = service.load();
      expect(entries, hasLength(1));
      expect(entries.first.apiKey, 'new_key');
    });

    test('add updates lastConnected when URL already exists', () async {
      await service.add('ws://host:8765', '');
      final first = service.load().first.lastConnected;

      // Wait a tiny bit so timestamps differ
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.add('ws://host:8765', '');
      final second = service.load().first.lastConnected;

      expect(second.isAfter(first), isTrue);
    });

    test('load returns entries sorted by lastConnected descending', () async {
      await service.add('ws://a:8765', '');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.add('ws://b:8765', '');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.add('ws://c:8765', '');

      final entries = service.load();
      expect(entries.map((e) => e.url).toList(), [
        'ws://c:8765',
        'ws://b:8765',
        'ws://a:8765',
      ]);
    });

    test('add enforces max 10 entries', () async {
      for (var i = 0; i < 12; i++) {
        await service.add('ws://host$i:8765', '');
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final entries = service.load();
      expect(entries, hasLength(10));
      // Oldest entries (host0, host1) should be dropped
      final urls = entries.map((e) => e.url).toSet();
      expect(urls.contains('ws://host0:8765'), isFalse);
      expect(urls.contains('ws://host1:8765'), isFalse);
      expect(urls.contains('ws://host11:8765'), isTrue);
    });

    test('remove deletes matching URL', () async {
      await service.add('ws://a:8765', '');
      await service.add('ws://b:8765', '');

      await service.remove('ws://a:8765');
      final entries = service.load();
      expect(entries, hasLength(1));
      expect(entries.first.url, 'ws://b:8765');
    });

    test('remove is no-op for non-existent URL', () async {
      await service.add('ws://a:8765', '');

      await service.remove('ws://nonexistent:8765');
      final entries = service.load();
      expect(entries, hasLength(1));
    });

    test('load handles corrupted data gracefully', () async {
      SharedPreferences.setMockInitialValues({'url_history': 'not valid json'});
      final prefs = await SharedPreferences.getInstance();
      final corruptedService = UrlHistoryService(prefs);

      expect(corruptedService.load(), isEmpty);
    });
  });

  group('UrlHistoryEntry', () {
    test('toJson produces correct map', () {
      final entry = UrlHistoryEntry(
        url: 'ws://host:8765',
        apiKey: 'key',
        lastConnected: DateTime.utc(2025, 1, 15, 12, 0),
      );

      final json = entry.toJson();
      expect(json['url'], 'ws://host:8765');
      expect(json['apiKey'], 'key');
      expect(json['lastConnected'], '2025-01-15T12:00:00.000Z');
    });

    test('fromJson parses correctly', () {
      final entry = UrlHistoryEntry.fromJson({
        'url': 'ws://host:8765',
        'apiKey': 'key',
        'lastConnected': '2025-01-15T12:00:00.000Z',
      });

      expect(entry.url, 'ws://host:8765');
      expect(entry.apiKey, 'key');
      expect(entry.lastConnected, DateTime.utc(2025, 1, 15, 12, 0));
    });

    test('fromJson defaults apiKey to empty when missing', () {
      final entry = UrlHistoryEntry.fromJson({
        'url': 'ws://host:8765',
        'lastConnected': '2025-01-15T12:00:00.000Z',
      });

      expect(entry.apiKey, '');
    });
  });
}
