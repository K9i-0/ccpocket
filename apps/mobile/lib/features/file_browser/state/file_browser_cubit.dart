import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../explore/state/explore_cubit.dart';
import '../../explore/state/explore_state.dart';
import '../file_browser_history.dart';
import 'file_browser_state.dart';

p.Context browserPathContext(String root) => p.Context(
  style: RegExp(r'^[A-Za-z]:[\\/]').hasMatch(root) || root.startsWith(r'\\')
      ? p.Style.windows
      : p.Style.posix,
);

String normalizeBrowserPath(String root, String path) {
  final ctx = browserPathContext(root);
  final absolute = ctx.normalize(
    ctx.isAbsolute(path) ? path : ctx.join(root, path),
  );
  if (ctx.equals(root, absolute)) return '';
  if (!ctx.isWithin(root, absolute)) return absolute;
  return ctx.relative(absolute, from: root).replaceAll('\\', '/');
}

bool isBrowserRelative(String path) =>
    !path.startsWith('/') &&
    !RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path) &&
    !path.startsWith(r'\\');

/// Search index is independent from the authoritative, on-demand directory list.
List<ExploreEntry> searchBrowserEntries(
  List<String> files,
  String query, {
  Set<String> ignored = const {},
}) {
  final terms = query.toLowerCase().trim().split(RegExp(r'\s+'));
  final paths = <String, bool>{};
  for (final file in files) {
    final parts = file.split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 1; i <= parts.length; i++) {
      paths[parts.take(i).join('/')] = i < parts.length || file.endsWith('/');
    }
  }
  final results = paths.entries
      .where(
        (entry) =>
            terms.every((term) => entry.key.toLowerCase().contains(term)),
      )
      .map(
        (entry) => ExploreEntry(
          name: entry.key.split('/').last,
          relativePath: entry.key,
          isDirectory: entry.value,
          isIgnored: ignored.contains(entry.key),
        ),
      )
      .toList();
  results.sort((a, b) {
    final exactA = a.name.toLowerCase() == query.trim().toLowerCase();
    final exactB = b.name.toLowerCase() == query.trim().toLowerCase();
    if (exactA != exactB) return exactA ? -1 : 1;
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.relativePath.toLowerCase().compareTo(b.relativePath.toLowerCase());
  });
  return results;
}

class FileBrowserCubit extends Cubit<FileBrowserState> {
  final BridgeService bridge;
  final String projectPath;
  final Duration requestTimeout;
  late final FileBrowserHistory _recents;
  late final StreamSubscription<ServerMessage> _messages;
  late final StreamSubscription<FileListMessage> _indexSubscription;
  List<String> _index;
  Set<String> _ignored = {};
  List<ExploreEntry> _directoryEntries = [];
  final _directoryCache = <String, List<ExploreEntry>>{};
  bool _hasAuthoritativeListing = false;
  String? _requestId;
  String? _resolvingPath;
  int? _resolvingLine;
  bool _legacyProbe = false;
  Timer? _timeout;
  Future<void>? _closing;

  FileBrowserCubit({
    required this.bridge,
    required this.projectPath,
    String initialDirectory = '',
    String? initialTarget,
    List<String> initialFiles = const [],
    List<String> recentFiles = const [],
    this.requestTimeout = const Duration(seconds: 15),
  }) : _index = initialFiles.isNotEmpty
           ? initialFiles
           : bridge.fileListForProject(projectPath),
       super(
         FileBrowserState(
           location: BrowserLocation(directory: initialDirectory),
         ),
       ) {
    _ignored = bridge.ignoredFilesForProject(projectPath);
    _recents = FileBrowserHistory.forProject(bridge, projectPath)
      ..seed(recentFiles);
    _recents.addListener(_syncRecents);
    _syncRecents();
    _messages = bridge.messages.listen(_onMessage);
    _indexSubscription = bridge.fileListMessagesForProject(projectPath).listen((
      message,
    ) {
      if (message.error != null) return;
      _index = message.files;
      if (!_hasAuthoritativeListing) {
        _hasAuthoritativeListing = false;
        _directoryEntries = buildExploreEntries(
          _index,
          currentPath: state.location.directory,
          ignoredFiles: message.ignoredFiles,
        );
      }
      _ignored = message.ignoredFiles;
      emit(state.copyWith(indexTruncated: message.truncated));
      _updateEntries();
    });
    bridge.requestFileList(projectPath);
    if (initialTarget != null) {
      openTarget(initialTarget, remember: false);
    } else {
      openDirectory(initialDirectory, remember: false);
    }
  }

  void _syncRecents() => emit(state.copyWith(recentFiles: _recents.value));

