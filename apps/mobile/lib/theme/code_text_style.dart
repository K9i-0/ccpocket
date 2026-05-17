import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/settings/state/settings_cubit.dart';
import '../models/code_font_family.dart';

const defaultCodeFontSize = 12.0;
const minCodeFontSize = 8.0;
const maxCodeFontSize = 24.0;
const codeLineHeight = 1.45;

const _fontFallbacks = ['monospace'];

class CodeTextSettings {
  final CodeFontFamily family;
  final double fontSize;

  const CodeTextSettings({
    this.family = CodeFontFamily.jetBrainsMono,
    this.fontSize = defaultCodeFontSize,
  });

  TextStyle style({
    Color? color,
    double? fontSize,
    double height = codeLineHeight,
    FontWeight? fontWeight,
    Color? backgroundColor,
  }) {
    return TextStyle(
      fontFamily: family.fontFamily,
      fontFamilyFallback: _fontFallbacks,
      fontSize: fontSize ?? this.fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color,
      backgroundColor: backgroundColor,
    );
  }
}

CodeTextSettings codeTextSettingsOf(BuildContext context) {
  SettingsCubit? cubit;
  try {
    cubit = BlocProvider.of<SettingsCubit>(context);
  } catch (_) {
    cubit = null;
  }
  final state = cubit?.state;
  if (state == null) return const CodeTextSettings();
  return CodeTextSettings(
    family: state.codeFontFamily,
    fontSize: state.codeFontSize,
  );
}
