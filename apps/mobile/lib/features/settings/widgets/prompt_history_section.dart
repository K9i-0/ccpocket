import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../../../services/machine_manager_service.dart';
import '../../../services/prompt_history_service.dart';
import '../../../utils/network_endpoint.dart';

class PromptHistorySection extends StatefulWidget {
  final BridgeService bridgeService;
  final PromptHistoryService promptHistoryService;
  final MachineManagerService machineManagerService;

  const PromptHistorySection({
    super.key,
    required this.bridgeService,
    required this.promptHistoryService,
    required this.machineManagerService,
  });

  @override
  State<PromptHistorySection> createState() => _PromptHistorySectionState();
}

class _PromptHistorySectionState extends State<PromptHistorySection> {
  List<PromptHistorySyncStatus> _statuses = const [];
  Map<String, String> _bridgeAliases = const {};
  bool _syncing = false;
  bool _hasLegacyHistory = false;
  bool _legacyMigrationDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.promptHistoryService.getSyncStatuses(),
      widget.promptHistoryService.getBridgeAliasMap(),
      widget.promptHistoryService.hasLegacyHistory(),
      widget.promptHistoryService.isLegacyMigrationDismissed(),
    ]);
    if (!mounted) return;
    setState(() {
      _statuses = results[0] as List<PromptHistorySyncStatus>;
      _bridgeAliases = results[1] as Map<String, String>;
      _hasLegacyHistory = results[2] as bool;
      _legacyMigrationDismissed = results[3] as bool;
    });
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    await widget.promptHistoryService.syncAll(
      machineManager: widget.machineManagerService,
      bridgeService: widget.bridgeService,
    );
    await _load();
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _importLegacy() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l.promptHistoryReplaceTitle),
          content: Text(l.promptHistoryReplaceSubtitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('prompt_history_replace_confirm_button'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.promptHistoryReplaceConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final migrated = await widget.promptHistoryService
        .importLegacyToCurrentBridge(bridgeService: widget.bridgeService);
    if (!migrated) return;
    await widget.promptHistoryService.setLegacyMigrationDismissed(true);
    await _sync();
  }

  Future<void> _dismissLegacyMigration() async {
    await widget.promptHistoryService.setLegacyMigrationDismissed(true);
    if (!mounted) return;
    setState(() => _legacyMigrationDismissed = true);
  }

  bool get _canMigrateLegacy =>
      _hasLegacyHistory &&
      !_legacyMigrationDismissed &&
      widget.bridgeService.isConnected &&
      widget.bridgeService.promptHistoryBridgeId != null;

  List<PromptHistorySyncStatus> get _groupedStatuses {
    final grouped = <String, PromptHistorySyncStatus>{};
    for (final status in _statuses) {
      final canonicalId = _bridgeAliases[status.bridgeId] ?? status.bridgeId;
      final normalized = _normalizeStatus(status, canonicalId);
      final current = grouped[canonicalId];
      grouped[canonicalId] = current == null
          ? normalized
          : _preferredStatus(current, normalized);
    }
    return grouped.values.toList()..sort((a, b) {
      final aTime = a.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
  }

  PromptHistorySyncStatus _normalizeStatus(
    PromptHistorySyncStatus status,
    String bridgeId,
  ) {
    if (status.bridgeId == bridgeId) return status;
    return PromptHistorySyncStatus(
      bridgeId: bridgeId,
      bridgeUrl: status.bridgeUrl,
      bridgeName: status.bridgeName,
      lastSyncAt: status.lastSyncAt,
      revision: status.revision,
      entryCount: status.entryCount,
      error: status.error,
    );
  }

  PromptHistorySyncStatus _preferredStatus(
    PromptHistorySyncStatus current,
    PromptHistorySyncStatus next,
  ) {
    if (current.error == null && next.error != null) return current;
    if (current.error != null && next.error == null) return next;
    final currentTime =
        current.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final nextTime = next.lastSyncAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return nextTime.isAfter(currentTime) ? next : current;
  }

  List<_BridgeRegistration> _registrationsFor(PromptHistorySyncStatus status) {
    final registrations = <_BridgeRegistration>[];
    final seen = <String>{};

    void add(_BridgeRegistration registration) {
      if (seen.add(registration.endpoint)) registrations.add(registration);
    }

    for (final machine in widget.machineManagerService.currentMachines) {
      final alias = widget.promptHistoryService.bridgeIdForUrl(machine.wsUrl);
      final canonical = _bridgeAliases[alias] ?? alias;
      if (canonical == status.bridgeId) {
        add(
          _BridgeRegistration(label: machine.name, endpoint: machine.uniqueKey),
        );
      }
    }

    final statusEndpoint = _endpointFromUrl(status.bridgeUrl);
    if (statusEndpoint != null) {
      add(
        _BridgeRegistration(
          label: _isBridgeIdLike(status.bridgeName, status.bridgeId)
              ? null
              : status.bridgeName,
          endpoint: statusEndpoint,
        ),
      );
    } else if (!_isBridgeIdLike(status.bridgeName, status.bridgeId)) {
      add(_BridgeRegistration(label: null, endpoint: status.bridgeName));
    }

    return registrations;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final groupedStatuses = _groupedStatuses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            l.promptHistorySectionTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (_canMigrateLegacy) ...[
                _LegacyMigrationTile(
                  onMigrate: _importLegacy,
                  onDismiss: _dismissLegacyMigration,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant,
                ),
              ],
              _SyncOverviewTile(
                statuses: groupedStatuses,
                syncing: _syncing,
                onSync: _syncing ? null : _sync,
              ),
              if (groupedStatuses.isNotEmpty) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant,
                ),
                for (final status in groupedStatuses)
                  _StatusTile(
                    status: status,
                    registrations: _registrationsFor(status),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BridgeRegistration {
  final String? label;
  final String endpoint;

  const _BridgeRegistration({required this.label, required this.endpoint});

  String get displayName {
    final name = label?.trim();
    if (name == null || name.isEmpty || name == endpoint) return endpoint;
    return '$name / $endpoint';
  }
}

class _LegacyMigrationTile extends StatelessWidget {
  final VoidCallback onMigrate;
  final VoidCallback onDismiss;

  const _LegacyMigrationTile({
    required this.onMigrate,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Padding(
      key: const ValueKey('prompt_history_migration_tile'),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.upload_file, color: cs.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.promptHistoryReplaceTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l.promptHistoryReplaceSubtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('prompt_history_migration_button'),
                      onPressed: onMigrate,
                      icon: const Icon(Icons.upload_file),
                      label: Text(l.promptHistoryReplaceConfirmAction),
                    ),
                    TextButton(
                      key: const ValueKey(
                        'prompt_history_migration_dismiss_button',
                      ),
                      onPressed: onDismiss,
                      child: Text(l.promptHistoryReplaceDismissAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncOverviewTile extends StatelessWidget {
  final List<PromptHistorySyncStatus> statuses;
  final bool syncing;
  final VoidCallback? onSync;

  const _SyncOverviewTile({
    required this.statuses,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(Icons.cloud_sync_outlined, color: cs.primary),
      title: Text(_statusSummary(l)),
      subtitle: Text(_latestSyncLabel(l)),
      trailing: IconButton(
        key: const ValueKey('prompt_history_sync_button'),
        tooltip: l.promptHistorySyncTitle,
        onPressed: onSync,
        icon: syncing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
      ),
    );
  }

  String _statusSummary(AppLocalizations l) {
    if (statuses.isEmpty) return l.promptHistoryNotSyncedYet;
    final ok = statuses.where((status) => status.error == null).length;
    final failed = statuses.length - ok;
    return failed == 0
        ? l.promptHistorySyncedBridges(ok)
        : l.promptHistorySyncSummaryWithFailures(ok, failed);
  }

  String _latestSyncLabel(AppLocalizations l) {
    final synced = statuses
        .where((status) => status.error == null && status.lastSyncAt != null)
        .map((status) => status.lastSyncAt!)
        .toList();
    if (synced.isEmpty) return l.promptHistoryNoSyncTime;
    synced.sort((a, b) => b.compareTo(a));
    return l.promptHistoryLatestSync(_formatSyncedAt(synced.first));
  }

  String _formatSyncedAt(DateTime value) {
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $h:$m';
  }
}

class _StatusTile extends StatelessWidget {
  final PromptHistorySyncStatus status;
  final List<_BridgeRegistration> registrations;

  const _StatusTile({required this.status, required this.registrations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasError = status.error != null;
    final l = AppLocalizations.of(context);
    final title = registrations.isEmpty
        ? (status.bridgeName.isEmpty
              ? _shortBridgeId(status.bridgeId)
              : status.bridgeName)
        : registrations.first.displayName;
    return ListTile(
      dense: true,
      leading: Icon(
        hasError ? Icons.error_outline : Icons.cloud_done,
        color: hasError ? cs.error : cs.primary,
      ),
      title: Text(title),
      subtitle: Text(_subtitle(l, hasError)),
      trailing: Text('${status.entryCount}'),
    );
  }

  String _subtitle(AppLocalizations l, bool hasError) {
    final lines = <String>[
      hasError ? status.error! : _formatSyncedAt(status.lastSyncAt, l),
      l.promptHistoryBridgeId(_shortBridgeId(status.bridgeId)),
    ];
    final others = registrations.skip(1).map((item) => item.displayName);
    if (others.isNotEmpty) {
      lines.add(l.promptHistoryOtherBridgeRegistrations(others.join(', ')));
    }
    return lines.join('\n');
  }

  String _formatSyncedAt(DateTime? value, AppLocalizations l) {
    if (value == null) return l.promptHistoryNoSyncTime;
    final local = value.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.year}/${local.month}/${local.day} $h:$m';
  }
}

String? _endpointFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url.isEmpty ? null : url;
  return uri.hasPort
      ? formatHostPort(uri.host, uri.port)
      : bracketIpv6Host(uri.host);
}

bool _isBridgeIdLike(String value, String bridgeId) {
  if (value.isEmpty || value == bridgeId) return true;
  return value.length >= 24 && !value.contains(':') && !value.contains('/');
}

String _shortBridgeId(String value) {
  if (value.length <= 16) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}
