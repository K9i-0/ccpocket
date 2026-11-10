import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../features/explore/state/explore_state.dart';
import '../features/explore/widgets/explore_entry_tile.dart';
import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../services/bridge_service_base.dart';

String _normalizePathForComparison(String path) {
  final separator = String.fromCharCode(92);
  final raw = path.trim();
  final isWindowsPath =
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(raw) ||
      raw.startsWith('\\\\') ||
      raw.startsWith('//');
  var value = isWindowsPath ? raw.replaceAll(separator, '/') : raw;
  if (value.toLowerCase().startsWith('//?/unc/')) {
    value = '//${value.substring(8)}';
  } else if (value.toLowerCase().startsWith('//?/')) {
    value = value.substring(4);
  }
  final drive = RegExp(r'^[A-Za-z]:').firstMatch(value)?.group(0);
  if (drive != null) value = value.substring(2);
  final absolute = value.startsWith('/');
  final parts = <String>[];
  for (final part in value.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (parts.isNotEmpty && parts.last != '..') {
        parts.removeLast();
      } else if (!absolute) {
        parts.add(part);
      }
      continue;
    }
    parts.add(part);
  }
  final body = parts.join('/');
  final normalized = drive != null
      ? (body.isEmpty ? '$drive/' : '$drive/$body')
      : absolute
      ? (body.isEmpty ? '/' : '/$body')
      : body;
  return isWindowsPath ? normalized.toLowerCase() : normalized;
}

bool _isPathWithinRoot(String path, String root) {
  final normalizedPath = _normalizePathForComparison(path);
  final normalizedRoot = _normalizePathForComparison(root);
  if (normalizedRoot == '/') return normalizedPath.startsWith('/');
  return normalizedPath == normalizedRoot ||
      normalizedPath.startsWith(
        normalizedRoot.endsWith('/') ? normalizedRoot : '$normalizedRoot/',
      );
}

String _leafName(String path) {
  var normalized = path;
  final separator = String.fromCharCode(92);
  while (normalized.length > 1 &&
      (normalized.endsWith('/') || normalized.endsWith(separator))) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final slash = math.max(
    normalized.lastIndexOf('/'),
    normalized.lastIndexOf(separator),
  );
  return slash >= 0 && slash + 1 < normalized.length
      ? normalized.substring(slash + 1)
      : normalized;
}

String? _parentPath(String path) {
  var normalized = path;
  final separator = String.fromCharCode(92);
  while (normalized.length > 1 &&
      (normalized.endsWith('/') || normalized.endsWith(separator))) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final slash = math.max(
    normalized.lastIndexOf('/'),
    normalized.lastIndexOf(separator),
  );
  if (slash < 0) return null;
  if (slash == 0) return normalized.substring(0, 1);
  if (slash == 2 && normalized.length > 2 && normalized[1] == ':') {
    return normalized.substring(0, 3);
  }
  return normalized.substring(0, slash);
}

bool _isAllowedPath(String path, List<String> allowedRoots) {
  if (allowedRoots.isEmpty) return true;
  return allowedRoots.any((root) => _isPathWithinRoot(path, root));
}

/// One step of the trail shown above a folder list.
typedef FolderBreadcrumb = ({String label, String path});

/// The trail from the allowed root that contains [path] down to [path].
///
/// Without allowed roots the trail starts at the filesystem root. The trail
/// never leaves the allowed roots, so every step can be opened.
List<FolderBreadcrumb> folderBreadcrumbs(
  String path,
  List<String> allowedRoots,
) {
  final roots = allowedRoots.map(_normalizePathForComparison).toSet();
  final trail = <FolderBreadcrumb>[];
  String? cursor = path;
  for (var depth = 0; cursor != null && depth < 64; depth++) {
    trail.add((label: _leafName(cursor), path: cursor));
    if (roots.contains(_normalizePathForComparison(cursor))) break;
    final parent = _parentPath(cursor);
    if (parent == null ||
        parent == cursor ||
        !_isAllowedPath(parent, allowedRoots)) {
      break;
    }
    cursor = parent;
  }
  return trail.reversed.toList();
}

/// Where a folder lives, for lists whose rows already show the folder name:
/// its parent as a trail from the allowed root, or the parent's full path when
/// that is outside the allowed roots. Null when the folder has no parent.
String? folderLocationLabel(String path, List<String> allowedRoots) {
  final parent = _parentPath(path);
  if (parent == null || parent == path) return null;
  final trail = folderBreadcrumbs(parent, allowedRoots);
  final start = _normalizePathForComparison(trail.first.path);
  final startsAtRoot = allowedRoots.any(
    (root) => _normalizePathForComparison(root) == start,
  );
  // Outside the allowed roots there is no short name to start from.
  if (!startsAtRoot) return parent;
  return trail.map((crumb) => crumb.label).join(' / ');
}

