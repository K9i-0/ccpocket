import 'dart:convert';
import 'dart:math' as math;

import 'package:ccpocket/features/session_list/widgets/section_header.dart';
import 'package:ccpocket/features/settings/models/settings_catalog.dart';
import 'package:ccpocket/features/settings/state/settings_state.dart';
import 'package:ccpocket/features/settings/widgets/settings_category_visuals.dart';
import 'package:ccpocket/features/settings/widgets/settings_status_card.dart';
import 'package:ccpocket/features/settings/widgets/settings_tiles.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/provider_style.dart';
import 'package:ccpocket/widgets/chat_input_bar.dart';
import 'package:ccpocket/widgets/new_session_sheet/sheet_chrome.dart';
import 'package:ccpocket/widgets/session_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _app(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ChatInputBar visual polish', () {
    testWidgets(
      'secondary toolbar buttons are transparent and muted at rest while send is solid primary',
      (tester) async {
        final controller = TextEditingController(text: 'Hello');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _app(
            AppTheme.darkTheme,
            ChatInputBar(
              inputController: controller,
              status: ProcessStatus.idle,
              hasInputText: true,
              isInputEmpty: true,
              isVoiceAvailable: true,
              isRecording: false,
              showDollarButton: true,
              onSend: () {},
              onStop: () {},
              onInterrupt: () {},
              onToggleVoice: () {},
              onIndent: () {},
              onDedent: () {},
              onSlashCommand: () {},
              onMention: () {},
              onDollarMention: () {},
              onAttachImage: () {},
              onShowPromptHistory: () {},
            ),
          ),
        );

        final cs = AppTheme.darkTheme.colorScheme;

        for (final key in const [
          ValueKey('indent_button'),
          ValueKey('mention_button'),
          ValueKey('dollar_button'),
          ValueKey('attach_image_button'),
          ValueKey('prompt_history_button'),
          ValueKey('voice_button'),
        ]) {
          final material = tester.widget<Material>(
            find
                .ancestor(of: find.byKey(key), matching: find.byType(Material))
                .first,
          );
          expect(material.color, Colors.transparent, reason: '$key at rest');
        }

        final indentIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('indent_button')),
            matching: find.byType(Icon),
          ),
        );
        expect(indentIcon.color, cs.onSurfaceVariant);

        final voiceIcon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const ValueKey('voice_button')),
            matching: find.byType(Icon),
          ),
        );
        expect(voiceIcon.color, cs.onSurfaceVariant);

        final sendBox = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('send_button')),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final sendDeco = sendBox.decoration as BoxDecoration;
        expect(sendDeco.color, cs.primary);
        expect(sendDeco.gradient, isNull);
        expect(sendDeco.shape, BoxShape.circle);
      },
    );

    testWidgets('attach and voice buttons highlight when active', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
      );

      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          ChatInputBar(
            inputController: controller,
            status: ProcessStatus.idle,
            hasInputText: false,
            isVoiceAvailable: true,
            isRecording: true,
            attachedImages: [(bytes: bytes, mimeType: 'image/png')],
            onSend: () {},
            onStop: () {},
            onInterrupt: () {},
            onToggleVoice: () {},
            onIndent: () {},
            onDedent: () {},
            onSlashCommand: () {},
            onMention: () {},
            onAttachImage: () {},
          ),
        ),
      );

      final cs = AppTheme.lightTheme.colorScheme;
      final attachMat = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('attach_image_button')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(attachMat.color, cs.primaryContainer);

      final voiceMat = tester.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('voice_button')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(voiceMat.color, cs.error);
    });
  });

  group('SessionCard and SectionHeader visual polish', () {
    testWidgets(
      'RunningSessionCard uses flat hairline header and understated stop button',
      (tester) async {
        final session = SessionInfo(
          id: 'run-1',
          projectPath: '/tmp/ccpocket',
          status: 'running',
          createdAt: DateTime.now().toIso8601String(),
          lastActivityAt: DateTime.now().toIso8601String(),
          lastMessage: 'Refining composer and home polish',
        );

        await tester.pumpWidget(
          _app(
            AppTheme.darkTheme,
            RunningSessionCard(session: session, onTap: () {}, onStop: () {}),
          ),
        );

        // No gradient strip anywhere in RunningSessionCard.
        final containers = tester.widgetList<Container>(
          find.descendant(
            of: find.byType(RunningSessionCard),
            matching: find.byType(Container),
          ),
        );
        for (final container in containers) {
          final deco = container.decoration;
          if (deco is BoxDecoration) {
            expect(deco.gradient, isNull);
          }
        }

        // Stop button is calm and transparent at rest, tinted error on hover.
        final stopButton = tester.widget<IconButton>(
          find.byKey(const ValueKey('running_session_stop_button')),
        );
        final restBg = stopButton.style?.backgroundColor?.resolve({});
        final restFg = stopButton.style?.foregroundColor?.resolve({});
        final hoverFg = stopButton.style?.foregroundColor?.resolve({
          WidgetState.hovered,
        });
        expect(restBg, Colors.transparent);
        expect(restFg, isNot(AppTheme.darkTheme.colorScheme.error));
        expect(hoverFg, AppTheme.darkTheme.colorScheme.error);
      },
    );

    testWidgets('SectionHeader renders cleanly without gradient underline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AppTheme.lightTheme,
          const SectionHeader(
            icon: Icons.history,
            label: 'RECENT SESSIONS',
            color: Color(0xFF52525B),
          ),
        ),
      );

      expect(find.text('RECENT SESSIONS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SectionHeader),
          matching: find.byType(Container),
        ),
        findsNothing,
      );
    });
  });

  group('NewSessionSheetActions CTA contrast', () {
    for (final entry in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      for (final provider in Provider.values) {
        testWidgets(
          '${provider.label} CTA is solid with WCAG AA (>=4.5:1) contrast in ${entry.key} mode',
          (tester) async {
            late ProviderStyle style;
            await tester.pumpWidget(
              _app(
                entry.value,
                Builder(
                  builder: (context) {
                    style = providerStyleFor(context, provider);
                    return NewSessionSheetActions(
                      provider: provider,
                      canStart: true,
                      onStart: () {},
                    );
                  },
                ),
              ),
            );

            final button = tester.widget<FilledButton>(
              find.byKey(const ValueKey('dialog_start_button')),
            );
            final bg = button.style!.backgroundColor!.resolve({})!;
            final fg = button.style!.foregroundColor!.resolve({})!;

            expect(bg, style.foreground);
            expect(bg.a, 1.0);
            expect(
              _contrastRatio(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason:
                  '${provider.label} (${entry.key}) contrast between $fg and $bg',
            );
          },
        );
      }
    }
  });

  group('Settings visual polish', () {
    testWidgets(
      'SettingsCategoryBadge renders flat tinted squircle without gradient or shadow',
      (tester) async {
        final badgeColor = SettingsCategory.connection.color(Brightness.light);
        await tester.pumpWidget(
          _app(
            AppTheme.lightTheme,
            SettingsCategoryBadge(
              icon: SettingsCategory.connection.icon,
              color: badgeColor,
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(SettingsCategoryBadge),
            matching: find.byType(Container),
          ),
        );
        final deco = container.decoration! as BoxDecoration;
        expect(deco.gradient, isNull);
        expect(deco.boxShadow, isNull);
        expect(deco.color, badgeColor.withValues(alpha: 0.12));
        expect(deco.border, isNotNull);

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(SettingsCategoryBadge),
            matching: find.byType(Icon),
          ),
        );
        expect(icon.color, badgeColor);
      },
    );

    testWidgets(
      'SettingsStatusCard uses neutral elevated surface without gradient',
      (tester) async {
        await tester.pumpWidget(
          _app(
            AppTheme.darkTheme,
            SettingsStatusCard(
              state: const SettingsState(),
              visibility: const SettingsVisibility(
                hasActiveMachine: false,
                bridgeConnected: false,
                hasBridgeUrl: false,
              ),
              onOpenCategory: (_) {},
              onUpdateBridge: (_) {},
            ),
          ),
        );

        final boxes = tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SettingsStatusCard),
            matching: find.byType(DecoratedBox),
          ),
        );
        var foundSurfaceBox = false;
        for (final box in boxes) {
          final deco = box.decoration;
          if (deco is BoxDecoration) {
            expect(deco.gradient, isNull);
            if (deco.color ==
                AppTheme.darkTheme.colorScheme.surfaceContainerHigh) {
              expect(deco.border, isNotNull);
              foundSurfaceBox = true;
            }
          }
        }
        expect(foundSurfaceBox, isTrue);
      },
    );
  });
}
