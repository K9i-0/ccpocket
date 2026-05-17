import 'package:ccpocket/features/settings/code_font_settings_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/code_font_family.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('code font settings previews and updates inline', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cubit = SettingsCubit(prefs);

    await tester.pumpWidget(
      BlocProvider<SettingsCubit>.value(
        value: cubit,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CodeFontSettingsScreen(),
        ),
      ),
    );

    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('12pt'), findsOneWidget);
    expect(
      find.text('const session = await client.start(projectPath);'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('code_font_size_increase_button')),
    );
    await tester.pump();

    expect(find.text('13pt'), findsOneWidget);
    expect(cubit.state.codeFontSize, 13);

    await tester.tap(
      find.byKey(const ValueKey('code_font_family_dejaVuSansMono_radio')),
    );
    await tester.pump();

    expect(cubit.state.codeFontFamily, CodeFontFamily.dejaVuSansMono);

    await cubit.close();
  });
}
