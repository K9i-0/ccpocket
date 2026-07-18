import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/session_mode_bar.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/codex_effort_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockBridgeService extends BridgeService {
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final sentMessages = <ClientMessage>[];
  List<String> availableCodexModels = const [];
  Map<String, List<String>> availableCodexReasoningEfforts = const {};
  Map<String, List<String>> availableCodexServiceTiers = const {};

  @override
  List<String> get codexModels => availableCodexModels;

  @override
  Map<String, List<String>> get codexModelReasoningEfforts =>
      availableCodexReasoningEfforts;

  @override
  Map<String, List<String>> get codexModelServiceTiers =>
      availableCodexServiceTiers;

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void interrupt(String sessionId) {}

  @override
  void stopSession(String sessionId) {}

  @override
  void requestFileList(String projectPath) {}

  @override
  void requestSessionList() {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void dispose() {
    _messageController.close();
    _taggedController.close();
    super.dispose();
  }
}

Widget _wrap(ChatSessionCubit cubit, {bool showExtendedCodexEfforts = false}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: BlocProvider<ChatSessionCubit>.value(
        value: cubit,
        child: SessionModeBar(
          showExtendedCodexEfforts: showExtendedCodexEfforts,
        ),
      ),
    ),
  );
}

Map<String, dynamic> _decode(ClientMessage message) =>
    jsonDecode(message.toJson()) as Map<String, dynamic>;

