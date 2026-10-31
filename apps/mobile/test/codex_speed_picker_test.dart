import 'dart:async';

import 'package:ccpocket/features/chat_session/widgets/codex_settings_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/codex_effort_slider.dart';
import 'package:ccpocket/widgets/codex_environment_summary.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ultrafast = CodexSpeed(
  'ultrafast',
  'Ultrafast',
  description: 'The fastest available responses for latency-sensitive work.',
);
const _metadata = {
  'gpt-6.1-sol': [CodexSpeed.fast, _ultrafast],
};

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

class _CatalogBridge extends BridgeService {
  _CatalogBridge({this.tiers = const {}, this.extended = false});

  Map<String, List<CodexSpeed>> tiers;
  final bool extended;
  final _catalogController = StreamController<List<SessionInfo>>.broadcast();

  @override
  List<String> get codexModels => const ['gpt-6.1-sol', 'gpt-6-luna'];
  @override
  Map<String, List<String>> get codexModelReasoningEfforts => const {
    'gpt-6.1-sol': ['high'],
    'gpt-6-luna': ['low'],
  };
  @override
  Map<String, List<CodexSpeed>> get codexModelServiceTierMetadata => tiers;
  @override
  bool get supportsCodexServiceTiers => extended;
  @override
  Stream<List<SessionInfo>> get sessionList => _catalogController.stream;
  void notifyCatalogChanged() => _catalogController.add(const []);
  @override
  void requestProjects() {}
  @override
  void dispose() {
    _catalogController.close();
    super.dispose();
  }
}

