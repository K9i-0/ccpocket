import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/logger.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/workspace_pane_chrome.dart';

/// Filter options displayed in [LogViewerScreen].
enum LogLevelFilter {
  all,
  debug,
  info,
  warning,
  error;

  String get label => switch (this) {
    LogLevelFilter.all => 'All',
    LogLevelFilter.debug => 'Debug',
    LogLevelFilter.info => 'Info',
    LogLevelFilter.warning => 'Warning',
    LogLevelFilter.error => 'Error',
  };

  bool matches(AppLogLevel level) => switch (this) {
    LogLevelFilter.all => true,
    LogLevelFilter.debug => level == AppLogLevel.debug,
    LogLevelFilter.info => level == AppLogLevel.info,
    LogLevelFilter.warning => level == AppLogLevel.warning,
    LogLevelFilter.error =>
      level == AppLogLevel.error || level == AppLogLevel.critical,
  };
}

/// Native `material_ui` log viewer backed by [AppLogger].
class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key, required this.logger, this.onShare});

  final AppLogger logger;

  /// Optional override for sharing exported log text (primarily for tests).
  final Future<void> Function(String text)? onShare;

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedIds = <int>{};

  LogLevelFilter _selectedFilter = LogLevelFilter.all;
  String _searchQuery = '';
  bool _pendingRefresh = false;

  @override
  void initState() {
    super.initState();
    widget.logger.listenable.addListener(_onLoggerChanged);
  }

  @override
  void didUpdateWidget(covariant LogViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logger != widget.logger) {
      oldWidget.logger.listenable.removeListener(_onLoggerChanged);
      _expandedIds.clear();
      widget.logger.listenable.addListener(_onLoggerChanged);
    }
  }

  @override
  void dispose() {
    widget.logger.listenable.removeListener(_onLoggerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onLoggerChanged() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_pendingRefresh) return;
      _pendingRefresh = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pendingRefresh = false;
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  List<AppLogEntry> _filteredChronological(List<AppLogEntry> allEntries) {
    return allEntries
        .where(
          (entry) =>
              _selectedFilter.matches(entry.level) &&
              entry.matchesQuery(_searchQuery),
        )
        .toList(growable: false);
  }

  Future<void> _copyLogs(List<AppLogEntry> entries) async {
    if (entries.isEmpty) return;
    final text = widget.logger.exportText(entries: entries);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showSnackBar('Copied ${entries.length} log entries');
  }

  Future<void> _copySingleEntry(AppLogEntry entry) async {
    await Clipboard.setData(ClipboardData(text: entry.format()));
    if (!mounted) return;
    _showSnackBar('Copied log entry');
  }

  Future<void> _shareLogs(List<AppLogEntry> entries) async {
    if (entries.isEmpty) return;
    final text = widget.logger.exportText(entries: entries);
    try {
      final customShare = widget.onShare;
      if (customShare != null) {
        await customShare(text);
      } else {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: 'CC Pocket Logs'),
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Failed to share logs: $error');
    }
  }

  void _clearLogs() {
    _expandedIds.clear();
    widget.logger.clear();
  }

  void _toggleExpanded(int id) {
    setState(() {
      if (!_expandedIds.remove(id)) {
        _expandedIds.add(id);
      }
    });
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final cs = Theme.of(context).colorScheme;
    final chrome = resolveStandalonePaneChrome(context);
    final allEntries = widget.logger.entries;
    final filteredChronological = _filteredChronological(allEntries);
    final displayEntries = filteredChronological.reversed.toList(
      growable: false,
    );

    return Scaffold(
      appBar: chrome.wrapAppBar(
        AppBar(
          title: Text(l?.logs ?? 'Logs'),
          actions: chrome.padActions([
            IconButton(
              key: const ValueKey('log_viewer_copy_all_button'),
              icon: const Icon(Icons.copy_all_outlined),
              tooltip: 'Copy all logs',
              onPressed: filteredChronological.isEmpty
                  ? null
                  : () => unawaited(_copyLogs(filteredChronological)),
            ),
            IconButton(
              key: const ValueKey('log_viewer_share_button'),
              icon: const Icon(Icons.share_outlined),
              tooltip: l?.share ?? 'Share',
              onPressed: filteredChronological.isEmpty
                  ? null
                  : () => unawaited(_shareLogs(filteredChronological)),
            ),
            IconButton(
              key: const ValueKey('log_viewer_clear_button'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear logs',
              onPressed: allEntries.isEmpty ? null : _clearLogs,
            ),
          ]),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              key: const ValueKey('log_viewer_search_field'),
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l?.searchHint ?? 'Search logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('log_viewer_search_clear'),
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: LogLevelFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final filter = LogLevelFilter.values[index];
                final isSelected = filter == _selectedFilter;
                return ChoiceChip(
                  key: ValueKey('log_viewer_filter_${filter.name}'),
                  label: Text(filter.label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
            child: Row(
              children: [
                Text(
                  '${displayEntries.length} / ${allEntries.length}',
                  key: const ValueKey('log_viewer_count'),
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: displayEntries.isEmpty
                ? _EmptyLogState(hasAnyLogs: allEntries.isNotEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: displayEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = displayEntries[index];
                      final isExpanded = _expandedIds.contains(entry.id);
                      return _LogEntryCard(
                        entry: entry,
                        isExpanded: isExpanded,
                        onToggle: () => _toggleExpanded(entry.id),
                        onCopy: () => unawaited(_copySingleEntry(entry)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogState extends StatelessWidget {
  const _EmptyLogState({required this.hasAnyLogs});

  final bool hasAnyLogs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyLogs ? Icons.filter_list_off : Icons.article_outlined,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              hasAnyLogs ? 'No matching logs' : 'No logs yet',
              key: const ValueKey('log_viewer_empty_state'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogEntryCard extends StatelessWidget {
  const _LogEntryCard({
    required this.entry,
    required this.isExpanded,
    required this.onToggle,
    required this.onCopy,
  });

  final AppLogEntry entry;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = _levelColor(entry.level, cs, theme.brightness);

    return Card(
      key: ValueKey('log_entry_${entry.id}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpanded ? accent.withValues(alpha: 0.6) : cs.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      entry.level.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.formattedTimestamp,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.message,
                maxLines: isExpanded ? null : 3,
                overflow: isExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              if (!isExpanded && entry.error != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Error: ${entry.error}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              ],
              if (isExpanded) ...[
                if (entry.error != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    'Error: ${entry.error}',
                    key: ValueKey('log_entry_error_${entry.id}'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
                if (entry.stackTrace != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: SelectableText(
                      entry.stackTrace.toString(),
                      key: ValueKey('log_entry_stack_${entry.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: ValueKey('log_entry_copy_${entry.id}'),
                    onPressed: onCopy,
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _levelColor(AppLogLevel level, ColorScheme cs, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return switch (level) {
      AppLogLevel.debug => cs.onSurfaceVariant,
      AppLogLevel.info => cs.secondary,
      AppLogLevel.warning =>
        isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
      AppLogLevel.error => cs.error,
      AppLogLevel.critical =>
        isDark ? const Color(0xFFFF6B6B) : const Color(0xFF991B1B),
    };
  }
}
