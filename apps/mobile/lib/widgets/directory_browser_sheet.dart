import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

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

Future<String?> showDirectoryBrowserSheet({
  required BuildContext context,
  required BridgeServiceBase bridge,
  String? initialPath,
  List<String> allowedRoots = const [],
  bool includeHidden = false,
}) {
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
    super.dispose();
  }

  void _onMessage(ServerMessage message) {
    if (!mounted || !_loading) return;
    if (message is DirectoryListingMessage) {
      if (!_matchesRequest(message.requestId, message.path)) return;
      final l = AppLocalizations.of(context);
      if (!_isAllowedPath(message.path)) {
        setState(() {
          _requestedPath = null;
          _requestedRequestId = null;
          _directories = const [];
          _error = l.directoryPathOutsideAllowedRoots;
          _loading = false;
        });
        return;
      }
      setState(() {
        _currentPath = message.path;
        _requestedPath = null;
        _requestedRequestId = null;
        _directories = message.directories
            .where((entry) => _isAllowedPath(entry.path))
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
            : message.message;
        _requestedRequestId = null;
        _loading = false;
      });
    }
  }

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
    if (!_isAllowedPath(normalized)) {
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

  bool _isAllowedPath(String path) {
    if (widget.allowedRoots.isEmpty) return true;
    return widget.allowedRoots.any((root) => _isPathWithinRoot(path, root));
  }

  void _goUp() {
    final parent = _parentPath(_currentPath);
    if (parent != null) _requestDirectory(parent);
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final parent = _parentPath(_currentPath);
    final height = math.min(MediaQuery.sizeOf(context).height * 0.78, 680.0);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DirectoryBrowserHeader(
              localizations: l,
              canGoUp: parent != null && _isAllowedPath(parent) && !_loading,
              loading: _loading,
              onGoUp: _goUp,
              onRefresh: () => _requestDirectory(_currentPath),
              onCancel: () => Navigator.pop(context),
            ),
            if (widget.allowedRoots.isNotEmpty)
              _DirectoryBrowserRoots(
                localizations: l,
                colorScheme: cs,
                roots: widget.allowedRoots,
                loading: _loading,
                onSelected: _requestDirectory,
              ),
            _DirectoryBrowserPathBanner(path: _currentPath, colorScheme: cs),
            const SizedBox(height: 8),
            Expanded(
              child: _DirectoryBrowserBody(
                localizations: l,
                colorScheme: cs,
                loading: _loading,
                error: _error,
                directories: _directories,
                onRetry: () =>
                    _requestDirectory(_requestedPath ?? _currentPath),
                onDirectorySelected: _requestDirectory,
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
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: const ValueKey('directory_browser_up_button'),
        tooltip: localizations.back,
        onPressed: canGoUp ? onGoUp : null,
        icon: const Icon(Icons.arrow_upward),
      ),
      Expanded(
        child: Text(
          localizations.browseDirectory,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
  );
}

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        localizations.directoryBrowserRoots,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
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
                onPressed: loading ? null : () => onSelected(root),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
    ],
  );
}

class _DirectoryBrowserPathBanner extends StatelessWidget {
  const _DirectoryBrowserPathBanner({
    required this.path,
    required this.colorScheme,
  });

  final String path;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      path,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class _DirectoryBrowserBody extends StatelessWidget {
  const _DirectoryBrowserBody({
    required this.localizations,
    required this.colorScheme,
    required this.loading,
    required this.error,
    required this.directories,
    required this.onRetry,
    required this.onDirectorySelected,
  });

  final AppLocalizations localizations;
  final ColorScheme colorScheme;
  final bool loading;
  final String? error;
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
        child: Text(
          localizations.noSubdirectories,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }
    return _DirectoryBrowserList(
      colorScheme: colorScheme,
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

class _DirectoryBrowserList extends StatelessWidget {
  const _DirectoryBrowserList({
    required this.colorScheme,
    required this.directories,
    required this.onSelected,
  });

  final ColorScheme colorScheme;
  final List<DirectoryListingEntry> directories;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const ValueKey('directory_browser_list'),
    itemCount: directories.length,
    separatorBuilder: (_, __) => const Divider(height: 1),
    itemBuilder: (context, index) {
      final directory = directories[index];
      return ListTile(
        key: ValueKey('directory_browser_entry_${directory.path}'),
        leading: Icon(Icons.folder_outlined, color: colorScheme.primary),
        title: Text(directory.name),
        subtitle: Text(
          directory.path,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onSelected(directory.path),
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
  Widget build(BuildContext context) => Row(
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
  );
}
