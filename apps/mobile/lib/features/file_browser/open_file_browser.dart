import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/bridge_service.dart';
import '../chat_session/state/chat_session_cubit.dart';
import '../session_list/workspace_shell_screen.dart';
import 'file_browser_reference.dart';
import 'file_browser_view.dart';
import 'state/file_browser_cubit.dart';

Future<void> showFileBrowser(
  BuildContext context, {
  required BridgeService bridge,
  required String projectPath,
  required String target,
  List<String> initialFiles = const [],
}) async {
  final cubit = FileBrowserCubit(
    bridge: bridge,
    projectPath: projectPath,
    initialTarget: target,
    initialFiles: initialFiles,
  );
  final shell = WorkspaceShellScreen.maybeOf(context);
  final sessionId =
      context.read<ChatSessionCubit?>()?.sessionId ?? shell?.liveSessionId;
  final reference = FileBrowserReferences.capture(bridge, sessionId);
  var addedReference = false;
  try {
    await presentFileBrowser(
      context,
      cubit: cubit,
      ownsCubit: true,
      onAddToChat: reference == null
          ? null
          : (path) {
              reference(path);
              addedReference = true;
            },
    );
  } finally {
    if (addedReference &&
        shell != null &&
        shell.mounted &&
        shell.liveSessionId == sessionId) {
      shell.closeToolPane();
    }
    await cubit.close();
  }
}

Future<void> presentFileBrowser(
  BuildContext context, {
  required FileBrowserCubit cubit,
  ValueChanged<String>? onAddToChat,
  bool ownsCubit = false,
}) {
  final shell = WorkspaceShellScreen.maybeOf(context);
  Widget build(VoidCallback close) {
    final view = FileBrowserView(
      onClose: close,
      onAddToChat: onAddToChat,
      handlesSystemBack: shell == null,
    );
    return ownsCubit
        ? BlocProvider(create: (_) => cubit, lazy: false, child: view)
        : BlocProvider.value(value: cubit, child: view);
  }

  if (shell != null) {
    return shell.showFileBrowser(
      builder: build,
      back: (close) => () {
        if (!cubit.back()) close();
      },
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) => build(() => Navigator.of(routeContext).pop()),
    ),
  );
}
