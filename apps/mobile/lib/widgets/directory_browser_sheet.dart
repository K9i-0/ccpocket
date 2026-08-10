import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../services/bridge_service_base.dart';

String _normalizePathForComparison(String path) {
  final separator = String.fromCharCode(92);
  var value = path.trim().replaceAll(separator, '/');
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
  if (drive != null) {
    return (body.isEmpty ? '$drive/' : '$drive/$body').toLowerCase();
  }
  if (absolute) return body.isEmpty ? '/' : '/$body';
  return body;
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

Future<String?> showDirectoryBrowserSheet({
  required BuildContext context,
  required BridgeServiceBase bridge,
  String? initialPath,
  List<String> allowedRoots = const [],
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
    ),
  );
}

class _DirectoryBrowserSheet extends StatefulWidget {
  final BridgeServiceBase bridge;
  final String initialPath;
  final List<String> allowedRoots;

  const _DirectoryBrowserSheet({
    required this.bridge,
    required this.initialPath,
    required this.allowedRoots,
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
    if (message is ErrorMessage &&
        _matchesRequest(message.requestId, message.path) &&
        (_isDirectoryError(message.errorCode) ||
            message.requestId != null ||
            message.path != null)) {
      setState(() {
        _error = message.message;
        _requestedRequestId = null;
        _loading = false;
      });
    }
  }

  bool _matchesRequest(String? requestId, String? path) {
    if (requestId != null && _requestedRequestId != null) {
      return requestId == _requestedRequestId;
    }
    if (path != null && _requestedPath != null) {
      return _normalizePathForComparison(path) ==
          _normalizePathForComparison(_requestedPath!);
    }
    return true;
  }

  bool _isDirectoryError(String? code) {
    return code == 'directory_not_allowed' ||
        code == 'directory_not_found' ||
        code == 'directory_not_readable' ||
        code == 'not_a_directory' ||
        code == 'directory_read_failed' ||
        code == 'unsupported_message';
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
    widget.bridge.requestDirectoryListing(normalized, requestId: requestId);
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
            Row(
              children: [
                IconButton(
                  key: const ValueKey('directory_browser_up_button'),
                  tooltip: l.back,
                  onPressed: parent == null || _loading ? null : _goUp,
                  icon: const Icon(Icons.arrow_upward),
                ),
                Expanded(
                  child: Text(
                    l.browseDirectory,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('directory_browser_refresh_button'),
                  tooltip: l.retry,
                  onPressed: _loading
                      ? null
                      : () => _requestDirectory(_currentPath),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  key: const ValueKey('directory_browser_cancel_button'),
                  tooltip: l.cancel,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (widget.allowedRoots.isNotEmpty) ...[
              Text(
                l.directoryBrowserRoots,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final root in widget.allowedRoots)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(_leafName(root)),
                          avatar: const Icon(Icons.folder_outlined, size: 16),
                          onPressed: _loading
                              ? null
                              : () => _requestDirectory(root),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _currentPath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody(l, cs)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('directory_browser_cancel_action'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('directory_browser_select_action'),
                    onPressed: _loading || _error != null
                        ? null
                        : () => Navigator.pop(context, _currentPath),
                    icon: const Icon(Icons.folder_open),
                    label: Text(l.selectDirectory),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, ColorScheme cs) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 32),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    _requestDirectory(_requestedPath ?? _currentPath),
                icon: const Icon(Icons.refresh),
                label: Text(l.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_directories.isEmpty) {
      return Center(
        child: Text(
          l.noSubdirectories,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    return ListView.separated(
      key: const ValueKey('directory_browser_list'),
      itemCount: _directories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final directory = _directories[index];
        return ListTile(
          key: ValueKey('directory_browser_entry_${directory.path}'),
          leading: Icon(Icons.folder_outlined, color: cs.primary),
          title: Text(directory.name),
          subtitle: Text(
            directory.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _loading ? null : () => _requestDirectory(directory.path),
        );
      },
    );
  }
}
