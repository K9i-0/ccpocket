import 'package:ccpocket/features/file_peek/markdown_link_handler.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/local_url_settings_tile.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/local_url_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('replaces only loopback HTTP(S) hosts and preserves URL components', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]']) {
      final original = Uri.parse('https://$host:3000/a%20b?q=localhost%2F#top');
      for (final replacement in [
        '192.168.1.10',
        'mac.tailnet.ts.net',
        '[fd00::123]',
      ]) {
        final result = replaceLocalUrlHost(original, replacement)!;
        expect(result.host, replacement.replaceAll(RegExp(r'[\[\]]'), ''));
        expect(result.port, 3000);
        expect(result.scheme, 'https');
        expect(result.path, original.path);
        expect(result.query, original.query);
        expect(result.fragment, original.fragment);
      }
    }
    for (final url in [
      'https://example.com/localhost',
      'http://localhost.example.com',
      'ws://localhost:3000',
      'file:///tmp/localhost',
    ]) {
      expect(replaceLocalUrlHost(Uri.parse(url), '192.168.1.10'), isNull);
    }
  });

  test('validates host-only input', () {
    for (final host in [
      '',
      'http://pc',
      'pc:3000',
      'pc/path',
      'user@pc',
      'pc?q=x',
      'pc#x',
      'two hosts',
      '::1',
    ]) {
      expect(normalizeLocalUrlHost(host), isNull, reason: host);
    }
    expect(normalizeLocalUrlHost('  pc.local  '), 'pc.local');
  });

  test(
    'persists settings per connection without credentials or tokens',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);
      const url = 'ws://user:secret@192.168.1.10:8765/path?token=secret';
      expect(cubit.localUrlSettingsFor(url).mode, LocalUrlMode.original);
      await cubit.setLocalUrlSettings(
        url,
        const LocalUrlSettings(mode: LocalUrlMode.ask, host: 'pc.local'),
      );
      await cubit.close();
      final restored = SettingsCubit(prefs);
      expect(
        restored.localUrlSettingsFor('ws://192.168.1.10:8765').mode,
        LocalUrlMode.ask,
      );
      expect(restored.localUrlSettingsFor(url).host, 'pc.local');
      expect(
        restored.localUrlSettingsFor('ws://192.168.1.11:8765').mode,
        LocalUrlMode.original,
      );
      expect(prefs.getKeys().any((key) => key.contains('secret')), isFalse);
      await restored.close();
    },
  );

  for (final mode in LocalUrlMode.values) {
    testWidgets('resolves ${mode.name} and supports chooser cancellation', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final cubit = SettingsCubit(await SharedPreferences.getInstance());
      final bridge = _TestBridge();
      addTearDown(cubit.close);
      addTearDown(bridge.dispose);
      await cubit.setLocalUrlSettings(
        bridge.lastUrl!,
        LocalUrlSettings(mode: mode, host: '192.168.1.10'),
      );
      Uri? resolved;
      final original = Uri.parse('http://localhost:3000/preview');
      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: BlocProvider.value(
            value: cubit,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      resolved = await resolveChatLocalUrl(context, original);
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (mode == LocalUrlMode.ask) {
        expect(find.text(original.toString()), findsOneWidget);
        expect(find.text('http://192.168.1.10:3000/preview'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('local_url_replace_button')),
        );
        await tester.pumpAndSettle();
        expect(resolved?.host, '192.168.1.10');
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('local_url_original_button')),
        );
        await tester.pumpAndSettle();
        expect(resolved, original);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(SimpleDialog))).pop();
        await tester.pumpAndSettle();
        expect(resolved, isNull);
      } else {
        expect(
          resolved?.host,
          mode == LocalUrlMode.original ? 'localhost' : '192.168.1.10',
        );
        expect(find.byType(SimpleDialog), findsNothing);
      }
    });
  }

  testWidgets('IPv6 Bridge default can be saved without editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LocalUrlSettingsDialog(
          settings: LocalUrlSettings(mode: LocalUrlMode.replace),
          bridgeHost: 'fd00::123',
        ),
      ),
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('local_url_host_field')),
    );
    expect(field.controller!.text, '[fd00::123]');
    expect(normalizeLocalUrlHost(field.controller!.text), '[fd00::123]');
  });

  testWidgets('dialog defaults to Bridge host and validates before saving', (
    tester,
  ) async {
    LocalUrlSettings? saved;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              child: const Text('Settings'),
              onPressed: () async {
                saved = await showDialog<LocalUrlSettings>(
                  context: context,
                  builder: (_) => const LocalUrlSettingsDialog(
                    settings: LocalUrlSettings(mode: LocalUrlMode.replace),
                    bridgeHost: '192.168.1.10',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('local_url_host_field')))
          .controller!
          .text,
      '192.168.1.10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('local_url_host_field')),
      'http://pc:3000',
    );
    await tester.tap(find.byKey(const ValueKey('local_url_save_button')));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.byType(LocalUrlSettingsDialog), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('local_url_host_field')),
      'pc.local',
    );
    await tester.tap(find.byKey(const ValueKey('local_url_save_button')));
    await tester.pumpAndSettle();
    expect(saved?.host, 'pc.local');
    expect(saved?.mode, LocalUrlMode.replace);
  });
}

class _TestBridge extends BridgeService {
  @override
  String? get lastUrl => 'ws://192.168.1.10:8765';
}
