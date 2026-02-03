import 'package:flutter/material.dart';

import '../../../services/server_discovery_service.dart';

class DiscoveredServersList extends StatelessWidget {
  final List<DiscoveredServer> servers;
  final ValueChanged<DiscoveredServer> onConnect;

  const DiscoveredServersList({
    super.key,
    required this.servers,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.wifi_find,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Discovered Servers',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final server in servers)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: Icon(
                Icons.dns,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                server.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                server.wsUrl,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: server.authRequired
                  ? Icon(
                      Icons.lock,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    )
                  : Icon(
                      Icons.lock_open,
                      size: 16,
                      color: Theme.of(context).colorScheme.outline,
                    ),
              onTap: () => onConnect(server),
            ),
          ),
      ],
    );
  }
}
