import 'dart:convert';

import 'package:ccpocket/features/session_list/services/codex_project_profile_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'codex_profile_by_project_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = CodexProjectProfileStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves and loads a profile using a normalized project path', () async {
    await store.save('  /workspace/app  ', 'trusted');

    expect(await store.load('/workspace/app'), 'trusted');
  });

  test('removes a saved profile when the new value is empty', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: jsonEncode({'/workspace/app': 'trusted'}),
    });

    await store.save('/workspace/app', null);

    expect(await store.load('/workspace/app'), isNull);
  });

  test('ignores values that are not non-empty profile names', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: jsonEncode({
        '/workspace/number': 42,
        '/workspace/empty': '',
        '/workspace/valid': 'trusted',
      }),
    });

    expect(await store.load('/workspace/number'), isNull);
    expect(await store.load('/workspace/empty'), isNull);
    expect(await store.load('/workspace/valid'), 'trusted');
  });

  test('replaces corrupt storage with the next explicit selection', () async {
    SharedPreferences.setMockInitialValues({_storageKey: '{not-json'});

    await store.save('/workspace/app', 'trusted');

    expect(await store.load('/workspace/app'), 'trusted');
  });

  test('does not persist a profile for an empty project path', () async {
    await store.save('   ', 'trusted');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_storageKey), isFalse);
  });

  test('keeps profiles separate for Projects sharing a primary path', () async {
    await store.save('/workspace/app', 'frontend', projectId: 'project-a');
    await store.save('/workspace/app', 'backend', projectId: 'project-b');

    expect(
      await store.load('/workspace/app', projectId: 'project-a'),
      'frontend',
    );
    expect(
      await store.load('/workspace/app', projectId: 'project-b'),
      'backend',
    );
  });

  test('falls back to a legacy path profile for a custom Project', () async {
    SharedPreferences.setMockInitialValues({
      _storageKey: jsonEncode({'/workspace/app': 'trusted'}),
    });

    expect(
      await store.load('/workspace/app', projectId: 'project-a'),
      'trusted',
    );
  });
}
