import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/legacy_material_bridge.dart';
// The legacy library is what the bridged dependencies read.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _button = Key('button');
const _icon = Key('icon');
const _text = Key('text');

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required bool bridged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      theme: theme,
      builder: (context, child) =>
          bridged ? LegacyMaterialBridge(child: child!) : child!,
      home: Scaffold(
        body: Column(
          children: [
            IconButton(
              key: _button,
              onPressed: () {},
              icon: const Icon(Icons.copy),
            ),
            const Icon(Icons.info, key: _icon),
            const Text('text', key: _text),
          ],
        ),
      ),
    ),
  );
}

Color? _glyphColor(WidgetTester tester, Key key) {
  final glyph = tester.widget<RichText>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
  );
  return glyph.text.style?.color;
}

void main() {
  final themes = {'light': AppTheme.lightTheme, 'dark': AppTheme.darkTheme};

  for (final MapEntry(key: name, value: theme) in themes.entries) {
    testWidgets('$name: the bridge keeps the app icon colors', (tester) async {
      await _pump(tester, theme, bridged: false);
      final button = _glyphColor(tester, _button);
      final icon = _glyphColor(tester, _icon);
      expect(button, isNotNull);

      await _pump(tester, theme, bridged: true);
      expect(_glyphColor(tester, _button), button);
      expect(_glyphColor(tester, _icon), icon);
    });

    testWidgets('$name: legacy widgets see the app color scheme', (
      tester,
    ) async {
      await _pump(tester, theme, bridged: true);
      final context = tester.element(find.byKey(_text));
      final legacyTheme = legacy.Theme.of(context);
      expect(legacyTheme.colorScheme.primary, theme.colorScheme.primary);
      expect(legacyTheme.brightness, theme.brightness);
      expect(legacy.MaterialLocalizations.of(context), isNotNull);
    });
  }
}