  void _navigate(
    BrowserLocation location, {
    bool remember = true,
    bool keepListing = false,
  }) {
    if (!keepListing) _cancelRequest();
    emit(
      state.copyWith(
        location: location,
        history: remember && location != state.location
            ? [...state.history, state.location]
            : state.history,
        error: null,
        loading: keepListing ? state.loading : false,
      ),
    );
  }

  void openTarget(String raw, {bool remember = true}) {
    final lineMatch = RegExp(r':(\d+)(?::\d+)?$').firstMatch(raw);
    final line = lineMatch == null ? null : int.tryParse(lineMatch.group(1)!);
    final clean = lineMatch == null ? raw : raw.substring(0, lineMatch.start);
    final path = normalizeBrowserPath(projectPath, clean);
    if (!isBrowserRelative(path) || _index.contains(path)) {
      if (!remember && isBrowserRelative(path)) {
        _navigate(
          BrowserLocation(directory: parentDirectoryOf(path)),
          remember: false,
        );
        _directoryEntries = buildExploreEntries(
          _index,
          currentPath: state.location.directory,
          ignoredFiles: _ignored,
        );
        _updateEntries();
      }
      openFile(path, line: line, remember: remember);
      if (!remember && isBrowserRelative(path)) {
        _requestDirectory(state.location.directory);
      }
    } else if (path.isEmpty ||
        raw.endsWith('/') ||
        _index.any((f) => f.startsWith('$path/'))) {
      openDirectory(path, remember: remember);
    } else {
      _navigate(BrowserLocation(directory: path), remember: remember);
      _resolvingLine = line;
      _requestDirectory(path, resolve: true);
    }
  }

  void openFile(String path, {int? line, bool remember = true}) {
    _navigate(
      state.location.copyWith(file: path, line: line),
      remember: remember,
      keepListing: true,
    );
    _recents.record(path);
  }

  void openDirectory(String path, {bool remember = true}) {
    final relative = normalizeBrowserPath(projectPath, path);
    if (!isBrowserRelative(relative)) {
      emit(state.copyWith(error: 'directory_not_allowed'));
      return;
    }
    _navigate(BrowserLocation(directory: relative), remember: remember);
    _restoreDirectoryEntries(relative);
    _updateEntries();
    _requestDirectory(relative);
  }

  void showParent() {
    final file = state.location.file;
    if (file != null && !isBrowserRelative(file)) return;
    openDirectory(parentDirectoryOf(file ?? state.location.directory));
  }

  bool back() {
    if (state.history.isEmpty) return false;
    final previous = state.history.last;
    final rest = state.history.take(state.history.length - 1).toList();
    _navigate(previous, remember: false);
    emit(state.copyWith(history: rest));
    _restoreDirectoryEntries(previous.directory);
    _updateEntries();
    if (previous.file == null && previous.query.isEmpty) {
      _requestDirectory(previous.directory);
    }
    return true;
  }

  void restore(BrowserLocation location, List<BrowserLocation> history) {
    _navigate(location, remember: false);
    emit(state.copyWith(history: history));
    _restoreDirectoryEntries(location.directory);
    _updateEntries();
    if (location.query.isEmpty) _requestDirectory(location.directory);
  }

  void _restoreDirectoryEntries(String directory) {
    final cached = _directoryCache[directory];
    _hasAuthoritativeListing = cached != null;
    _directoryEntries =
        cached ??
        buildExploreEntries(
          _index,
          currentPath: directory,
          ignoredFiles: _ignored,
        );
  }

  void setQuery(String query) {
    final wasSearching = state.location.query.isNotEmpty;
    if (!wasSearching && query.isNotEmpty) {
      _navigate(state.location.copyWith(query: query, file: null, line: null));
    } else {
      _navigate(
        state.location.copyWith(query: query, file: null, line: null),
        remember: false,
      );
    }
    _updateEntries();
    if (query.isEmpty) _requestDirectory(state.location.directory);
  }

  void retry() {
    _requestDirectory(
      state.location.directory,
      resolve: _resolvingPath != null,
    );
  }

  void _updateEntries() {
    emit(
      state.copyWith(
        entries: state.location.query.trim().isEmpty
            ? _directoryEntries
            : searchBrowserEntries(
                _index,
                state.location.query,
                ignored: _ignored,
              ),
      ),
    );
  }

