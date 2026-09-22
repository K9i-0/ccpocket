import '../../widgets/workspace_pane_chrome.dart';
import '../session_list/workspace_shell_screen.dart';
import '../explore/widgets/explore_entry_tile.dart';
import '../file_transfer/widgets/file_transfer_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/file_type_icon.dart';
import '../file_peek/file_peek_sheet.dart';
import '../explore/widgets/explore_breadcrumbs.dart';
import '../explore/state/explore_cubit.dart';
import '../explore/state/explore_state.dart';
import 'state/file_browser_cubit.dart';
import 'state/file_browser_state.dart';

/// Shared full-screen and embedded browser. Navigation belongs to the Cubit;
/// focus, scroll storage and sidebar visibility belong to this presentation.
class FileBrowserView extends StatefulWidget {
  final VoidCallback onClose;
  final ValueChanged<String>? onAddToChat;
  final ValueChanged<String>? onOpenFile;
  final VoidCallback? onUpload;
  final bool embedded;
  final bool handlesSystemBack;
  const FileBrowserView({
    super.key,
    required this.onClose,
    this.onAddToChat,
    this.onOpenFile,
    this.onUpload,
    this.embedded = false,
    this.handlesSystemBack = true,
  });
  @override
  State<FileBrowserView> createState() => _FileBrowserViewState();
}

class _FileBrowserViewState extends State<FileBrowserView> {
  final _bucket = PageStorageBucket();
  final _listOffsets = <(String, String), double>{};
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _browserFocus = FocusNode();
  bool _showList = true;
  @override
  void dispose() {
    _search.dispose();
    _focus.dispose();
    _browserFocus.dispose();
    super.dispose();
  }

  void _back() {
    _browserFocus.requestFocus();
    if (!context.read<FileBrowserCubit>().back()) widget.onClose();
  }

  void _open(ExploreEntry entry) {
    _focus.unfocus();
    _browserFocus.requestFocus();
    final cubit = context.read<FileBrowserCubit>();
    if (entry.isDirectory) {
      cubit.openDirectory(entry.relativePath);
    } else if (widget.onOpenFile != null) {
      widget.onOpenFile!(entry.relativePath);
    } else {
      cubit.openFile(entry.relativePath);
    }
  }

