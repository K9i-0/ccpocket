import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/machine.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../providers/server_discovery_cubit.dart';
import '../../router/app_router.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/server_discovery_service.dart';
import '../session_list/widgets/connect_form.dart';
import '../session_list/widgets/machine_edit_sheet.dart';
import '../../screens/qr_scan_screen.dart';
import '../settings/settings_screen.dart';

/// Screen shown when the app is not connected to a Bridge server.
///
/// Extracted from [SessionListScreen] to work with auto_route's
/// [ConnectionGuard]. When connection succeeds the guard automatically
/// navigates away from this screen.
@RoutePage()
class ConnectionScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;

  const ConnectionScreen({super.key, this.deepLinkNotifier});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  bool _isAutoConnecting = false;

  static const _prefKeyUrl = 'bridge_url';
  static const _prefKeyApiKey = 'bridge_api_key';

  @override
  void initState() {
    super.initState();
    widget.deepLinkNotifier?.addListener(_onDeepLink);
    _loadPreferencesAndAutoConnect();
  }

  void _onDeepLink() {
    final params = widget.deepLinkNotifier?.value;
    if (params == null) return;
    widget.deepLinkNotifier?.value = null;
    _urlController.text = params.serverUrl;
    if (params.token != null) {
      _apiKeyController.text = params.token!;
    }
    _connect();
  }

  Future<void> _loadPreferencesAndAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final url = prefs.getString(_prefKeyUrl);
    final apiKey = prefs.getString(_prefKeyApiKey);
    if (url != null && url.isNotEmpty) {
      _urlController.text = url;
    }
    if (apiKey != null && apiKey.isNotEmpty) {
      _apiKeyController.text = apiKey;
    }
    if (url != null && url.isNotEmpty) {
      setState(() => _isAutoConnecting = true);
      final attempted = await context.read<BridgeService>().autoConnect();
      if (!attempted && mounted) {
        setState(() => _isAutoConnecting = false);
      }
    }
  }

  Future<void> _connect() async {
    var url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('ws://') && !url.startsWith('wss://')) {
      url = 'ws://$url';
      _urlController.text = url;
    }

    final health = await BridgeService.checkHealth(url);
    if (health == null && mounted) {
      final shouldConnect = await _showSetupGuide(url);
      if (shouldConnect != true) return;
    }

    if (!mounted) return;
    final apiKey = _apiKeyController.text.trim();
    final machineManagerCubit = context.read<MachineManagerCubit?>();
    if (machineManagerCubit != null) {
      final uri = Uri.tryParse(
        url.replaceFirst('ws://', 'http://').replaceFirst('wss://', 'https://'),
      );
      if (uri != null) {
        await machineManagerCubit.recordConnection(
          host: uri.host,
          port: uri.port != 0 ? uri.port : 8765,
          apiKey: apiKey.isNotEmpty ? apiKey : null,
        );
      }
    }

    if (!mounted) return;
    var connectUrl = url;
    if (apiKey.isNotEmpty) {
      final sep = connectUrl.contains('?') ? '&' : '?';
      connectUrl = '$connectUrl${sep}token=$apiKey';
    }
    final bridge = context.read<BridgeService>();
    bridge.connect(connectUrl);
    bridge.savePreferences(
      _urlController.text.trim(),
      _apiKeyController.text.trim(),
    );
  }

  Future<bool?> _showSetupGuide(String url) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            SizedBox(width: 8),
            Expanded(child: Text('Server Unreachable')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not reach the Bridge server at:',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                url,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Setup Steps:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _setupStep(
                ctx,
                '1',
                'Install and build the Bridge server',
                'cd packages/bridge && npm install && npm run bridge:build',
              ),
              _setupStep(ctx, '2', 'Start the server', 'npm run bridge'),
              _setupStep(
                ctx,
                '3',
                'For persistent startup, register as service',
                'npm run setup',
              ),
              const SizedBox(height: 12),
              Text(
                'Make sure both devices are on the same network (or use Tailscale).',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Connect Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _setupStep(
    BuildContext ctx,
    String number,
    String title,
    String command,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(ctx).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    command,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<ConnectionParams>(
      MaterialPageRoute<ConnectionParams>(
        builder: (_) => const QrScanScreen(),
      ),
    );
    if (result != null && mounted) {
      _urlController.text = result.serverUrl;
      if (result.token != null) {
        _apiKeyController.text = result.token!;
      }
      _connect();
    }
  }

  @override
  void dispose() {
    widget.deepLinkNotifier?.removeListener(_onDeepLink);
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  // ---- Machine Management ----

  void _connectToDiscovered(DiscoveredServer server) {
    _urlController.text = server.wsUrl;
    _apiKeyController.clear();
    if (server.authRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This server requires an API key')),
      );
      return;
    }
    _connect();
  }

  void _connectToMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final wsUrl = await cubit.buildWsUrl(m.machine.id);
    _urlController.text = m.machine.wsUrl;
    final apiKey = await cubit.getApiKey(m.machine.id);
    _apiKeyController.text = apiKey ?? '';

    await cubit.recordConnection(
      host: m.machine.host,
      port: m.machine.port,
      apiKey: apiKey,
    );

    if (!mounted) return;
    final bridge = context.read<BridgeService>();
    bridge.connect(wsUrl);
    bridge.savePreferences(m.machine.wsUrl, apiKey ?? '');
  }

  void _toggleFavorite(MachineWithStatus m) {
    context.read<MachineManagerCubit>().toggleFavorite(m.machine.id);
  }

  void _updateMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return;
    }

    final success = await cubit.updateBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bridge Server updated')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update server')),
      );
    }
  }

  void _startMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return;
    }

    final success = await cubit.startBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bridge Server started')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to start server')),
      );
    }
  }

  void _stopMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final savedPassword = await cubit.getSshPassword(m.machine.id);
    String? password = savedPassword;

    if (password == null || password.isEmpty) {
      password = await _promptForPassword(m.machine.displayName);
      if (password == null) return;
    }

    final success = await cubit.stopBridge(m.machine.id, password: password);

    if (success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bridge Server stopped')));
    } else if (mounted) {
      final error = cubit.state.error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Failed to stop server')));
    }
  }

  Future<String?> _promptForPassword(String machineName) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('SSH Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter SSH password for $machineName'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _editMachine(MachineWithStatus m) async {
    final cubit = context.read<MachineManagerCubit>();
    final apiKey = await cubit.getApiKey(m.machine.id);
    final sshPassword = await cubit.getSshPassword(m.machine.id);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MachineEditSheet(
        machine: m.machine,
        existingApiKey: apiKey,
        existingSshPassword: sshPassword,
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          await cubit.updateMachine(
            machine,
            apiKey: apiKey,
            sshPassword: sshPassword,
            sshPrivateKey: sshPrivateKey,
          );
        },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }

  void _deleteMachine(MachineWithStatus m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Machine'),
        content: Text(
          'Delete "${m.machine.displayName}"? This will remove all saved credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<MachineManagerCubit>().deleteMachine(m.machine.id);
    }
  }

  void _addMachine() {
    final cubit = context.read<MachineManagerCubit>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MachineEditSheet(
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          final newMachine = cubit.createNewMachine(
            name: machine.name,
            host: machine.host,
            port: machine.port,
          );
          await cubit.addMachine(
            newMachine.copyWith(
              sshEnabled: machine.sshEnabled,
              sshUsername: machine.sshUsername,
              sshPort: machine.sshPort,
              sshAuthType: machine.sshAuthType,
              isFavorite: true,
            ),
            apiKey: apiKey,
            sshPassword: sshPassword,
            sshPrivateKey: sshPrivateKey,
          );
        },
        onTestConnection: cubit.testConnectionWithCredentials,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = context.watch<ConnectionCubit>().state;
    final discoveredServers = context.watch<ServerDiscoveryCubit>().state;

    return BlocListener<ConnectionCubit, BridgeConnectionState>(
      listener: (context, nextState) {
        if (_isAutoConnecting) {
          setState(() => _isAutoConnecting = false);
        }
        // Navigate to session list when connection succeeds.
        // We cannot rely on reevaluateListenable because rejected guard
        // navigations are not re-attempted by auto_route.
        if (nextState == BridgeConnectionState.connected) {
          context.router.root.replaceAll([SessionListRoute()]);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CC Pocket'),
          actions: [
            IconButton(
              key: const ValueKey('settings_button'),
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        ),
        body:
            _isAutoConnecting ||
                connectionState == BridgeConnectionState.connecting
            ? const Center(child: CircularProgressIndicator())
            : _buildConnectForm(discoveredServers),
      ),
    );
  }

  Widget _buildConnectForm(List<DiscoveredServer> discoveredServers) {
    final machineManagerCubit = context.watch<MachineManagerCubit?>();
    final machineState = machineManagerCubit?.state;

    return ConnectForm(
      urlController: _urlController,
      apiKeyController: _apiKeyController,
      discoveredServers: discoveredServers,
      onConnect: _connect,
      onScanQrCode: _scanQrCode,
      onConnectToDiscovered: _connectToDiscovered,
      machines: machineState?.machines ?? [],
      startingMachineId: machineState?.startingMachineId,
      updatingMachineId: machineState?.updatingMachineId,
      onConnectToMachine: _connectToMachine,
      onStartMachine: _startMachine,
      onEditMachine: _editMachine,
      onDeleteMachine: _deleteMachine,
      onToggleFavorite: _toggleFavorite,
      onUpdateMachine: _updateMachine,
      onStopMachine: _stopMachine,
      onAddMachine: _addMachine,
      onRefreshMachines: () => machineManagerCubit?.refreshAll(),
    );
  }
}
