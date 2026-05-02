import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/prompt_history_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromptHistoryEntry', () {
    test('merges entries from multiple bridges for display', () {
      final first = PromptHistoryEntry(
        id: 'ph_1',
        text: '/test',
        projectPath: '/repo',
        useCount: 2,
        isFavorite: false,
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
        commandKind: 'slash',
        bridgeIds: const ['bridge-a'],
        bridgeNames: const ['A'],
        clientStats: const {
          'phone': PromptHistoryClientStat(
            useCount: 2,
            lastUsedAt: '2026-01-02T00:00:00.000Z',
          ),
        },
        sessionStats: const {},
      );
      final second = PromptHistoryEntry(
        id: 'ph_1',
        text: '/test',
        projectPath: '/repo',
        useCount: 3,
        isFavorite: true,
        createdAt: DateTime.utc(2026, 1, 3),
        lastUsedAt: DateTime.utc(2026, 1, 4),
        updatedAt: DateTime.utc(2026, 1, 4),
        commandKind: 'slash',
        bridgeIds: const ['bridge-b'],
        bridgeNames: const ['B'],
        clientStats: const {
          'phone': PromptHistoryClientStat(
            useCount: 1,
            lastUsedAt: '2026-01-04T00:00:00.000Z',
          ),
        },
        sessionStats: const {
          'session': PromptHistorySessionStat(
            useCount: 3,
            lastUsedAt: '2026-01-04T00:00:00.000Z',
          ),
        },
      );

      final merged = first.merge(second);

      expect(merged.useCount, 5);
      expect(merged.isFavorite, isTrue);
      expect(merged.lastUsedAt, DateTime.utc(2026, 1, 4));
      expect(merged.bridgeIds, containsAll(['bridge-a', 'bridge-b']));
      expect(merged.clientStats['phone']?.useCount, 3);
      expect(merged.sessionStats['session']?.useCount, 3);
    });

    test('merges different raw entries by displayed prompt text', () {
      final commandXml = PromptHistoryEntry(
        id: 'ph_xml',
        text:
            '<command-message><command-name>\$release-app</command-name></command-message>',
        projectPath: '/repo/a',
        useCount: 11,
        isFavorite: false,
        createdAt: DateTime.utc(2026, 1, 1),
        lastUsedAt: DateTime.utc(2026, 1, 2),
        updatedAt: DateTime.utc(2026, 1, 2),
        commandKind: 'skill',
        bridgeIds: const ['bridge-a'],
        bridgeNames: const ['A'],
        clientStats: const {},
        sessionStats: const {},
        sources: const [
          PromptHistorySource(id: 'ph_xml', bridgeId: 'bridge-a'),
        ],
      );
      final displayText = PromptHistoryEntry(
        id: 'ph_plain',
        text: r'$release-app',
        projectPath: '/repo/b',
        useCount: 41,
        isFavorite: true,
        createdAt: DateTime.utc(2026, 1, 3),
        lastUsedAt: DateTime.utc(2026, 1, 4),
        updatedAt: DateTime.utc(2026, 1, 4),
        commandKind: 'skill',
        bridgeIds: const ['bridge-b'],
        bridgeNames: const ['B'],
        clientStats: const {},
        sessionStats: const {},
        sources: const [
          PromptHistorySource(id: 'ph_plain', bridgeId: 'bridge-b'),
        ],
      );

      final prompts = PromptHistoryService.mergeEntriesForDisplay([
        commandXml,
        displayText,
      ]);

      expect(prompts, hasLength(1));
      expect(prompts.single.id, 'ph_plain');
      expect(prompts.single.text, r'$release-app');
      expect(prompts.single.useCount, 52);
      expect(prompts.single.isFavorite, isTrue);
      expect(prompts.single.bridgeIds, containsAll(['bridge-a', 'bridge-b']));
      expect(
        prompts.single.sources.map((source) => source.id),
        containsAll(['ph_xml', 'ph_plain']),
      );
    });

    test('merges only entries that survived filters', () {
      final sameProject = _entry(
        id: 'same',
        projectPath: '/workspace/current',
        bridgeId: 'bridge-a',
        text: 'LGTMコミットして',
      );
      final otherProject = _entry(
        id: 'other',
        projectPath: '/workspace/other',
        bridgeId: 'bridge-b',
        text: 'LGTMコミットして',
      );

      final filtered = [sameProject, otherProject]
          .where(
            (entry) => PromptHistoryService.matchesFilters(
              entry,
              filters: const PromptHistoryFilters(currentProjectOnly: true),
              clientId: 'phone',
              currentProjectPath: '/workspace/current',
            ),
          )
          .toList();
      final prompts = PromptHistoryService.mergeEntriesForDisplay(filtered);

      expect(prompts, hasLength(1));
      expect(prompts.single.useCount, 1);
      expect(prompts.single.bridgeIds, ['bridge-a']);
    });

    test('reports active filters', () {
      expect(const PromptHistoryFilters().hasActiveFilter, isFalse);
      expect(
        const PromptHistoryFilters(currentProjectOnly: true).hasActiveFilter,
        isTrue,
      );
    });

    test('matches open project only by project path', () {
      final currentProjectEntry = _entry(
        id: 'current',
        projectPath: '/workspace/current',
      );
      final otherProjectEntry = _entry(
        id: 'other',
        projectPath: '/workspace/other',
      );

      expect(
        PromptHistoryService.matchesFilters(
          currentProjectEntry,
          filters: const PromptHistoryFilters(currentProjectOnly: true),
          clientId: 'phone',
          currentProjectPath: '/workspace/current',
        ),
        isTrue,
      );
      expect(
        PromptHistoryService.matchesFilters(
          otherProjectEntry,
          filters: const PromptHistoryFilters(currentProjectOnly: true),
          clientId: 'phone',
          currentProjectPath: '/workspace/current',
        ),
        isFalse,
      );
    });

    test('does not apply open project when the project filter is off', () {
      final otherProjectEntry = _entry(
        id: 'other',
        projectPath: '/workspace/other',
      );

      expect(
        PromptHistoryService.matchesFilters(
          otherProjectEntry,
          filters: const PromptHistoryFilters(),
          clientId: 'phone',
          currentProjectPath: '/workspace/current',
        ),
        isTrue,
      );
    });
  });

  test('open project filter does not match empty project paths', () {
    final entry = _entry(id: 'empty', projectPath: '');

    expect(
      PromptHistoryService.matchesFilters(
        entry,
        filters: const PromptHistoryFilters(currentProjectOnly: true),
        clientId: 'phone',
        currentProjectPath: '',
      ),
      isFalse,
    );
    expect(
      PromptHistoryService.matchesFilters(
        entry,
        filters: const PromptHistoryFilters(currentProjectOnly: true),
        clientId: 'phone',
        currentProjectPath: '/workspace/current',
      ),
      isFalse,
    );
  });
}

PromptHistoryEntry _entry({
  required String id,
  required String projectPath,
  String text = '',
  String bridgeId = 'bridge-a',
}) {
  return PromptHistoryEntry(
    id: id,
    text: text.isEmpty ? 'prompt $id' : text,
    projectPath: projectPath,
    useCount: 1,
    isFavorite: false,
    createdAt: DateTime.utc(2026),
    lastUsedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    commandKind: 'none',
    bridgeIds: [bridgeId],
    bridgeNames: const ['Bridge A'],
    clientStats: const {},
    sessionStats: const {},
    sources: [PromptHistorySource(id: id, bridgeId: bridgeId)],
  );
}
