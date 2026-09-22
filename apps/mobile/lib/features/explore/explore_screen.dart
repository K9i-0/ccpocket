import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../services/bridge_service.dart';
import '../file_upload/widgets/file_upload_dialog.dart';
import '../file_browser/file_browser_reference.dart';
import '../file_browser/file_browser_view.dart';
import '../file_browser/open_file_browser.dart';
import '../file_browser/state/file_browser_cubit.dart';
import '../file_browser/state/file_browser_state.dart';
import '../session_list/workspace_shell_screen.dart';
import 'state/explore_state.dart';

Future<ExploreScreenResult?> openExplorerScreen(
  BuildContext context, {
  required String sessionId,
  required String projectPath,
  List<String> initialFiles = const [],
  String initialPath = '',
  List<String> recentPeekedFiles = const [],
}) {
  final bridge = context.read<BridgeService>();
  return Navigator.of(context).push<ExploreScreenResult>(
    MaterialPageRoute(
      builder: (_) => RepositoryProvider<BridgeService>.value(
        value: bridge,
        child: ExploreScreen(
          sessionId: sessionId,
          projectPath: projectPath,
          initialFiles: initialFiles,
          initialPath: initialPath,
          recentPeekedFiles: recentPeekedFiles,
        ),
      ),
    ),
  );
}

@RoutePage()
class ExploreScreen extends StatefulWidget {
  final String sessionId;
  final String projectPath;
  final List<String> initialFiles;
  final String initialPath;
  final List<String> recentPeekedFiles;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<ExploreScreenResult>? onResultChanged;
  const ExploreScreen({
    super.key,
    required this.sessionId,
    required this.projectPath,
    this.initialFiles = const [],
    this.initialPath = '',
    this.recentPeekedFiles = const [],
    this.embedded = false,
    this.onClose,
    this.onResultChanged,
  });
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late final FileBrowserCubit _cubit;
  late final StreamSubscription<FileBrowserState> _subscription;
  bool _expanded = false;
  @override
  void initState() {
    super.initState();
    _cubit = FileBrowserCubit(
      bridge: context.read<BridgeService>(),
      projectPath: widget.projectPath,
      initialFiles: widget.initialFiles,
      initialDirectory: widget.initialPath,
      recentFiles: widget.recentPeekedFiles,
    );
    _subscription = _cubit.stream.listen((state) {
      widget.onResultChanged?.call(
        ExploreScreenResult(
          currentPath: state.location.directory,
          recentPeekedFiles: state.recentFiles,
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _cubit.close();
    super.dispose();
  }

  void _close() {
    if (widget.embedded) {
      widget.onClose?.call();
    } else {
      Navigator.of(context).pop(
        ExploreScreenResult(
          currentPath: _cubit.state.location.directory,
          recentPeekedFiles: _cubit.state.recentFiles,
        ),
      );
    }
  }

  Future<void> _expandFile(String path) async {
    if (_expanded) return;
    final location = _cubit.state.location;
    final history = _cubit.state.history;
    _expanded = true;
    _cubit.openFile(path);
    var addedReference = false;
    final reference = FileBrowserReferences.capture(
      _cubit.bridge,
      widget.sessionId,
    );
    await presentFileBrowser(
      context,
      cubit: _cubit,
      onAddToChat: reference == null
          ? null
          : (path) {
              reference(path);
              addedReference = true;
            },
    );
    if (!mounted) return;
    _expanded = false;
    _cubit.restore(location, history);
    if (addedReference) _close();
  }

  Future<void> _pickAndUploadFiles(FileBrowserCubit cubit) async {
    final l = AppLocalizations.of(context);
    try {
      final files = await openFiles();
      if (!mounted || files.isEmpty) return;
      if (files.length > maxUploadFileCount) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.fileUploadTooMany)));
        return;
      }
      final sizes = await Future.wait(files.map((file) => file.length()));
      if (!mounted) return;
      if (sizes.any((size) => size > maxUploadFileBytes)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.fileUploadFileTooLarge)));
        return;
      }
      if (sizes.fold<int>(0, (total, size) => total + size) >
          maxUploadTotalBytes) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.fileUploadTotalTooLarge)));
        return;
      }
      final uploadedPaths = await showProjectFileUploadDialog(
        context,
        bridge: context.read<BridgeService>(),
        projectPath: widget.projectPath,
        directoryPath: cubit.state.location.directory,
        files: files,
        fileSizes: sizes,
      );
      if (!mounted || uploadedPaths == null || uploadedPaths.isEmpty) return;
      cubit.retry();
      context.read<BridgeService>().requestFileList(widget.projectPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.fileUploadSelectionFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = WorkspaceShellScreen.maybeOf(context);
    final embedded = widget.embedded && shell != null;
    return BlocProvider.value(
      value: _cubit,
      child: FileBrowserView(
        embedded: embedded,
        onClose: _close,
        onOpenFile: embedded ? _expandFile : null,
        onAddToChat: FileBrowserReferences.capture(
          _cubit.bridge,
          widget.sessionId,
        ),
        onUpload: supportsProjectFileUpload
            ? () => _pickAndUploadFiles(_cubit)
            : null,
      ),
    );
  }
}
