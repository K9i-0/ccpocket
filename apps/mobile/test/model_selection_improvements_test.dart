import 'package:ccpocket/features/chat_session/widgets/codex_settings_sheet.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/enabled_models_bottom_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/model_picker_style.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/utils/model_filter.dart';
import 'package:ccpocket/widgets/antigravity_model_options_panel.dart';
import 'package:ccpocket/widgets/claude_settings_panel.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeModelCatalogBridge extends BridgeService {
  @override
  final List<ClaudeModelOption> claudeModelOptions;
  @override
  final List<String> codexModels;
  @override
  final AntigravitySettings? antigravityCatalog;

  _FakeModelCatalogBridge({
    this.claudeModelOptions = const [],
    this.codexModels = const [],
    this.antigravityCatalog,
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('filterEnabledModels', () {
    const models = ['fable-5.2', 'opus-5.5', 'sonnet-4.6', 'haiku-4.5'];

    test('returns all models when enabledIds is empty', () {
      expect(
        filterEnabledModels<String>(
          models: models,
          enabledIds: const {},
          idOf: (m) => m,
        ),
        models,
      );
    });

    test('filters to only enabled models in catalog order', () {
      expect(
        filterEnabledModels<String>(
          models: models,
          enabledIds: const {'opus-5.5', 'fable-5.2'},
          idOf: (m) => m,
        ),
        const ['fable-5.2', 'opus-5.5'],
      );
    });

    test('keeps currentId even if filtered out', () {
      expect(
        filterEnabledModels<String>(
          models: models,
          enabledIds: const {'fable-5.2', 'opus-5.5'},
          idOf: (m) => m,
          currentId: 'haiku-4.5',
        ),
        const ['fable-5.2', 'opus-5.5', 'haiku-4.5'],
      );
    });

    test('falls back to all models when no enabled ID matches catalog', () {
      expect(
        filterEnabledModels<String>(
          models: models,
          enabledIds: const {'removed-model'},
          idOf: (m) => m,
        ),
        models,
      );
    });
  });

  group('Antigravity thinking level helpers', () {
    test('sorts known levels ascending and preserves unknown levels', () {
      expect(
        sortAntigravityThoughtLevels(const ['high', 'low', 'medium']),
        const ['low', 'medium', 'high'],
      );
      expect(
        sortAntigravityThoughtLevels(const [
          'custom',
          'max',
          'minimal',
          'xhigh',
        ]),
        const ['minimal', 'xhigh', 'max', 'custom'],
      );
    });

    test(
      'preferredAntigravityThoughtLevel keeps current or falls back to high',
      () {
        expect(
          preferredAntigravityThoughtLevel(const [
            'low',
            'medium',
            'high',
          ], current: 'low'),
          'low',
        );
        expect(
          preferredAntigravityThoughtLevel(const [
            'low',
            'high',
          ], current: 'medium'),
          'high',
        );
        expect(preferredAntigravityThoughtLevel(const []), isNull);
      },
    );
  });

  group('SettingsCubit model preferences', () {
    test('persists modelPickerStyle and enabled models per provider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);
      addTearDown(cubit.close);

      expect(cubit.state.modelPickerStyle, ModelPickerStyle.bottomSheet);
      expect(cubit.state.enabledClaudeModels, isEmpty);
      expect(cubit.state.enabledCodexModels, isEmpty);
      expect(cubit.state.enabledAntigravityModels, isEmpty);

      cubit.setModelPickerStyle(ModelPickerStyle.popupMenu);
      cubit.setEnabledClaudeModels(const {'fable-5.2', 'opus-5.5'});
      cubit.setEnabledCodexModels(const {'gpt-5.4'});
      cubit.setEnabledAntigravityModels(const {'gemini-3.8-flash'});

      expect(cubit.state.modelPickerStyle, ModelPickerStyle.popupMenu);
      expect(cubit.state.enabledClaudeModels, const {'fable-5.2', 'opus-5.5'});
      expect(cubit.state.enabledCodexModels, const {'gpt-5.4'});
      expect(cubit.state.enabledAntigravityModels, const {'gemini-3.8-flash'});

      final reloaded = SettingsCubit(prefs);
      addTearDown(reloaded.close);
      expect(reloaded.state.modelPickerStyle, ModelPickerStyle.popupMenu);
      expect(reloaded.state.enabledClaudeModels, const {
        'fable-5.2',
        'opus-5.5',
      });
      expect(reloaded.state.enabledCodexModels, const {'gpt-5.4'});
      expect(reloaded.state.enabledAntigravityModels, const {
        'gemini-3.8-flash',
      });

      // Clearing resets back to unrestricted.
      reloaded.setEnabledClaudeModels(const {});
      expect(reloaded.state.enabledClaudeModels, isEmpty);
      final reloadedAgain = SettingsCubit(prefs);
      addTearDown(reloadedAgain.close);
      expect(reloadedAgain.state.enabledClaudeModels, isEmpty);
    });
  });

  group('Inline popup menu model picker', () {
    testWidgets('ClaudeSettingsPanel opens popup menu in place when enabled', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        _app(
          ClaudeSettingsPanel(
            models: const [
              ClaudeModelOption(value: 'fable-5.2', displayName: 'Fable 5.2'),
              ClaudeModelOption(value: 'opus-5.5', displayName: 'Opus 5.5'),
            ],
            modelEfforts: const {
              'fable-5.2': [
                ClaudeEffort.low,
                ClaudeEffort.medium,
                ClaudeEffort.high,
              ],
              'opus-5.5': [ClaudeEffort.medium, ClaudeEffort.high],
            },
            model: 'fable-5.2',
            effort: ClaudeEffort.medium,
            fastMode: false,
            ultracode: false,
            modelPickerStyle: ModelPickerStyle.popupMenu,
            onModelChanged: (m) => picked = m,
            onEffortChanged: (_) {},
            onFastModeChanged: (_) {},
            onUltracodeChanged: (_) {},
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('claude_settings_model_label_button')),
      );
      await tester.pumpAndSettle();

      // PopupMenuItem appears instead of a nested bottom sheet ListTile.
      expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('claude_settings_model_opus-5.5_option')),
      );
      await tester.pumpAndSettle();
      expect(picked, 'opus-5.5');
    });

    testWidgets('CodexSettingsSheet opens popup menu in place when enabled', (
      tester,
    ) async {
      String? pickedModel;
      await tester.pumpWidget(
        _app(
          CodexSettingsSheet(
            models: const ['gpt-5.4', 'gpt-5.3-codex'],
            modelEfforts: const {
              'gpt-5.4': [ReasoningEffort.medium, ReasoningEffort.high],
              'gpt-5.3-codex': [ReasoningEffort.medium, ReasoningEffort.high],
            },
            modelServiceTiers: const {},
            initialModel: 'gpt-5.4',
            initialEffort: ReasoningEffort.high,
            initialSpeed: CodexSpeed.standard,
            modelPickerStyle: ModelPickerStyle.popupMenu,
            onModelChanged: (model, _) => pickedModel = model,
            onEffortChanged: (_, _) {},
            onSpeedChanged: (_) {},
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('codex_settings_model_label_button')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
      await tester.tap(
        find.byKey(const ValueKey('codex_model_gpt-5.3-codex_option')),
      );
      await tester.pumpAndSettle();
      expect(pickedModel, 'gpt-5.3-codex');
    });

    testWidgets(
      'AntigravityModelOptionsPanel renders slider and inline popup menu',
      (tester) async {
        AntigravityModelOption? pickedModel;
        String? pickedLevel;
        await tester.pumpWidget(
          _app(
            AntigravityModelOptionsPanel(
              modelOptions: const [
                AntigravityModelOption(
                  id: 'gemini-3.8-flash',
                  name: 'Gemini 3.8 Flash',
                  thoughtLevels: ['high', 'low', 'medium'],
                ),
                AntigravityModelOption(
                  id: 'gemini-3.1-pro',
                  name: 'Gemini 3.1 Pro',
                  thoughtLevels: ['low', 'high'],
                ),
              ],
              model: 'gemini-3.8-flash',
              thoughtLevel: 'high',
              thoughtLevels: const ['high', 'low', 'medium'],
              modelPickerStyle: ModelPickerStyle.popupMenu,
              onModelSelected: (m) => pickedModel = m,
              onThoughtLevelSelected: (l) => pickedLevel = l,
            ),
          ),
        );

        // Slider is present and centered tap selects medium.
        final slider = find.byKey(
          const ValueKey('antigravity_settings_effort_slider'),
        );
        expect(slider, findsOneWidget);
        await tester.tap(slider);
        await tester.pumpAndSettle();
        expect(pickedLevel, 'medium');

        // Model name tap opens an inline popup menu.
        await tester.tap(
          find.byKey(const ValueKey('antigravity_settings_model_label_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(PopupMenuItem<AntigravityModelOption>),
          findsNWidgets(2),
        );
        await tester.tap(
          find.byKey(const ValueKey('antigravity_model_option_gemini-3.1-pro')),
        );
        await tester.pumpAndSettle();
        expect(pickedModel?.id, 'gemini-3.1-pro');
      },
    );
  });

  group('EnabledModelsBottomSheet', () {
    testWidgets('allows clearing all, picking two models, and saving', (
      tester,
    ) async {
      final bridge = _FakeModelCatalogBridge(
        claudeModelOptions: const [
          ClaudeModelOption(value: 'fable-5.2', displayName: 'Fable 5.2'),
          ClaudeModelOption(value: 'opus-5.5', displayName: 'Opus 5.5'),
          ClaudeModelOption(value: 'sonnet-4.6', displayName: 'Sonnet 4.6'),
          ClaudeModelOption(value: 'haiku-4.5', displayName: 'Haiku 4.5'),
        ],
        codexModels: const ['gpt-5.4', 'gpt-5.3-codex'],
        antigravityCatalog: const AntigravitySettings(
          baseModel: 'gemini-3.8-flash',
          modelOptions: [
            AntigravityModelOption(
              id: 'gemini-3.8-flash',
              name: 'Gemini 3.8 Flash',
              thoughtLevels: ['low', 'medium', 'high'],
            ),
            AntigravityModelOption(
              id: 'gemini-3.1-pro',
              name: 'Gemini 3.1 Pro',
              thoughtLevels: ['low', 'high'],
            ),
          ],
        ),
      );
      addTearDown(bridge.dispose);

      Map<Provider, Set<String>>? saved;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showEnabledModelsBottomSheet(
                context: context,
                agents: const [
                  NewSessionTab.claude,
                  NewSessionTab.codex,
                  NewSessionTab.antigravity,
                ],
                initialEnabledByProvider: const {
                  Provider.claude: {},
                  Provider.codex: {},
                  Provider.antigravity: {},
                },
                bridge: bridge,
                onSaved: (updated) => saved = updated,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('4 / 4'), findsOneWidget);

      // Clear all disables save and shows validation message.
      await tester.tap(
        find.byKey(const ValueKey('enabled_models_clear_all_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 / 4'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('enabled_models_validation_message')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('enabled_models_save_button')),
            )
            .onPressed,
        isNull,
      );

      // Pick Fable 5.2 and Opus 5.5 only.
      await tester.tap(
        find.byKey(const ValueKey('enabled_model_claude_fable-5.2')),
      );
      await tester.tap(
        find.byKey(const ValueKey('enabled_model_claude_opus-5.5')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 4'), findsOneWidget);

      // Switch to Antigravity tab and uncheck Gemini 3.1 Pro.
      await tester.tap(
        find.byKey(const ValueKey('enabled_models_tab_antigravity')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('enabled_model_antigravity_gemini-3.1-pro')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('enabled_models_save_button')),
      );
      await tester.pumpAndSettle();

      expect(saved?[Provider.claude], const {'fable-5.2', 'opus-5.5'});
      expect(saved?[Provider.codex], isEmpty);
      expect(saved?[Provider.antigravity], const {'gemini-3.8-flash'});
    });

    testWidgets('selecting all normalizes back to empty set (unrestricted)', (
      tester,
    ) async {
      final bridge = _FakeModelCatalogBridge(
        claudeModelOptions: const [
          ClaudeModelOption(value: 'fable-5.2', displayName: 'Fable 5.2'),
          ClaudeModelOption(value: 'opus-5.5', displayName: 'Opus 5.5'),
        ],
      );
      addTearDown(bridge.dispose);

      Map<Provider, Set<String>>? saved;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showEnabledModelsBottomSheet(
                context: context,
                agents: const [NewSessionTab.claude],
                initialEnabledByProvider: const {
                  Provider.claude: {'fable-5.2'},
                },
                bridge: bridge,
                onSaved: (updated) => saved = updated,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('enabled_models_select_all_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('enabled_models_save_button')),
      );
      await tester.pumpAndSettle();
      expect(saved?[Provider.claude], isEmpty);
    });
  });

  group('NewSessionSheet model filtering and inline menu', () {
    testWidgets(
      'filters Claude models and opens inline popup menu when configured',
      (tester) async {
        final bridge = _FakeModelCatalogBridge(
          claudeModelOptions: const [
            ClaudeModelOption(value: 'fable-5.2', displayName: 'Fable 5.2'),
            ClaudeModelOption(value: 'opus-5.5', displayName: 'Opus 5.5'),
            ClaudeModelOption(value: 'sonnet-4.6', displayName: 'Sonnet 4.6'),
            ClaudeModelOption(value: 'haiku-4.5', displayName: 'Haiku 4.5'),
          ],
        );
        addTearDown(bridge.dispose);

        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showNewSessionSheet(
                  context: context,
                  recentProjects: const [],
                  bridge: bridge,
                  initialParams: NewSessionParams(
                    projectPath: '/workspace/app',
                    provider: Provider.claude,
                    claudeModel: 'sonnet-4.6',
                  ),
                  visibleTabs: const [NewSessionTab.claude],
                  modelPickerStyle: ModelPickerStyle.popupMenu,
                  enabledClaudeModels: const {'fable-5.2', 'opus-5.5'},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Saved sonnet-4.6 is filtered out, so Fable 5.2 becomes active.
        final modelButton = find.byKey(
          const ValueKey('dialog_claude_model_label_button'),
        );
        await tester.ensureVisible(modelButton);
        await tester.pumpAndSettle();
        expect(find.text('Fable 5.2'), findsOneWidget);
        await tester.tap(modelButton);
        await tester.pumpAndSettle();

        expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('dialog_claude_model_fable-5.2_option')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('dialog_claude_model_opus-5.5_option')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('dialog_claude_model_sonnet-4.6_option')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('dialog_claude_model_haiku-4.5_option')),
          findsNothing,
        );
      },
    );
  });
}
