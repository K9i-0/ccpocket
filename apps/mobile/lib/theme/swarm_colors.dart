import 'package:material_ui/material_ui.dart';

/// Colours for the workers of an Antigravity swarm.
///
/// The Bridge numbers workers from 0 in the order they joined; a worker takes
/// the colour at its number, so it keeps one colour for the whole swarm and
/// nothing is left to chance. A swarm has no fixed size limit, so beyond the
/// palette the colours repeat.
///
/// The hues stay clear of what already means something in a transcript: the
/// coordinator's primary orange, amber for warnings and red for errors.
/// The first few are the furthest apart, because most swarms use only those.
/// Eight is as many as stay tellable apart under these limits: each reads as
/// 12px text on the theme's surface (WCAG AA) and keeps its distance from
/// every other one and from the reserved colours (`swarm_colors_test.dart`).
const swarmWorkerColorsLight = <Color>[
  Color(0xFF1D4ED8), // blue
  Color(0xFF047857), // emerald
  Color(0xFFBE185D), // pink
  Color(0xFF6D28D9), // violet
  Color(0xFF0C6F87), // cyan
  Color(0xFF3F6212), // lime
  Color(0xFFA21CAF), // fuchsia
  Color(0xFF3F3F46), // gray
];

const swarmWorkerColorsDark = <Color>[
  Color(0xFF60A5FA), // blue
  Color(0xFF34D399), // emerald
  Color(0xFFF472B6), // pink
  Color(0xFFA78BFA), // violet
  Color(0xFF22D3EE), // cyan
  Color(0xFFA3E635), // lime
  Color(0xFFE879F9), // fuchsia
  Color(0xFFA1A1AA), // gray
];

/// The colour of the worker that joined its swarm at [index] (from 0).
Color swarmWorkerColor(Brightness brightness, int index) {
  final palette = brightness == Brightness.dark
      ? swarmWorkerColorsDark
      : swarmWorkerColorsLight;
  return palette[index % palette.length];
}

/// The colour of a swarm member: the coordinator's is the theme's primary, a
/// numbered worker's comes from the palette. A worker without a number (an
/// older Bridge sends none) keeps the single colour workers had before.
Color swarmMemberColor(
  BuildContext context, {
  required bool isCoordinator,
  int? index,
}) {
  final theme = Theme.of(context);
  if (isCoordinator) return theme.colorScheme.primary;
  if (index == null || index < 0) return theme.colorScheme.tertiary;
  return swarmWorkerColor(theme.brightness, index);
}
