import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../router/app_router.dart';

@RoutePage()
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.debug)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l.logs),
            subtitle: Text(l.viewApplicationLogs),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TalkerScreen(talker: logger),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science),
            title: Text(l.mockPreview),
            subtitle: Text(l.viewMockChatScenarios),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.router.push(MockPreviewRoute()),
          ),
        ],
      ),
    );
  }
}
