import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../services/database_service.dart';

/// Settings セクション: プロンプト履歴のバックアップ＆リストア
class BackupSection extends StatefulWidget {
  final BridgeService bridgeService;
  final DatabaseService databaseService;
  const BackupSection({
    super.key,
    required this.bridgeService,
    required this.databaseService,
  });

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  PromptHistoryBackupInfoMessage? _info;
  bool _backingUp = false;
  bool _restoring = false;
  StreamSubscription<PromptHistoryBackupInfoMessage>? _infoSub;
  StreamSubscription<PromptHistoryBackupResultMessage>? _backupSub;
  StreamSubscription<PromptHistoryRestoreResultMessage>? _restoreSub;
  StreamSubscription<BridgeConnectionState>? _connSub;

  @override
  void initState() {
    super.initState();
    _infoSub = widget.bridgeService.backupInfo.listen((msg) {
      if (mounted) setState(() => _info = msg);
    });
    _backupSub = widget.bridgeService.backupResults.listen(_onBackupResult);
    _restoreSub = widget.bridgeService.restoreResults.listen(_onRestoreResult);
    _connSub = widget.bridgeService.connectionStatus.listen((state) {
      if (!mounted) return;
      if (state == BridgeConnectionState.connected) {
        _fetchInfo();
      }
      setState(() {}); // Rebuild on both connect & disconnect
    });
    _fetchInfo();
  }

  @override
  void dispose() {
    _infoSub?.cancel();
    _backupSub?.cancel();
    _restoreSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  void _fetchInfo() {
    if (!widget.bridgeService.isConnected) return;
    widget.bridgeService.send(ClientMessage.getPromptHistoryBackupInfo());
  }

  Future<void> _doBackup() async {
    if (_backingUp) return;
    setState(() => _backingUp = true);

    try {
      final data = await widget.databaseService.exportDb();
      if (data == null || !mounted) {
        if (mounted) setState(() => _backingUp = false);
        return;
      }

      final info = await PackageInfo.fromPlatform();
      final base64Data = base64Encode(data);
      widget.bridgeService.send(
        ClientMessage.backupPromptHistory(
          data: base64Data,
          appVersion: info.version,
          dbVersion: widget.databaseService.dbVersion,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  void _onBackupResult(PromptHistoryBackupResultMessage msg) {
    if (!mounted) return;
    setState(() => _backingUp = false);
    final l = AppLocalizations.of(context);
    if (msg.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.backupSuccess)));
      _fetchInfo();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.backupFailed(msg.error ?? 'Unknown error'))),
      );
    }
  }

  void _requestRestore() {
    if (_restoring) return;
    final l = AppLocalizations.of(context);
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.restoreConfirmTitle),
        content: Text(l.restoreConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.restoreConfirmButton),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _doRestore();
    });
  }

  void _doRestore() {
    setState(() => _restoring = true);
    widget.bridgeService.send(ClientMessage.restorePromptHistory());
  }

  Future<void> _onRestoreResult(PromptHistoryRestoreResultMessage msg) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);

    try {
      if (msg.success && msg.data != null) {
        final bytes = base64Decode(msg.data!);
        final ok = await widget.databaseService.importDb(bytes);
        if (mounted) {
          setState(() => _restoring = false);
          if (ok) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l.restoreSuccess)));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.restoreFailed('Import failed'))),
            );
          }
        }
      } else {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.restoreFailed(msg.error ?? 'Unknown error')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _restoring = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.restoreFailed('$e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final isConnected = widget.bridgeService.isConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            l.sectionBackup,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        if (!isConnected)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.connectToBackup,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Backup info tile
                _BackupInfoTile(info: _info),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant,
                ),
                // Backup button
                ListTile(
                  leading: Icon(Icons.cloud_upload, color: cs.primary),
                  title: Text(l.backupPromptHistory),
                  trailing: _backingUp
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, size: 20),
                  onTap: _backingUp ? null : _doBackup,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant,
                ),
                // Restore button
                ListTile(
                  leading: Icon(Icons.cloud_download, color: cs.primary),
                  title: Text(l.restorePromptHistory),
                  trailing: _restoring
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right, size: 20),
                  onTap: (_restoring || _info == null || !_info!.exists)
                      ? null
                      : _requestRestore,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BackupInfoTile extends StatelessWidget {
  final PromptHistoryBackupInfoMessage? info;
  const _BackupInfoTile({required this.info});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    if (info == null || !info!.exists) {
      return ListTile(
        leading: Icon(Icons.info_outline, color: cs.onSurfaceVariant),
        title: Text(
          l.noBackupFound,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }

    final backedUpAt = info!.backedUpAt != null
        ? _formatDate(DateTime.tryParse(info!.backedUpAt!))
        : '?';
    final version = info!.appVersion ?? '?';
    final size = info!.sizeBytes != null ? _formatSize(info!.sizeBytes!) : '?';

    return ListTile(
      leading: Icon(Icons.cloud_done, color: cs.primary),
      title: Text(l.backupInfo(backedUpAt)),
      subtitle: Text(l.backupVersionInfo(version, size)),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '?';
    final local = dt.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