Future<String?> showDirectoryBrowserSheet({
  required BuildContext context,
  required BridgeServiceBase bridge,
  String? initialPath,
  List<String> allowedRoots = const [],
  bool includeHidden = false,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final fallbackPath = initialPath?.trim().isNotEmpty == true
      ? initialPath!.trim()
      : (allowedRoots.isNotEmpty ? allowedRoots.first : '/');
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _DirectoryBrowserSheet(
      bridge: bridge,
      initialPath: fallbackPath,
      allowedRoots: allowedRoots,
      includeHidden: includeHidden,
    ),
  );
}

class _DirectoryBrowserSheet extends StatefulWidget {
  final BridgeServiceBase bridge;
  final String initialPath;
  final List<String> allowedRoots;
  final bool includeHidden;

  const _DirectoryBrowserSheet({
    required this.bridge,
    required this.initialPath,
    required this.allowedRoots,
    required this.includeHidden,
  });

  @override
  State<_DirectoryBrowserSheet> createState() => _DirectoryBrowserSheetState();
}

class _DirectoryBrowserSheetState extends State<_DirectoryBrowserSheet> {
  final _filterController = TextEditingController();
  late String _currentPath;
  String? _requestedPath;
  String? _requestedRequestId;
  List<DirectoryListingEntry> _directories = const [];
  String? _error;
  bool _loading = false;
  int _requestSequence = 0;
  StreamSubscription<ServerMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _messageSubscription = widget.bridge.messages.listen(_onMessage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestDirectory(_currentPath);
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _onMessage(ServerMessage message) {
    if (!mounted || !_loading) return;
    if (message is DirectoryListingMessage) {
      if (!_matchesRequest(message.requestId, message.path)) return;
      final l = AppLocalizations.of(context);
      if (!_isAllowed(message.path)) {
        setState(() {
          _requestedPath = null;
          _requestedRequestId = null;
          _directories = const [];
          _error = l.directoryPathOutsideAllowedRoots;
          _loading = false;
        });
        return;
      }
      // The filter narrows one folder's children; it means nothing elsewhere.
      if (_normalizePathForComparison(message.path) !=
          _normalizePathForComparison(_currentPath)) {
        _filterController.clear();
      }
      setState(() {
        _currentPath = message.path;
        _requestedPath = null;
        _requestedRequestId = null;
        _directories = message.directories
            .where((entry) => _isAllowed(entry.path))
            .toList();
        _error = null;
        _loading = false;
      });
      return;
    }
    if (message is ErrorMessage) {
      final legacyUnsupported = _isLegacyUnsupportedRequest(message);
      if (!legacyUnsupported &&
          (!_matchesRequest(message.requestId, message.path) ||
              !_isDirectoryError(message.errorCode))) {
        return;
      }
      final l = AppLocalizations.of(context);
      setState(() {
        _error = legacyUnsupported
            ? l.directoryBrowserBridgeUpdateRequired
            : _errorText(l, message);
        _requestedRequestId = null;
        _loading = false;
      });
    }
  }

  /// Bridge error messages are English and say "directory"; the known codes
  /// are shown in the app's own words instead.
  String _errorText(AppLocalizations l, ErrorMessage message) =>
      switch (message.errorCode) {
        'directory_not_allowed' => l.browserNotAllowed,
        'directory_not_found' => l.browserNotFound,
        'directory_not_readable' || 'not_a_directory' => l.browserUnreadable,
        _ => message.message,
      };

  bool _matchesRequest(String? requestId, String? path) {
    final expectedRequestId = _requestedRequestId;
    if (expectedRequestId != null) {
      return requestId == expectedRequestId;
    }
    if (path != null && _requestedPath != null) {
      return _normalizePathForComparison(path) ==
          _normalizePathForComparison(_requestedPath!);
    }
    return false;
  }

  bool _isLegacyUnsupportedRequest(ErrorMessage message) =>
      message.errorCode == 'unsupported_message' &&
      message.message == 'list_directory' &&
      message.requestId == null &&
      message.path == null;

  bool _isDirectoryError(String? code) {
    return code == 'directory_not_allowed' ||
        code == 'directory_not_found' ||
        code == 'directory_not_readable' ||
        code == 'not_a_directory' ||
        code == 'directory_read_failed';
  }

  void _requestDirectory(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    final l = AppLocalizations.of(context);
    if (!_isAllowed(normalized)) {
      setState(() {
        _requestedPath = null;
        _requestedRequestId = null;
        _directories = const [];
        _error = l.directoryPathOutsideAllowedRoots;
        _loading = false;
      });
      return;
    }
    final requestId =
        'directory-browser-${identityHashCode(this)}-${++_requestSequence}';
    setState(() {
      _requestedPath = normalized;
      _requestedRequestId = requestId;
      _error = null;
      _loading = true;
    });
    widget.bridge.requestDirectoryListing(
      normalized,
      requestId: requestId,
      includeHidden: widget.includeHidden,
    );
  }

  bool _isAllowed(String path) => _isAllowedPath(path, widget.allowedRoots);

  void _goUp() {
    final parent = _parentPath(_currentPath);
    if (parent != null) _requestDirectory(parent);
  }

  void _openChild(String path) {
    // Put the keyboard away so the opened folder's list is not covered.
    FocusManager.instance.primaryFocus?.unfocus();
    _requestDirectory(path);
  }

  List<DirectoryListingEntry> get _visibleDirectories {
    final query = _filterController.text.trim().toLowerCase();
    if (query.isEmpty) return _directories;
    return _directories
        .where((entry) => entry.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final parent = _parentPath(_currentPath);
    final height = math.min(MediaQuery.sizeOf(context).height * 0.78, 680.0);

    return Padding(
      // Keeps the list and the actions above the keyboard while filtering.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DirectoryBrowserHeader(
                localizations: l,
                canGoUp: parent != null && _isAllowed(parent) && !_loading,
                loading: _loading,
                onGoUp: _goUp,
                onRefresh: () => _requestDirectory(_currentPath),
                onCancel: () => Navigator.pop(context),
              ),
              if (widget.allowedRoots.length > 1)
                _DirectoryBrowserRoots(
                  localizations: l,
                  colorScheme: cs,
                  roots: widget.allowedRoots,
                  loading: _loading,
                  onSelected: _requestDirectory,
                ),
              _DirectoryBrowserBreadcrumbs(
                crumbs: folderBreadcrumbs(_currentPath, widget.allowedRoots),
                colorScheme: cs,
                enabled: !_loading,
                onSelected: _requestDirectory,
              ),
              if (_error == null && _directories.isNotEmpty)
                _DirectoryBrowserFilterField(
                  localizations: l,
                  controller: _filterController,
                  onChanged: () => setState(() {}),
                ),
              Expanded(
                child: _DirectoryBrowserBody(
                  localizations: l,
                  colorScheme: cs,
                  loading: _loading,
                  error: _error,
                  hasDirectories: _directories.isNotEmpty,
                  directories: _visibleDirectories,
                  onRetry: () =>
                      _requestDirectory(_requestedPath ?? _currentPath),
                  onDirectorySelected: _openChild,
                ),
              ),
              const SizedBox(height: 8),
              _DirectoryBrowserActions(
                localizations: l,
                canSelect: !_loading && _error == null,
                onCancel: () => Navigator.pop(context),
                onSelect: () => Navigator.pop(context, _currentPath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryBrowserHeader extends StatelessWidget {
  const _DirectoryBrowserHeader({
    required this.localizations,
    required this.canGoUp,
    required this.loading,
    required this.onGoUp,
    required this.onRefresh,
    required this.onCancel,
  });

  final AppLocalizations localizations;
  final bool canGoUp;
  final bool loading;
  final VoidCallback onGoUp;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('directory_browser_up_button'),
          tooltip: localizations.browserParent,
          onPressed: canGoUp ? onGoUp : null,
          icon: const Icon(Icons.arrow_upward),
        ),
        Expanded(
          child: Text(
            localizations.browseDirectory,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('directory_browser_refresh_button'),
          tooltip: localizations.retry,
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const ValueKey('directory_browser_cancel_button'),
          tooltip: localizations.cancel,
          onPressed: onCancel,
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );
}

/// Shortcuts between the allowed roots. A single root is already the first
/// breadcrumb, so this only appears when there is a choice.
class _DirectoryBrowserRoots extends StatelessWidget {
  const _DirectoryBrowserRoots({
    required this.localizations,
    required this.colorScheme,
    required this.roots,
    required this.loading,
    required this.onSelected,
  });

  final AppLocalizations localizations;
  final ColorScheme colorScheme;
  final List<String> roots;
  final bool loading;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.directoryBrowserRoots,
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: roots.length,
            itemBuilder: (context, index) {
              final root = roots[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  key: ValueKey('directory_browser_root_$root'),
                  label: Text(_leafName(root)),
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: loading ? null : () => onSelected(root),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// The current location as one line of tappable steps. It replaces both the
/// full-path banner and the per-row paths, which repeated the same prefix.
class _DirectoryBrowserBreadcrumbs extends StatelessWidget {
  const _DirectoryBrowserBreadcrumbs({
    required this.crumbs,
    required this.colorScheme,
    required this.enabled,
    required this.onSelected,
  });

  final List<FolderBreadcrumb> crumbs;
  final ColorScheme colorScheme;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('directory_browser_breadcrumbs'),
      height: 36,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // Reversed so a deep path stays scrolled to the current folder.
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth - 16),
            child: Row(
              children: [
                for (final (index, crumb) in crumbs.indexed) ...[
                  if (index > 0)
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  if (index == crumbs.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        crumb.label,
                        key: const ValueKey('directory_browser_current_name'),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    InkWell(
                      key: ValueKey('directory_browser_crumb_${crumb.path}'),
                      borderRadius: BorderRadius.circular(6),
                      onTap: enabled ? () => onSelected(crumb.path) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Text(
                          crumb.label,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryBrowserFilterField extends StatelessWidget {
  const _DirectoryBrowserFilterField({
    required this.localizations,
    required this.controller,
    required this.onChanged,
  });

  final AppLocalizations localizations;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: TextField(
      key: const ValueKey('directory_browser_filter_field'),
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: localizations.directoryBrowserFilterHint,
        prefixIcon: const Icon(Icons.search),
        isDense: true,
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey('directory_browser_filter_clear_button'),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
      ),
    ),
  );
}

class _DirectoryBrowserBody extends StatelessWidget {
  const _DirectoryBrowserBody({
    required this.localizations,
    required this.colorScheme,
    required this.loading,
    required this.error,
    required this.hasDirectories,
    required this.directories,
    required this.onRetry,
    required this.onDirectorySelected,
  });

  final AppLocalizations localizations;
  final ColorScheme colorScheme;
  final bool loading;
  final String? error;

  /// Whether the folder has children at all, before the filter is applied.
  final bool hasDirectories;
  final List<DirectoryListingEntry> directories;
  final VoidCallback onRetry;
  final ValueChanged<String> onDirectorySelected;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return _DirectoryBrowserError(
        localizations: localizations,
        colorScheme: colorScheme,
        message: error!,
        onRetry: onRetry,
      );
    }
    if (directories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            hasDirectories
                ? localizations.directoryBrowserNoMatches
                : localizations.noSubdirectories,
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return _DirectoryBrowserList(
      directories: directories,
      onSelected: onDirectorySelected,
    );
  }
}

class _DirectoryBrowserError extends StatelessWidget {
  const _DirectoryBrowserError({
    required this.localizations,
    required this.colorScheme,
    required this.message,
    required this.onRetry,
  });

  final AppLocalizations localizations;
  final ColorScheme colorScheme;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 32),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('directory_browser_retry_button'),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retry),
          ),
        ],
      ),
    ),
  );
}

/// Rows are the Explorer's own tiles: name only, since the breadcrumbs above
/// already say where these folders are.
class _DirectoryBrowserList extends StatelessWidget {
  const _DirectoryBrowserList({
    required this.directories,
    required this.onSelected,
  });

  final List<DirectoryListingEntry> directories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey('directory_browser_list'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    itemCount: directories.length,
    itemBuilder: (context, index) {
      final directory = directories[index];
      return KeyedSubtree(
        key: ValueKey('directory_browser_entry_${directory.path}'),
        child: ExploreEntryTile(
          entry: ExploreEntry(
            name: directory.name,
            relativePath: directory.path,
            isDirectory: true,
          ),
          onTap: () => onSelected(directory.path),
        ),
      );
    },
  );
}

class _DirectoryBrowserActions extends StatelessWidget {
  const _DirectoryBrowserActions({
    required this.localizations,
    required this.canSelect,
    required this.onCancel,
    required this.onSelect,
  });

  final AppLocalizations localizations;
  final bool canSelect;
  final VoidCallback onCancel;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('directory_browser_cancel_action'),
            onPressed: onCancel,
            child: Text(localizations.cancel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('directory_browser_select_action'),
            onPressed: canSelect ? onSelect : null,
            icon: const Icon(Icons.folder_open),
            label: Text(localizations.selectDirectory),
          ),
        ),
      ],
    ),
  );
}
