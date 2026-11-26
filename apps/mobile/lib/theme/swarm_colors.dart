import 'package:flutter_svg/flutter_svg.dart';
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
  Color(0xFF195CE6), // blue
  Color(0xFF047954), // emerald
  Color(0xFFCA1664), // pink
  Color(0xFF7524EB), // violet
  Color(0xFF027392), // cyan
  Color(0xFF447306), // lime
  Color(0xFFB316C4), // fuchsia
  Color(0xFF52525B), // gray
];

/// More vivid light-mode fills for non-text elements (creature icons and card
/// accent strips). Keeps the same hues as [swarmWorkerColorsLight] while using
/// WCAG non-text contrast (>= 3.0) so creatures stay bright on light surfaces.
const swarmWorkerIconColorsLight = <Color>[
  Color(0xFF2563EB), // blue
  Color(0xFF059669), // emerald
  Color(0xFFEC2B7C), // pink
  Color(0xFF8B3DFF), // violet
  Color(0xFF0592B5), // cyan
  Color(0xFF559205), // lime
  Color(0xFFD22CE0), // fuchsia
  Color(0xFF63636B), // gray
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

/// The icon/graphic colour of the worker at [index] (from 0). In dark mode this
/// matches [swarmWorkerColor]; in light mode it uses the brighter
/// [swarmWorkerIconColorsLight] palette.
Color swarmWorkerIconColor(Brightness brightness, int index) {
  final palette = brightness == Brightness.dark
      ? swarmWorkerColorsDark
      : swarmWorkerIconColorsLight;
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

/// The icon/graphic colour of a swarm member.
Color swarmMemberIconColor(
  BuildContext context, {
  required bool isCoordinator,
  int? index,
}) {
  final theme = Theme.of(context);
  if (isCoordinator) return theme.colorScheme.primary;
  if (index == null || index < 0) return theme.colorScheme.tertiary;
  return swarmWorkerIconColor(theme.brightness, index);
}

/// Asset path of the monochrome creature mark for the swarm coordinator.
const swarmCoordinatorIconAsset = 'assets/icons/swarm_octopus.svg';

/// Asset paths of the monochrome creature marks for numbered swarm workers,
/// paired 1:1 with [swarmWorkerColorsLight] and [swarmWorkerColorsDark].
const swarmWorkerIconAssets = <String>[
  'assets/icons/swarm_shark.svg',
  'assets/icons/swarm_turtle.svg',
  'assets/icons/swarm_flamingo.svg',
  'assets/icons/swarm_bat.svg',
  'assets/icons/swarm_cat.svg',
  'assets/icons/swarm_dino.svg',
  'assets/icons/swarm_fox.svg',
  'assets/icons/swarm_hedgehog.svg',
];

/// The creature icon asset of the worker that joined its swarm at [index]
/// (from 0).
String swarmWorkerIconAsset(int index) =>
    swarmWorkerIconAssets[index % swarmWorkerIconAssets.length];

/// Icon for a swarm member: an octopus SVG for the coordinator, a fixed
/// monochrome creature SVG matched to the member's palette slot for numbered
/// workers, and the legacy robot icon when an older Bridge sends no worker
/// index.
class SwarmMemberIcon extends StatelessWidget {
  final bool isCoordinator;
  final int? index;
  final double size;
  final Color? color;

  const SwarmMemberIcon({
    super.key,
    this.isCoordinator = false,
    this.index,
    required this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ??
        swarmMemberIconColor(
          context,
          isCoordinator: isCoordinator,
          index: index,
        );
    final String asset;
    if (isCoordinator) {
      asset = swarmCoordinatorIconAsset;
    } else {
      final workerIndex = index;
      if (workerIndex == null || workerIndex < 0) {
        return Icon(Icons.smart_toy_outlined, size: size, color: resolvedColor);
      }
      asset = swarmWorkerIconAsset(workerIndex);
    }
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