  Future<void> _recent() async {
    final cubit = context.read<FileBrowserCubit>();
    final path = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => BrowserRecentFiles(paths: cubit.state.recentFiles),
    );
    if (path != null && mounted) {
      _open(
        ExploreEntry(
          name: path.split('/').last,
          relativePath: path,
          isDirectory: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FileBrowserCubit>();
    final shell = WorkspaceShellScreen.maybeOf(context);
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
      isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
      slot: WorkspacePaneSlot.center,
    );
    return BlocBuilder<FileBrowserCubit, FileBrowserState>(
      builder: (context, state) {
        final location = state.location;
        if (_search.text != location.query) {
          _search.value = TextEditingValue(
            text: location.query,
            selection: TextSelection.collapsed(offset: location.query.length),
          );
        }
        final file = widget.embedded ? null : location.file;
        return PopScope(
          canPop: !widget.handlesSystemBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && widget.handlesSystemBack) _back();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
              const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                  _focus.requestFocus,
              const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                  _focus.requestFocus,
            },
            child: Focus(
              focusNode: _browserFocus,
              autofocus: !widget.embedded,
              child: Scaffold(
                body: SafeArea(
                  minimum: EdgeInsets.only(top: chrome.topInset),
                  child: PageStorage(
                    bucket: _bucket,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide =
                            constraints.maxWidth >= 760 && !widget.embedded;
                        final showList = file == null || wide && _showList;
                        return Column(
                          children: [
                            BrowserHeader(
                              embedded: widget.embedded,
                              showToggle: wide && file != null,
                              showList: _showList,
                              onToggle: () =>
                                  setState(() => _showList = !_showList),
                              onRecent: _recent,
                              onUpload: widget.onUpload,
                              onClose: widget.onClose,
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  if (showList)
                                    SizedBox(
                                      width: wide && file != null
                                          ? 280
                                          : constraints.maxWidth,
                                      child: BrowserSearchPane(
                                        offsets: _listOffsets,
                                        state: state,
                                        controller: _search,
                                        focus: _focus,
                                        onOpen: _open,
                                      ),
                                    ),
                                  if (showList && file != null)
                                    const VerticalDivider(width: 1),
                                  if (file != null)
                                    Expanded(
                                      child: BrowserFilePreview(
                                        key: ValueKey((file, location.line)),
                                        filePath: file,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            BrowserNavigationBar(
                              onBack: _back,
                              onParent:
                                  file != null && !isBrowserRelative(file) ||
                                      file == null && location.directory.isEmpty
                                  ? null
                                  : cubit.showParent,
                              onAddToChat: widget.onAddToChat == null
                                  ? null
                                  : () {
                                      widget.onAddToChat!(
                                        file ??
                                            (location.directory.isEmpty
                                                ? '.'
                                                : '${location.directory}/'),
                                      );
                                      widget.onClose();
                                    },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BrowserHeader extends StatelessWidget {
  final bool embedded, showToggle, showList;
  final VoidCallback onToggle, onRecent, onClose;
  final VoidCallback? onUpload;
  const BrowserHeader({
    super.key,
    required this.embedded,
    required this.showToggle,
    required this.showList,
    required this.onToggle,
    required this.onRecent,
    required this.onClose,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      key: const ValueKey('browser_header'),
      height: 52,
      child: Row(
        children: [
          IconButton(
            key: ValueKey(
              embedded ? 'close_explore_pane_button' : 'file_peek_close_button',
            ),
            tooltip: l.browserClose,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          Expanded(
            child: Text(
              l.browserTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (showToggle)
            IconButton(
              key: const ValueKey('browser_toggle_list_button'),
              tooltip: l.browserToggleList,
              onPressed: onToggle,
              icon: Icon(
                showList ? Icons.view_sidebar_outlined : Icons.view_sidebar,
              ),
            ),
          if (onUpload != null)
            IconButton(
              key: const ValueKey('explore_upload_button'),
              tooltip: l.fileUploadTitle,
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file),
            ),
          IconButton(
            key: const ValueKey('explore_recent_files_button'),
            tooltip: l.browserRecent,
            onPressed: onRecent,
            icon: const Icon(Icons.history),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class BrowserSearchPane extends StatelessWidget {
  final FileBrowserState state;
  final Map<(String, String), double> offsets;
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<ExploreEntry> onOpen;
  const BrowserSearchPane({
    super.key,
    required this.state,
    required this.offsets,
    required this.controller,
    required this.focus,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<FileBrowserCubit>();
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              key: const ValueKey('browser_search_field'),
              controller: controller,
              focusNode: focus,
              onChanged: cubit.setQuery,
              decoration: InputDecoration(
                hintText: l.browserSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: state.location.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.browserClose,
                        icon: const Icon(Icons.clear),
                        onPressed: () => cubit.setQuery(''),
                      ),
              ),
            ),
          ),
          if (state.location.query.isEmpty && constraints.maxHeight >= 240)
            ExploreBreadcrumbs(
              projectName: cubit.projectPath.split(RegExp(r'[/\\]')).last,
              currentPath: state.location.directory,
              breadcrumbs: breadcrumbsForPath(state.location.directory),
              onTapCrumb: cubit.openDirectory,
            ),
          if (state.legacyListing) BrowserNotice(text: l.browserLegacy),
          if (state.indexTruncated)
            BrowserNotice(
              key: const ValueKey('explore_file_list_truncated_notice'),
              text: l.browserIndexLimited,
            ),
          Expanded(
            child: BrowserEntryList(
              offsets: offsets,
              state: state,
              onOpen: onOpen,
              onRetry: cubit.retry,
            ),
          ),
        ],
      ),
    );
  }
}

class BrowserEntryList extends StatelessWidget {
  final FileBrowserState state;
  final Map<(String, String), double> offsets;
  final ValueChanged<ExploreEntry> onOpen;
  final VoidCallback onRetry;
  const BrowserEntryList({
    super.key,
    required this.state,
    required this.offsets,
    required this.onOpen,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.error != null) {
      final message = switch (state.error) {
        'timeout' => l.browserTimeout,
        'directory_not_allowed' => l.browserNotAllowed,
        'directory_not_found' => l.browserNotFound,
        _ => l.browserUnreadable,
      };
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                key: const ValueKey('browser_retry_button'),
                onPressed: onRetry,
                child: Text(l.browserRetry),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (state.loading)
          const LinearProgressIndicator(
            key: ValueKey('browser_loading_indicator'),
          ),
        if (state.entries.isEmpty && !state.loading)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  state.location.query.isEmpty
                      ? l.browserEmpty
                      : l.browserNoResults,
                ),
              ),
            ),
          ),
        if (state.entries.isNotEmpty)
          Expanded(
            child: BrowserScrollableEntries(
              offsets: offsets,
              key: PageStorageKey((
                'directory',
                state.location.directory,
                state.location.query,
              )),
              state: state,
              onOpen: onOpen,
              onRetry: onRetry,
            ),
          ),
      ],
    );
  }
}

class BrowserFilePreview extends StatefulWidget {
  final String filePath;
  const BrowserFilePreview({super.key, required this.filePath});
  @override
  State<BrowserFilePreview> createState() => _BrowserFilePreviewState();
}

class _BrowserFilePreviewState extends State<BrowserFilePreview> {
  late final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<FileBrowserCubit>();
    return FilePeekContent(
      key: PageStorageKey(('browser_file', widget.filePath)),
      bridge: cubit.bridge,
      projectPath: cubit.projectPath,
      filePath: widget.filePath,
      scrollController: _scroll,
      initialLine: cubit.state.location.line,
    );
  }
}

class BrowserNavigationBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onParent;
  final VoidCallback? onAddToChat;
  const BrowserNavigationBar({
    super.key,
    required this.onBack,
    this.onParent,
    this.onAddToChat,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: SizedBox(
        height: 56,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              key: const ValueKey('browser_back_button'),
              tooltip: l.browserBack,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            IconButton(
              key: const ValueKey('browser_parent_button'),
              tooltip: l.browserParent,
              onPressed: onParent,
              icon: const Icon(Icons.drive_folder_upload_outlined),
            ),
            if (onAddToChat != null)
              IconButton(
                key: const ValueKey('browser_add_to_chat_button'),
                tooltip: l.browserAddToChat,
                onPressed: onAddToChat,
                icon: const Icon(Icons.add_comment_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class BrowserNotice extends StatelessWidget {
  final String text;
  const BrowserNotice({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class BrowserRecentFiles extends StatelessWidget {
  final List<String> paths;
  const BrowserRecentFiles({super.key, required this.paths});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.browserRecent,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (paths.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.browserNoRecent),
            ),
          Flexible(
            child: ListView.builder(
              primary: false,
              shrinkWrap: true,
              itemCount: paths.length,
              itemBuilder: (context, i) => ListTile(
                key: ValueKey('browser_recent_${paths[i]}'),
                leading: FileTypeIcon(path: paths[i]),
                title: Text(paths[i].split('/').last),
                subtitle: Text(
                  paths[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(context, paths[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrowserScrollableEntries extends StatefulWidget {
  final FileBrowserState state;
  final Map<(String, String), double> offsets;
  final ValueChanged<ExploreEntry> onOpen;
  final VoidCallback onRetry;
  const BrowserScrollableEntries({
    super.key,
    required this.state,
    required this.offsets,
    required this.onOpen,
    required this.onRetry,
  });
  @override
  State<BrowserScrollableEntries> createState() =>
      _BrowserScrollableEntriesState();
}

class _BrowserScrollableEntriesState extends State<BrowserScrollableEntries> {
  late final _locationKey = (
    widget.state.location.directory,
    widget.state.location.query,
  );
  late final ScrollController _controller =
      ScrollController(
        initialScrollOffset: widget.offsets[_locationKey] ?? 0,
        keepScrollOffset: false,
      )..addListener(() {
        widget.offsets[_locationKey] = _controller.offset;
      });
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<FileBrowserCubit>();
    return RefreshIndicator(
      onRefresh: () async => widget.onRetry(),
      child: ListView.builder(
        key: const ValueKey('explore_list'),
        controller: _controller,
        itemCount: state.entries.length,
        itemBuilder: (context, index) {
          final entry = state.entries[index];
          return ExploreEntryTile(
            entry: entry,
            showPath: state.location.query.isNotEmpty,
            isHighlighted: state.location.file == entry.relativePath,
            onTap: () => widget.onOpen(entry),
            onShareFile: !entry.isDirectory && supportsProjectFileTransfer
                ? () => showProjectFileTransferDialog(
                    context,
                    bridge: cubit.bridge,
                    projectPath: cubit.projectPath,
                    filePath: entry.relativePath,
                  )
                : null,
          );
        },
      ),
    );
  }
}