  void _requestDirectory(
    String relative, {
    bool resolve = false,
    bool legacyProbe = false,
  }) {
    _legacyProbe = legacyProbe;
    _cancelRequest();
    _resolvingPath = resolve ? relative : null;
    _requestId = bridge.createProjectRequestId('browser-directory');
    emit(state.copyWith(loading: true, error: null, legacyListing: false));
    _timeout = Timer(requestTimeout, () {
      if (!isClosed) {
        _requestId = null;
        emit(state.copyWith(loading: false, error: 'timeout'));
      }
    });
    bridge.send(
      ClientMessage.listDirectory(
        browserPathContext(projectPath).join(projectPath, relative),
        requestId: _requestId,
        includeHidden: true,
        includeFiles: !legacyProbe,
      ),
    );
  }

  void _onMessage(ServerMessage message) {
    if (_requestId == null) return;
    if (message is DirectoryListingMessage && message.requestId == _requestId) {
      final relative = normalizeBrowserPath(projectPath, message.path);
      if (relative != state.location.directory) return;
      _cancelRequest();
      _hasAuthoritativeListing = message.files != null;
      _directoryEntries = [
        for (final entry in message.directories)
          if (isBrowserRelative(normalizeBrowserPath(projectPath, entry.path)))
            ExploreEntry(
              name: entry.name,
              relativePath: normalizeBrowserPath(projectPath, entry.path),
              isDirectory: true,
            ),
        for (final entry in message.files ?? const <DirectoryListingEntry>[])
          if (isBrowserRelative(normalizeBrowserPath(projectPath, entry.path)))
            ExploreEntry(
              name: entry.name,
              relativePath: normalizeBrowserPath(projectPath, entry.path),
              isDirectory: false,
              isIgnored: _ignored.contains(
                normalizeBrowserPath(projectPath, entry.path),
              ),
            ),
      ];
      if (message.files != null) {
        _directoryCache[relative] = _directoryEntries;
      } else {
        _directoryCache.remove(relative);
      }
      if (message.files == null) {
        _directoryEntries.addAll(
          buildExploreEntries(
            _index,
            currentPath: relative,
            ignoredFiles: _ignored,
          ).where((entry) => !entry.isDirectory),
        );
      }
      emit(
        state.copyWith(loading: false, legacyListing: message.files == null),
      );
      _updateEntries();
    } else if (message is ErrorMessage &&
        (message.requestId == _requestId ||
            message.requestId == null &&
                message.errorCode == 'unsupported_message' &&
                message.message == 'list_directory')) {
      final resolving = _resolvingPath;
      final wasLegacyProbe = _legacyProbe;
      _cancelRequest();
      if (message.errorCode == 'not_a_directory' && resolving != null) {
        _navigate(
          BrowserLocation(
            directory: parentDirectoryOf(resolving),
            file: resolving,
            line: _resolvingLine,
          ),
          remember: false,
        );
        _directoryEntries = buildExploreEntries(
          _index,
          currentPath: state.location.directory,
          ignoredFiles: _ignored,
        );
        _hasAuthoritativeListing = false;
        _updateEntries();
        _recents.record(resolving);
        _requestDirectory(
          state.location.directory,
          legacyProbe: wasLegacyProbe,
        );
      } else if (message.errorCode == 'unsupported_message' &&
          resolving != null &&
          !wasLegacyProbe) {
        _requestDirectory(resolving, resolve: true, legacyProbe: true);
      } else if (message.errorCode == 'unsupported_message' &&
          resolving != null) {
        _navigate(
          BrowserLocation(
            directory: parentDirectoryOf(resolving),
            file: resolving,
            line: _resolvingLine,
          ),
          remember: false,
        );
        _directoryEntries = buildExploreEntries(
          _index,
          currentPath: state.location.directory,
          ignoredFiles: _ignored,
        );
        _hasAuthoritativeListing = false;
        _updateEntries();
        _recents.record(resolving);
        emit(state.copyWith(legacyListing: true));
      } else if (message.errorCode == 'unsupported_message') {
        emit(state.copyWith(loading: false, legacyListing: true));
        _hasAuthoritativeListing = false;
        _directoryEntries = buildExploreEntries(
          _index,
          currentPath: state.location.directory,
          ignoredFiles: _ignored,
        );
        _updateEntries();
      } else {
        emit(
          state.copyWith(
            loading: false,
            error: message.errorCode ?? message.message,
          ),
        );
      }
    }
  }

  void _cancelRequest() {
    _timeout?.cancel();
    _requestId = null;
  }

  @override
  Future<void> close() {
    if (_closing case final closing?) return closing;
    _cancelRequest();
    _recents.removeListener(_syncRecents);
    return _closing = Future.wait([
      _messages.cancel(),
      _indexSubscription.cancel(),
      super.close(),
    ]).then((_) {});
  }
}
