import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The GitHub mark, tinted like an [Icon] by the surrounding [IconTheme].
class GitHubMarkIcon extends StatelessWidget {
  final double? size;
  final Color? color;

  const GitHubMarkIcon({super.key, this.size, this.color});

  static const _asset = 'assets/icons/github_mark.svg';

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final size = this.size ?? iconTheme.size ?? 24;
    final color =
        this.color ??
        iconTheme.color ??
        Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      _asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}
