import 'package:material_ui/material_ui.dart';

/// Gives dependencies that still import `package:flutter/material.dart`
/// (flutter_markdown, skeletonizer, talker_flutter, ...) the legacy Theme and
/// MaterialLocalizations, which package:material_ui no longer provides.
///
/// Remove together with the bridge once those dependencies have migrated.
class LegacyMaterialBridge extends StatelessWidget {
  const LegacyMaterialBridge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      // The legacy Theme the bridge inserts also installs its own IconTheme,
      // which would recolor every Icon and IconButton of the app (black87
      // instead of the scheme's onSurface, pure white in dark mode). Putting
      // the app's Theme back below it restores what MaterialApp provides.
      child: Theme(data: Theme.of(context), child: child),
    );
  }
}