void main() {
  late _MockBridgeService bridge;
  late StreamingStateCubit streamingCubit;
  late ChatSessionCubit cubit;

  setUp(() async {
    bridge = _MockBridgeService();
    streamingCubit = StreamingStateCubit();
    cubit = ChatSessionCubit(
      sessionId: 'codex-session',
      provider: Provider.codex,
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    await Future<void>.microtask(() {});
  });

  tearDown(() async {
    await cubit.close();
    await streamingCubit.close();
    bridge.dispose();
  });

  test('Codex Fast mode supports current and legacy metadata', () {
    expect(
      codexSupportsFast('gpt-5.6-sol', const {
        'gpt-5.6-sol': ['fast'],
      }),
      isTrue,
    );
    expect(
      codexSupportsFast('gpt-5.6-sol', const {
        'gpt-5.6-sol': ['priority'],
      }),
      isTrue,
    );
    expect(codexSupportsFast('gpt-5.5', const {}), isFalse);
    expect(codexSupportsFast('gpt-5.4-mini', const {}), isFalse);
  });

  test('Codex Effort slider caps at Extra High unless extended', () {
    const available = [
      ReasoningEffort.low,
      ReasoningEffort.medium,
      ReasoningEffort.high,
      ReasoningEffort.xhigh,
      ReasoningEffort.max,
      ReasoningEffort.ultra,
    ];

    expect(codexQuickEfforts(available).last, ReasoningEffort.xhigh);
    expect(
      codexQuickEfforts(available, includeExtended: true),
      containsAllInOrder([ReasoningEffort.max, ReasoningEffort.ultra]),
    );
  });

  testWidgets('extended Codex Effort slider can select Ultra', (tester) async {
    bridge.availableCodexModels = const ['gpt-5.6-sol'];
    bridge.availableCodexReasoningEfforts = const {
      'gpt-5.6-sol': ['low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
    };

    await tester.pumpWidget(_wrap(cubit, showExtendedCodexEfforts: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('5.6 Sol High'));
    await tester.pumpAndSettle();

    final slider = find.byKey(const ValueKey('codex_effort_slider'));
    final sliderRect = tester.getRect(slider);
    await tester.tapAt(Offset(sliderRect.right - 8, sliderRect.center.dy));
    await tester.pumpAndSettle();

    expect(cubit.state.codexModelReasoningEffort, ReasoningEffort.ultra);
    expect(
      _decode(bridge.sentMessages.last),
      containsPair('modelReasoningEffort', 'ultra'),
    );
  });

  testWidgets('codex settings header fits narrow layouts with large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(280, 600),
            textScaler: TextScaler.linear(3),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 280,
              child: CodexSettingsPanel(
                model: 'gpt-a-very-long-future-model-name',
                effort: ReasoningEffort.fromValue(
                  'a-very-long-future-effort-name',
                ),
                speed: CodexSpeed.standard,
                supportsFast: false,
                onSpeedChanged: (_) {},
                speedButtonKey: 'speed',
                showAdvanced: false,
                advancedLabel: 'Advanced',
                toggleButtonKey: 'advanced',
                onToggleMode: () {},
                quickPanelKey: 'quick-panel',
                advancedPanelKey: 'advanced-panel',
                modelLabelKey: 'model-label',
                effortLabelKey: 'effort-label',
                quickChild: const SizedBox(height: 32),
                advancedChild: const SizedBox(height: 96),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('effort-label'))).overflow,
      TextOverflow.ellipsis,
    );
  });

  testWidgets('claude keeps permission and sandbox grouped', (tester) async {
    final claudeCubit = ChatSessionCubit(
      sessionId: 'claude-session',
      provider: Provider.claude,
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    addTearDown(claudeCubit.close);

    bridge.emitMessage(
      const SystemMessage(
        subtype: 'set_permission_mode',
        provider: 'claude',
        permissionMode: 'plan',
      ),
      sessionId: 'claude-session',
    );
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.running),
      sessionId: 'claude-session',
    );

    await tester.pumpWidget(_wrap(claudeCubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plan Off'), findsNothing);
    expect(find.text('Plan On'), findsNothing);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.byType(PermissionModeChip), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_mode_chip_glow')), findsNothing);
  });

  testWidgets('claude auto permission mode is shown as Auto', (tester) async {
    final claudeCubit = ChatSessionCubit(
      sessionId: 'claude-auto-session',
      provider: Provider.claude,
      bridge: bridge,
      streamingCubit: streamingCubit,
      initialPermissionMode: PermissionMode.auto,
    );

    await tester.pumpWidget(_wrap(claudeCubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Auto'), findsOneWidget);
    expect(find.byIcon(Icons.auto_mode_outlined), findsOneWidget);

    await claudeCubit.close();
  });

  testWidgets('codex renders chips in Plan, Permissions order', (tester) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    final plan = tester.getCenter(find.text('Plan Off')).dx;
    final permissions = tester.getCenter(find.text('Default')).dx;

    expect(plan, lessThan(permissions));
    expect(find.text('Sandbox'), findsNothing);
  });

  testWidgets('codex model chip shows effective reasoning effort', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(cubit.state.codexModelReasoningEffort, isNull);
    expect(find.text('5.5 High'), findsOneWidget);
  });

  testWidgets('codex model menu supports GPT-5.6 max and ultra efforts', (
    tester,
  ) async {
    bridge.availableCodexModels = const ['gpt-5.6-sol'];
    bridge.availableCodexReasoningEfforts = const {
      'gpt-5.6-sol': ['low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
    };

    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('5.6 Sol High'), findsOneWidget);
    await tester.tap(find.text('5.6 Sol High'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('codex_settings_model_label')),
          )
          .data,
      '5.6 Sol',
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('codex_settings_effort_label')),
          )
          .data,
      'High',
    );
    expect(find.text('Ultra'), findsNothing);
    expect(find.byKey(const ValueKey('codex_effort_slider')), findsOneWidget);
    final modeButton = find.byKey(const ValueKey('codex_settings_advanced'));
    expect(
      find.descendant(
        of: modeButton,
        matching: find.byIcon(Icons.tune_rounded),
      ),
      findsOneWidget,
    );
    final headerY = tester
        .getCenter(find.byKey(const ValueKey('codex_speed_button')))
        .dy;
    for (final key in const [
      'codex_settings_model_label',
      'codex_settings_effort_label',
      'codex_settings_advanced',
    ]) {
      expect(
        tester.getCenter(find.byKey(ValueKey(key))).dy,
        closeTo(headerY, 1),
      );
    }
    final modelBounds = tester.getRect(
      find.byKey(const ValueKey('codex_settings_model_label')),
    );
    final effortBounds = tester.getRect(
      find.byKey(const ValueKey('codex_settings_effort_label')),
    );
    expect(effortBounds.left - modelBounds.right, closeTo(8, 1));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('codex_settings_effort_label')),
          )
          .style
          ?.fontWeight,
      FontWeight.w400,
    );

    await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: modeButton,
        matching: find.byIcon(Icons.linear_scale_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('codex_settings_quick_panel')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('codex_settings_advanced_panel')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('codex_effort_advanced')),
    );
    await tester.tap(find.byKey(const ValueKey('codex_effort_advanced')));
    await tester.pumpAndSettle();

    final ultraOption = find.byKey(
      const ValueKey('codex_effort_ultra_option'),
      skipOffstage: false,
    );
    expect(
      find.byKey(
        const ValueKey('codex_effort_max_option'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(ultraOption, findsOneWidget);
    await tester.ensureVisible(ultraOption);
    await tester.pumpAndSettle();
    await tester.tap(ultraOption);
    await tester.pumpAndSettle();

    expect(cubit.state.codexModelReasoningEffort, ReasoningEffort.ultra);
    expect(
      _decode(bridge.sentMessages.last),
      containsPair('modelReasoningEffort', 'ultra'),
    );

    await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codex_settings_quick_panel')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('codex_settings_effort_label')),
          )
          .data,
      'Ultra',
    );
    expect(
      find.byKey(const ValueKey('codex_settings_advanced_panel')),
      findsNothing,
    );
  });

  testWidgets('codex speed toggles Fast for the next turn', (tester) async {
    bridge.availableCodexModels = const ['gpt-5.6-sol'];
    bridge.availableCodexReasoningEfforts = const {
      'gpt-5.6-sol': ['low', 'medium', 'high', 'xhigh', 'ultra'],
    };
    bridge.availableCodexServiceTiers = const {
      'gpt-5.6-sol': ['priority'],
    };

    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('5.6 Sol High'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex_speed_button')));
    await tester.pumpAndSettle();

    expect(cubit.state.codexSpeed, CodexSpeed.fast);
    expect(_decode(bridge.sentMessages.last), {
      'type': 'set_codex_speed',
      'serviceTier': 'fast',
      'sessionId': 'codex-session',
    });
  });

  testWidgets('codex advanced Speed picker includes Fast', (tester) async {
    bridge.availableCodexModels = const ['gpt-5.6-sol'];
    bridge.availableCodexReasoningEfforts = const {
      'gpt-5.6-sol': ['low', 'medium', 'high', 'xhigh'],
    };
    bridge.availableCodexServiceTiers = const {
      'gpt-5.6-sol': ['priority'],
    };

    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('5.6 Sol High'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex_speed_advanced')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('codex_speed_fast_option')),
      findsOneWidget,
    );
  });

  testWidgets('codex model change prefers the first non-None Effort', (
    tester,
  ) async {
    bridge.availableCodexModels = const ['gpt-5.6-sol', 'gpt-5.4-mini'];
    bridge.availableCodexReasoningEfforts = const {
      'gpt-5.6-sol': ['xhigh', 'ultra'],
      'gpt-5.4-mini': ['low', 'medium'],
    };

    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('5.6 Sol Extra High'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex_settings_advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('codex_model_advanced')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5.4 Mini').last);
    await tester.pumpAndSettle();

    expect(
      _decode(bridge.sentMessages.last),
      containsPair('model', 'gpt-5.4-mini'),
    );
    expect(
      _decode(bridge.sentMessages.last),
      containsPair('modelReasoningEffort', 'low'),
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('codex_settings_effort_label')),
          )
          .data,
      'Light',
    );
  });

  testWidgets('shows bar-level glow when running in plan mode', (tester) async {
    bridge.emitMessage(
      const SystemMessage(
        subtype: 'set_permission_mode',
        provider: 'codex',
        permissionMode: 'plan',
        executionMode: 'default',
        planMode: true,
      ),
      sessionId: 'codex-session',
    );
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.running),
      sessionId: 'codex-session',
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    // Chip-local glow is off; bar-level rotating glow is used instead
    expect(find.byKey(const ValueKey('plan_mode_chip_glow')), findsNothing);
  });

  testWidgets('plan toggle updates in place for idle codex session', (
    tester,
  ) async {
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.idle),
      sessionId: 'codex-session',
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Plan Off'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enable Plan Mode'), findsNothing);
    expect(bridge.sentMessages, isNotEmpty);
    final message = _decode(bridge.sentMessages.last);
    expect(message['type'], 'set_permission_mode');
    expect(message['planMode'], true);
    expect(message['executionMode'], 'default');
  });

  testWidgets('codex permissions change shows restart confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Default'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full access'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Change Approval Policy'), findsOneWidget);
    expect(find.textContaining('will restart the session'), findsOneWidget);
  });

  testWidgets('codex mode bar does not render separate sandbox control', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sandbox'), findsNothing);
    expect(find.text('Default'), findsOneWidget);
  });
}