void main() {
  test(
    'extended choices require both the model catalog and Bridge capability',
    () {
      expect(
        codexAvailableSpeeds(
          'gpt-6.1-sol',
          const {},
          modelServiceTierMetadata: _metadata,
        ),
        [CodexSpeed.standard, CodexSpeed.fast],
      );
      expect(
        codexAvailableSpeeds(
          'gpt-6.1-sol',
          const {},
          modelServiceTierMetadata: _metadata,
          supportsExtendedServiceTiers: true,
        ),
        [CodexSpeed.standard, CodexSpeed.fast, _ultrafast],
      );
      expect(
        codexAvailableSpeeds(
          'gpt-6.1-sol',
          const {
            'gpt-6.1-sol': ['ultrafast'],
          },
          modelServiceTierMetadata: const {'gpt-6.1-sol': []},
          supportsExtendedServiceTiers: true,
        ),
        [CodexSpeed.standard],
      );
    },
  );

  test('display uses catalog name without changing a saved id', () {
    final stored = codexSpeedFromRaw('ultrafast');
    expect(codexSpeedForDisplay(stored, [_ultrafast]).label, 'Ultrafast');
    expect(codexSpeedForDisplay(stored, []).value, 'ultrafast');
  });

  test('available speeds preserve the legacy priority alias for Fast', () {
    expect(
      codexAvailableSpeeds('gpt-6.1-sol', const {
        'gpt-6.1-sol': ['priority'],
      }),
      [CodexSpeed.standard, CodexSpeed.fast],
    );
  });

  test('legacy saved Fast works without metadata but not with an explicit empty catalog', () {
    expect(
      codexAvailableSpeeds('model', const {}, currentSpeed: CodexSpeed.fast),
      [CodexSpeed.standard, CodexSpeed.fast],
    );
    expect(
      codexAvailableSpeeds('model', const {
        'model': [],
      }, currentSpeed: CodexSpeed.fast),
      [CodexSpeed.standard],
    );
    expect(codexAvailableSpeeds('model', const {}, currentSpeed: _ultrafast), [
      CodexSpeed.standard,
    ]);
  });

  testWidgets(
    'expanded quick control requires explicit choice and shows description',
    (tester) async {
      CodexSpeed? selected;
      await tester.pumpWidget(
        _wrap(
          CodexSpeedButton(
            speed: CodexSpeed.standard,
            availableSpeeds: const [
              CodexSpeed.standard,
              CodexSpeed.fast,
              _ultrafast,
            ],
            onChanged: (value) => selected = value,
            buttonKey: 'speed',
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('speed')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text(_ultrafast.description!), findsOneWidget);
      await tester.tap(find.text('Ultrafast'));
      await tester.pumpAndSettle();
      expect(selected, _ultrafast);
    },
  );

  testWidgets('legacy quick control continues toggling Standard and Fast', (
    tester,
  ) async {
    CodexSpeed? selected;
    await tester.pumpWidget(
      _wrap(
        CodexSpeedButton(
          speed: CodexSpeed.standard,
          onChanged: (value) => selected = value,
          buttonKey: 'speed',
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('speed')));
    expect(selected, CodexSpeed.fast);
  });

  testWidgets(
    'unavailable current tier can be changed explicitly to Standard',
    (tester) async {
      CodexSpeed? selected;
      await tester.pumpWidget(
        _wrap(
          CodexSpeedButton(
            speed: _ultrafast,
            availableSpeeds: const [CodexSpeed.standard],
            onChanged: (value) => selected = value,
            buttonKey: 'speed',
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('speed')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.text('Ultrafast'), findsNothing);
      await tester.tap(find.text('Standard'));
      expect(selected, CodexSpeed.standard);
    },
  );

  testWidgets(
    'settings wait for confirmation and block incompatible model changes',
    (tester) async {
      CodexSpeed confirmed = _ultrafast;
      CodexSpeed? requested;
      String? changedModel;
      late StateSetter refresh;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (_, setState) {
              refresh = setState;
              return CodexSettingsSheet(
                models: const ['gpt-6.1-sol', 'gpt-6-luna'],
                modelEfforts: const {},
                modelServiceTiers: const {},
                modelServiceTierMetadata: _metadata,
                supportsExtendedServiceTiers: true,
                initialModel: 'gpt-6.1-sol',
                initialEffort: ReasoningEffort.high,
                initialSpeed: confirmed,
                onModelChanged: (model, _) => changedModel = model,
                onEffortChanged: (_, _) {},
                onSpeedChanged: (value) => requested = value,
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_model_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 Luna'));
      await tester.pumpAndSettle();
      expect(changedModel, isNull);
      expect(
        find.text('Choose a supported speed before changing model.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('codex_speed_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('codex_speed_standard_option')),
      );
      await tester.pumpAndSettle();
      expect(requested, CodexSpeed.standard);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('codex_speed_advanced')),
          matching: find.text('Ultrafast'),
        ),
        findsOneWidget,
      );
      refresh(() => confirmed = CodexSpeed.standard);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('codex_speed_advanced')),
          matching: find.text('Standard'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('environment summary preserves a named nonstandard tier', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const CodexEnvironmentSummary(
          model: 'gpt-6.1-sol',
          serviceTier: 'ultrafast',
        ),
      ),
    );
    expect(find.text('ultrafast'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex_speed_mode_indicator')),
      findsOneWidget,
    );
  });

  testWidgets(
    'reselecting the same legacy model keeps Fast when its catalog is absent',
    (tester) async {
      final speedRequests = <CodexSpeed>[];
      final modelRequests = <String>[];
      await tester.pumpWidget(
        _wrap(
          CodexSettingsSheet(
            models: const ['gpt-6.1-sol'],
            modelEfforts: const {},
            modelServiceTiers: const {},
            initialModel: 'gpt-6.1-sol',
            initialEffort: ReasoningEffort.high,
            initialSpeed: CodexSpeed.fast,
            onModelChanged: (model, _) => modelRequests.add(model),
            onEffortChanged: (_, _) {},
            onSpeedChanged: speedRequests.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_model_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6.1 Sol').last);
      await tester.pumpAndSettle();
      expect(modelRequests, ['gpt-6.1-sol']);
      expect(speedRequests, isEmpty);
    },
  );

  testWidgets(
    'legacy Fast model switch requests Standard before model and waits for confirmation',
    (tester) async {
      final requests = <String>[];
      await tester.pumpWidget(
        _wrap(
          CodexSettingsSheet(
            models: const ['gpt-6.1-sol', 'gpt-6-luna'],
            modelEfforts: const {},
            modelServiceTiers: const {
              'gpt-6.1-sol': ['fast'],
              'gpt-6-luna': [],
            },
            initialModel: 'gpt-6.1-sol',
            initialEffort: ReasoningEffort.high,
            initialSpeed: CodexSpeed.fast,
            onModelChanged: (model, _) => requests.add('model:$model'),
            onEffortChanged: (_, _) {},
            onSpeedChanged: (speed) => requests.add('speed:${speed.value}'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_model_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 Luna'));
      await tester.pumpAndSettle();
      expect(requests, ['speed:standard', 'model:gpt-6-luna']);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('codex_speed_advanced')),
          matching: find.text('Fast'),
        ),
        findsOneWidget,
      );
      expect(find.byType(CodexSettingsSheet), findsOneWidget);
      expect(
        tester
            .widget<CodexSettingsSheet>(find.byType(CodexSettingsSheet))
            .initialModel,
        'gpt-6.1-sol',
      );
    },
  );

  testWidgets(
    'an explicit return to the confirmed tier is not lost before acknowledgement',
    (tester) async {
      final requested = <CodexSpeed>[];
      await tester.pumpWidget(
        _wrap(
          CodexSettingsSheet(
            models: const ['gpt-6.1-sol'],
            modelEfforts: const {},
            modelServiceTiers: const {},
            modelServiceTierMetadata: _metadata,
            supportsExtendedServiceTiers: true,
            initialModel: 'gpt-6.1-sol',
            initialEffort: ReasoningEffort.high,
            initialSpeed: CodexSpeed.standard,
            onModelChanged: (_, _) {},
            onEffortChanged: (_, _) {},
            onSpeedChanged: requested.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_speed_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_speed_fast_option')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('codex_speed_advanced')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('codex_speed_standard_option')),
      );
      await tester.pumpAndSettle();
      expect(requested, [CodexSpeed.fast, CodexSpeed.standard]);
    },
  );

  testWidgets('a saved unavailable tier remains visible and blocks starting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bridge = _CatalogBridge();
    addTearDown(bridge.dispose);
    final initial = sessionStartDefaultsFromJson(
      sessionStartDefaultsToJson(
        NewSessionParams(
          provider: Provider.codex,
          projectPath: '/workspace/app',
          model: 'gpt-6.1-sol',
          codexSpeed: _ultrafast,
        ),
      ),
    )!;
    expect(initial.codexSpeed.value, 'ultrafast');
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showNewSessionSheet(
              context: context,
              recentProjects: const [],
              bridge: bridge,
              initialParams: initial.copyWith(projectPath: '/workspace/app'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('is unavailable for this model or Bridge'),
      findsOneWidget,
    );
    final start = tester.widget<FilledButton>(
      find.byKey(const ValueKey('dialog_start_button')),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets(
    'new session keeps an extended tier when switching to an incompatible model',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _CatalogBridge(tiers: _metadata, extended: true);
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showNewSessionSheet(
                context: context,
                recentProjects: const [],
                bridge: bridge,
                initialParams: NewSessionParams(
                  provider: Provider.codex,
                  projectPath: '/workspace/app',
                  model: 'gpt-6.1-sol',
                  codexSpeed: _ultrafast,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('dialog_codex_settings_mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dialog_codex_model')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 Luna').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<CodexSpeed>>(
              find.byKey(const ValueKey('dialog_codex_speed_advanced')),
            )
            .initialValue,
        _ultrafast,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dialog_start_button')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('codex_speed_unavailable')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'new session refreshes tiers from the dedicated session list stream',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = _CatalogBridge(extended: true);
      addTearDown(bridge.dispose);
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showNewSessionSheet(
                context: context,
                recentProjects: const [],
                bridge: bridge,
                initialParams: NewSessionParams(
                  provider: Provider.codex,
                  projectPath: '/workspace/app',
                  model: 'gpt-6.1-sol',
                  codexSpeed: _ultrafast,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dialog_start_button')),
            )
            .onPressed,
        isNull,
      );
      bridge.tiers = _metadata;
      bridge.notifyCatalogChanged();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('dialog_start_button')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.textContaining('is unavailable for this model or Bridge'),
        findsNothing,
      );
    },
  );
}
