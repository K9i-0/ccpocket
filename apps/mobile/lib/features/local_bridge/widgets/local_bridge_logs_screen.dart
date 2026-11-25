import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/google_search_text_selection.dart';
import '../data/local_bridge_models.dart';

/// Recent Bridge console output.
class LocalBridgeLogsScreen extends StatefulWidget {
  const LocalBridgeLogsScreen({super.key, required this.loadLogs});

  final Future<List<LocalBridgeLogEntry>> Function() loadLogs;

  @override
  State<LocalBridgeLogsScreen> createState() => _LocalBridgeLogsScreenState();
}

class _LocalBridgeLogsScreenState extends State<LocalBridgeLogsScreen> {
  late Future<List<LocalBridgeLogEntry>> _logs = widget.loadLogs();

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _line(LocalBridgeLogEntry entry) {
    final t = entry.time;
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)} ${entry.message}';
  }

  Future<void> _copy(List<LocalBridgeLogEntry> entries) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: entries.map(_line).join('\n')));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<List<LocalBridgeLogEntry>>(
      future: _logs,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <LocalBridgeLogEntry>[];
        return Scaffold(
          appBar: AppBar(
            title: Text(l.localBridgeLogsTitle),
            actions: [
              IconButton(
                key: const ValueKey('local_bridge_logs_copy_button'),
                tooltip: l.copy,
                onPressed: entries.isEmpty ? null : () => _copy(entries),
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                key: const ValueKey('local_bridge_logs_refresh_button'),
                tooltip: l.refresh,
                onPressed: () => setState(() => _logs = widget.loadLogs()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: switch (snapshot) {
            AsyncSnapshot(connectionState: ConnectionState.waiting) =>
              const Center(child: CircularProgressIndicator()),
            AsyncSnapshot(hasError: true) => Center(
              child: Text(l.localBridgeErrorTitle),
            ),
            _ when entries.isEmpty => Center(
              child: Text(l.localBridgeLogsEmpty),
            ),
            _ => GoogleSearchSelectionArea(
              child: SingleChildScrollView(
                key: const ValueKey('local_bridge_logs_list'),
                reverse: true,
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: cs.onSurface,
                      ),
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          TextSpan(
                            text: i == entries.length - 1
                                ? _line(entries[i])
                                : '${_line(entries[i])}\n',
                            style: switch (entries[i].level) {
                              'error' => TextStyle(color: cs.error),
                              'warn' => TextStyle(color: cs.tertiary),
                              _ => null,
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          },
        );
      },
    );
  }
}
