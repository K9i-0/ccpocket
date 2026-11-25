import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../../local_bridge/data/local_bridge_models.dart';
import '../../local_bridge/widgets/local_bridge_tools_card.dart';
import 'settings_tiles.dart';

/// Fetches `GET /tools` from the currently connected Bridge (local or remote)
/// using Bearer API key auth and displays installed CLIs via
/// [LocalBridgeToolsCard].
class ConnectedBridgeToolsCard extends StatefulWidget {
  const ConnectedBridgeToolsCard({
    super.key,
    required this.bridge,
    this.httpClient,
  });

  final BridgeService bridge;

  /// Optional client override for unit/widget tests.
  final http.Client? httpClient;

  @override
  State<ConnectedBridgeToolsCard> createState() =>
      _ConnectedBridgeToolsCardState();
}

class _ConnectedBridgeToolsCardState extends State<ConnectedBridgeToolsCard> {
  late final http.Client _client;
  late final bool _ownsClient;
  LocalBridgeTools? _tools;
  bool _loading = false;
  bool _unsupported = false;
  bool _failed = false;
  String? _loadedBaseUrl;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.httpClient == null;
    _client = widget.httpClient ?? http.Client();
    unawaited(_load(refresh: false));
  }

  @override
  void didUpdateWidget(ConnectedBridgeToolsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBaseUrl = widget.bridge.httpBaseUrl;
    if (nextBaseUrl != _loadedBaseUrl && widget.bridge.isConnected) {
      unawaited(_load(refresh: false));
    }
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
    super.dispose();
  }

  Future<void> _load({required bool refresh}) async {
    final baseUrl = widget.bridge.httpBaseUrl;
    if (!widget.bridge.isConnected || baseUrl == null || baseUrl.isEmpty) {
      return;
    }
    final generation = ++_generation;
    _loadedBaseUrl = baseUrl;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final uri = Uri.parse(
      refresh ? '$baseUrl/tools?refresh=1' : '$baseUrl/tools',
    );
    try {
      final response = await _client
          .get(uri, headers: widget.bridge.bridgeAuthHeaders)
          .timeout(const Duration(seconds: 20));
      if (!mounted || generation != _generation) return;
      if (response.statusCode == 404) {
        setState(() {
          _loading = false;
          _unsupported = true;
          _failed = false;
          _tools = null;
        });
        return;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map) {
          final report = LocalBridgeTools.fromJson(
            decoded.cast<String, Object?>(),
          );
          setState(() {
            _loading = false;
            _unsupported = false;
            _failed = false;
            _tools = report;
          });
          return;
        }
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final baseUrl = widget.bridge.httpBaseUrl;
    if (!widget.bridge.isConnected || baseUrl == null || baseUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    // Gracefully hide when connected to an older Bridge without /tools.
    if (_unsupported) {
      return const SizedBox.shrink();
    }

    return Column(
      key: const ValueKey('connected_bridge_tools_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: l.settingsConnectedBridgeToolsTitle),
        if (_failed && _tools == null)
          SettingsCard(
            key: const ValueKey('connected_bridge_tools_error_card'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.settingsConnectedBridgeToolsError,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('connected_bridge_tools_retry_button'),
                    onPressed: _loading ? null : () => _load(refresh: true),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l.localBridgeToolRecheck),
                  ),
                ],
              ),
            ),
          )
        else
          LocalBridgeToolsCard(
            tools: _tools,
            loading: _loading,
            unsupported: false,
            onRecheck: () => _load(refresh: true),
          ),
      ],
    );
  }
}
