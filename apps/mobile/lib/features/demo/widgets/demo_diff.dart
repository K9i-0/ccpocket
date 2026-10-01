import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/diff_parser.dart';
import '../../git/widgets/diff_hunk_widget.dart';

const demoDiff = '''diff --git a/lib/welcome.dart b/lib/welcome.dart
--- a/lib/welcome.dart
+++ b/lib/welcome.dart
@@ -1,3 +1,3 @@
 String welcome() {
-  return 'Hello';
+  return 'Hello, Pocket!';
 }
''';

class DemoDiff extends StatelessWidget {
  const DemoDiff({super.key});

  static final _file = parseDiff(demoDiff).single;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('demo_diff_button'),
        initiallyExpanded: true,
        title: const Text('lib/welcome.dart'),
        subtitle: Text(l.demoDiffSummary),
        children: [
          DiffHunkWidget(
            hunk: _file.hunks.single,
            lineNumberWidth: 28,
            dismissKey: 'demo-diff',
            lineWrapEnabled: true,
          ),
        ],
      ),
    );
  }
}
