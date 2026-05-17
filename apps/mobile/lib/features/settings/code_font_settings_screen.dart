import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../models/code_font_family.dart';
import '../../theme/code_text_style.dart';
import 'state/settings_cubit.dart';
import 'state/settings_state.dart';

const _previewLines = [
  'const session = await client.start(projectPath);',
  'if (status !== "running") return;',
  'git diff -- src/components/editor.ts',
  '+ codeFontSize: 12.0',
  '- fontFamily: "monospace"',
  '{ "mode": "plan", "approval": "on-request" }',
];

class CodeFontSettingsScreen extends StatelessWidget {
  const CodeFontSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.codeFontFamily)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = CodeTextSettings(
            family: state.codeFontFamily,
            fontSize: state.codeFontSize,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CodePreviewCard(settings: settings),
              const SizedBox(height: 20),
              _CodeFontSizeControl(
                value: state.codeFontSize,
                onChanged: context.read<SettingsCubit>().setCodeFontSize,
              ),
              const SizedBox(height: 20),
              _CodeFontFamilyList(
                current: state.codeFontFamily,
                onChanged: context.read<SettingsCubit>().setCodeFontFamily,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CodePreviewCard extends StatelessWidget {
  const _CodePreviewCard({required this.settings});

  final CodeTextSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            l.codeFontPreview,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _previewLines.length; i++)
                  _CodePreviewLine(
                    lineNumber: i + 1,
                    text: _previewLines[i],
                    settings: settings,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodePreviewLine extends StatelessWidget {
  const _CodePreviewLine({
    required this.lineNumber,
    required this.text,
    required this.settings,
  });

  final int lineNumber;
  final String text;
  final CodeTextSettings settings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lineNumberStyle = settings.style(
      color: cs.onSurfaceVariant,
      fontSize: (settings.fontSize - 2).clamp(minCodeFontSize, maxCodeFontSize),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$lineNumber',
              textAlign: TextAlign.right,
              style: lineNumberStyle,
            ),
          ),
          const SizedBox(width: 12),
          Text(text, style: settings.style(color: cs.onSurface)),
        ],
      ),
    );
  }
}

class _CodeFontSizeControl extends StatelessWidget {
  const _CodeFontSizeControl({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final size = value.round();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(child: Text(l.codeFontSize)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('code_font_size_decrease_button'),
                    icon: const Icon(Icons.remove),
                    visualDensity: VisualDensity.compact,
                    onPressed: size <= minCodeFontSize
                        ? null
                        : () => onChanged(value - 1),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${size}pt',
                      key: const ValueKey('code_font_size_value_label'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('code_font_size_increase_button'),
                    icon: const Icon(Icons.add),
                    visualDensity: VisualDensity.compact,
                    onPressed: size >= maxCodeFontSize
                        ? null
                        : () => onChanged(value + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeFontFamilyList extends StatelessWidget {
  const _CodeFontFamilyList({required this.current, required this.onChanged});

  final CodeFontFamily current;
  final ValueChanged<CodeFontFamily> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: RadioGroup<CodeFontFamily>(
        groupValue: current,
        onChanged: (value) {
          if (value == null) return;
          onChanged(value);
        },
        child: Column(
          children: [
            for (var i = 0; i < CodeFontFamily.values.length; i++) ...[
              _CodeFontFamilyTile(family: CodeFontFamily.values[i]),
              if (i != CodeFontFamily.values.length - 1)
                const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _CodeFontFamilyTile extends StatelessWidget {
  const _CodeFontFamilyTile({required this.family});

  final CodeFontFamily family;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<CodeFontFamily>(
      key: ValueKey('code_font_family_${family.id}_radio'),
      value: family,
      title: Text(
        family.label,
        style: TextStyle(fontFamily: family.fontFamily),
      ),
    );
  }
}
