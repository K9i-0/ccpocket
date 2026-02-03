import 'package:flutter/material.dart';

import '../../../services/server_discovery_service.dart';
import '../../../services/url_history_service.dart';
import 'discovered_servers_list.dart';
import 'url_history_list.dart';

class ConnectForm extends StatelessWidget {
  final TextEditingController urlController;
  final TextEditingController apiKeyController;
  final List<DiscoveredServer> discoveredServers;
  final List<UrlHistoryEntry> urlHistory;
  final VoidCallback onConnect;
  final VoidCallback onScanQrCode;
  final ValueChanged<DiscoveredServer> onConnectToDiscovered;
  final ValueChanged<UrlHistoryEntry> onSelectUrlHistory;
  final ValueChanged<String> onRemoveUrlHistory;

  const ConnectForm({
    super.key,
    required this.urlController,
    required this.apiKeyController,
    required this.discoveredServers,
    required this.urlHistory,
    required this.onConnect,
    required this.onScanQrCode,
    required this.onConnectToDiscovered,
    required this.onSelectUrlHistory,
    required this.onRemoveUrlHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.terminal,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Connect to Bridge Server',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          if (discoveredServers.isNotEmpty) ...[
            DiscoveredServersList(
              servers: discoveredServers,
              onConnect: onConnectToDiscovered,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or enter manually',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (urlHistory.isNotEmpty) ...[
            UrlHistoryList(
              entries: urlHistory,
              onSelect: onSelectUrlHistory,
              onRemove: onRemoveUrlHistory,
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const ValueKey('server_url_field'),
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'ws://<host-ip>:8765',
              prefixIcon: Icon(Icons.dns),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('api_key_field'),
            controller: apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key (optional)',
              hintText: 'Leave empty if no auth',
              prefixIcon: Icon(Icons.key),
              border: OutlineInputBorder(),
            ),
            obscureText: true,
            onSubmitted: (_) => onConnect(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              key: const ValueKey('connect_button'),
              onPressed: onConnect,
              icon: const Icon(Icons.link),
              label: const Text('Connect'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const ValueKey('scan_qr_button'),
              onPressed: onScanQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
            ),
          ),
        ],
      ),
    );
  }
}
