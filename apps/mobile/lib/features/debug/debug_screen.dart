import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

import '../../core/logger.dart';
import '../../router/app_router.dart';

@RoutePage()
class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Logs'),
            subtitle: const Text('View application logs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TalkerScreen(talker: logger),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Mock Preview'),
            subtitle: const Text('View mock chat scenarios'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.router.push(MockPreviewRoute()),
          ),
        ],
      ),
    );
  }
}
