import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppColors equality and hashCode', () {
    test('equal instances compare equal and share the same hashCode', () {
      final lightA = AppColors.light();
      final lightB = AppColors.light().copyWith();
      expect(lightA, equals(lightB));
      expect(lightA.hashCode, equals(lightB.hashCode));

      final darkA = AppColors.dark();
      final darkB = AppColors.dark().copyWith();
      expect(darkA, equals(darkB));
      expect(darkA.hashCode, equals(darkB.hashCode));
    });

    test('light and dark instances are not equal', () {
      expect(AppColors.light(), isNot(equals(AppColors.dark())));
      expect(AppColors.light() == Object(), isFalse);
    });

    test('lerp endpoints match source and target instances', () {
      final light = AppColors.light();
      final dark = AppColors.dark();
      expect(light.lerp(dark, 0.0), equals(light));
      expect(light.lerp(dark, 0.0).hashCode, equals(light.hashCode));
      expect(light.lerp(dark, 1.0), equals(dark));
      expect(light.lerp(dark, 1.0).hashCode, equals(dark.hashCode));
    });

    test('changing any single field breaks equality', () {
      final base = AppColors.light();
      const alt = Color(0xFF123456);

      final mutations = <String, AppColors>{
        'userBubble': base.copyWith(userBubble: alt),
        'userBubbleText': base.copyWith(userBubbleText: alt),
        'assistantBubble': base.copyWith(assistantBubble: alt),
        'toolBubble': base.copyWith(toolBubble: alt),
        'toolBubbleBorder': base.copyWith(toolBubbleBorder: alt),
        'toolIcon': base.copyWith(toolIcon: alt),
        'errorBubble': base.copyWith(errorBubble: alt),
        'errorBubbleBorder': base.copyWith(errorBubbleBorder: alt),
        'errorText': base.copyWith(errorText: alt),
        'warningBubble': base.copyWith(warningBubble: alt),
        'warningBubbleBorder': base.copyWith(warningBubbleBorder: alt),
        'warningText': base.copyWith(warningText: alt),
        'permissionBubble': base.copyWith(permissionBubble: alt),
        'permissionBubbleBorder': base.copyWith(permissionBubbleBorder: alt),
        'permissionIcon': base.copyWith(permissionIcon: alt),
        'askBubble': base.copyWith(askBubble: alt),
        'askBubbleBorder': base.copyWith(askBubbleBorder: alt),
        'askIcon': base.copyWith(askIcon: alt),
        'systemChip': base.copyWith(systemChip: alt),
        'successChip': base.copyWith(successChip: alt),
        'errorChip': base.copyWith(errorChip: alt),
        'approvalBar': base.copyWith(approvalBar: alt),
        'approvalBarBorder': base.copyWith(approvalBarBorder: alt),
        'statusStarting': base.copyWith(statusStarting: alt),
        'statusRunning': base.copyWith(statusRunning: alt),
        'statusApproval': base.copyWith(statusApproval: alt),
        'statusCompacting': base.copyWith(statusCompacting: alt),
        'statusIdle': base.copyWith(statusIdle: alt),
        'statusOnline': base.copyWith(statusOnline: alt),
        'statusPlan': base.copyWith(statusPlan: alt),
        'statusPlanGlow': base.copyWith(statusPlanGlow: alt),
        'subtleText': base.copyWith(subtleText: alt),
        'codeBackground': base.copyWith(codeBackground: alt),
        'codeBorder': base.copyWith(codeBorder: alt),
        'toolResultBackground': base.copyWith(toolResultBackground: alt),
        'toolResultText': base.copyWith(toolResultText: alt),
        'toolResultTextExpanded': base.copyWith(toolResultTextExpanded: alt),
        'diffAdditionBackground': base.copyWith(diffAdditionBackground: alt),
        'diffAdditionText': base.copyWith(diffAdditionText: alt),
        'diffDeletionBackground': base.copyWith(diffDeletionBackground: alt),
        'diffDeletionText': base.copyWith(diffDeletionText: alt),
      };

      expect(mutations.length, 41);
      for (final entry in mutations.entries) {
        expect(
          base,
          isNot(equals(entry.value)),
          reason: 'mutating ${entry.key} must affect equality',
        );
      }
    });
  });

  group('AppTheme ThemeData equality', () {
    test('repeated theme builds for the same locale compare equal', () {
      expect(AppTheme.lightTheme, equals(AppTheme.lightTheme));
      expect(AppTheme.darkTheme, equals(AppTheme.darkTheme));
      expect(
        AppTheme.lightThemeForLocale(const Locale('zh')),
        equals(AppTheme.lightThemeForLocale(const Locale('zh'))),
      );
      expect(
        AppTheme.darkThemeForLocale(const Locale('zh')),
        equals(AppTheme.darkThemeForLocale(const Locale('zh'))),
      );
      expect(AppTheme.lightTheme, isNot(equals(AppTheme.darkTheme)));
    });

    test('uses platform system fonts by default and applies zh fallback for zh locale', () {
      final platformFont = ThemeData(useMaterial3: true)
          .textTheme
          .bodyMedium
          ?.fontFamily;
      final defaultTheme = AppTheme.lightTheme;
      expect(defaultTheme.textTheme.bodyMedium?.fontFamily, platformFont);
      expect(defaultTheme.textTheme.headlineSmall?.fontFamily, platformFont);
      expect(defaultTheme.textTheme.bodyMedium?.fontFamilyFallback, isNull);

      final zhTheme = AppTheme.lightThemeForLocale(const Locale('zh'));
      expect(zhTheme.textTheme.bodyMedium?.fontFamily, platformFont);
      expect(
        zhTheme.textTheme.bodyMedium?.fontFamilyFallback,
        containsAll(['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC']),
      );
    });
  });
}
