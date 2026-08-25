import 'dart:convert';

import 'package:ccpocket/features/session_list/services/session_start_defaults_store.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyKey = 'session_start_defaults_v1';
const _lastProviderKey = 'session_start_defaults_last_provider_v1';
const _claudeKey = 'session_start_defaults_claude_v1';
const _codexKey = 'session_start_defaults_codex_v1';

NewSessionParams _defaults(Provider provider, String projectPath) {
  return NewSessionParams(projectPath: projectPath, provider: provider);
}

String _encode(NewSessionParams params) {
  return jsonEncode(sessionStartDefaultsToJson(params));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const store = SessionStartDefaultsStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saves provider defaults and selects them as the latest', () async {
    final params = _defaults(Provider.codex, '/workspace/codex');

    await store.save(params);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_codexKey), _encode(params));
    expect(prefs.getString(_lastProviderKey), Provider.codex.value);
  });

  test('loads the latest provider without mixing scoped defaults', () async {
    SharedPreferences.setMockInitialValues({
      _lastProviderKey: Provider.claude.value,
      _claudeKey: _encode(_defaults(Provider.claude, '/workspace/claude')),
      _codexKey: _encode(_defaults(Provider.codex, '/workspace/codex')),
    });

    final loaded = await store.loadInitial();

    expect(loaded?.provider, Provider.claude);
    expect(loaded?.projectPath, '/workspace/claude');
  });

  test('rejects defaults stored under the wrong provider key', () async {
    SharedPreferences.setMockInitialValues({
      _claudeKey: _encode(_defaults(Provider.codex, '/workspace/codex')),
    });

    final loaded = await store.loadFor(Provider.claude);

    expect(loaded, isNull);
  });

  test('migrates matching legacy defaults and removes the fallback', () async {
    final legacy = _defaults(Provider.claude, '/workspace/legacy');
    SharedPreferences.setMockInitialValues({_legacyKey: _encode(legacy)});

    final loaded = await store.loadFor(Provider.claude);

    expect(loaded?.projectPath, '/workspace/legacy');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_claudeKey), _encode(legacy));
    expect(prefs.getString(_lastProviderKey), Provider.claude.value);
    expect(prefs.containsKey(_legacyKey), isFalse);
  });

  test('migration through loadFor preserves a valid latest provider', () async {
    final claude = _defaults(Provider.claude, '/workspace/claude');
    final legacyCodex = _defaults(Provider.codex, '/workspace/codex');
    SharedPreferences.setMockInitialValues({
      _lastProviderKey: Provider.claude.value,
      _claudeKey: _encode(claude),
      _legacyKey: _encode(legacyCodex),
    });

    final loaded = await store.loadFor(Provider.codex);

    expect(loaded?.projectPath, '/workspace/codex');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_codexKey), _encode(legacyCodex));
    expect(prefs.getString(_lastProviderKey), Provider.claude.value);
    expect(prefs.containsKey(_legacyKey), isFalse);
  });

  test('ignores a legacy fallback belonging to another provider', () async {
    SharedPreferences.setMockInitialValues({
      _legacyKey: _encode(_defaults(Provider.codex, '/workspace/codex')),
    });

    final loaded = await store.loadFor(Provider.claude);

    expect(loaded, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_legacyKey), isTrue);
  });

  test(
    'uses a valid legacy value when the latest scoped value is corrupt',
    () async {
      final legacy = _defaults(Provider.codex, '/workspace/legacy');
      SharedPreferences.setMockInitialValues({
        _lastProviderKey: Provider.claude.value,
        _claudeKey: '{not-json',
        _legacyKey: _encode(legacy),
      });

      final loaded = await store.loadInitial();

      expect(loaded?.provider, Provider.codex);
      expect(loaded?.projectPath, '/workspace/legacy');
    },
  );

  test(
    'preserves other-provider legacy defaults during an explicit save',
    () async {
      final legacyClaude = _defaults(Provider.claude, '/workspace/old');
      final newCodex = _defaults(Provider.codex, '/workspace/new');
      SharedPreferences.setMockInitialValues({
        _legacyKey: _encode(legacyClaude),
      });

      await store.save(newCodex);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_claudeKey), _encode(legacyClaude));
      expect(prefs.getString(_codexKey), _encode(newCodex));
      expect(prefs.getString(_lastProviderKey), Provider.codex.value);
      expect(prefs.containsKey(_legacyKey), isFalse);
    },
  );
}
