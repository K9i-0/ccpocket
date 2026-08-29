import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../providers/bridge_cubits.dart';
import '../../../services/bridge_service.dart';
import '../state/chat_session_cubit.dart';

/// Keeps file completion and peek data scoped to the canonical project for
/// the active session without rebuilding the session screen when that project
/// becomes available after navigation.
class SessionFileListScope extends StatefulWidget {
  const SessionFileListScope({
    super.key,
    required this.bridge,
    required this.child,
    this.fallbackProjectPath,
  });

  final BridgeService bridge;
  final String? fallbackProjectPath;
  final Widget child;

  @override
  State<SessionFileListScope> createState() => _SessionFileListScopeState();
}

class _SessionFileListScopeState extends State<SessionFileListScope> {
  FileListCubit? _fileListCubit;
  String? _activeProjectPath;

  @override
  Widget build(BuildContext context) {
    final contextProjectPath = context.select(
      (ChatSessionCubit cubit) => cubit.state.projectPath,
    );
    final projectPath = _firstNonEmpty(
      contextProjectPath,
      widget.fallbackProjectPath,
    );
    if (_fileListCubit == null || projectPath != _activeProjectPath) {
      _replaceCubit(projectPath);
    }

    return BlocProvider<FileListCubit>.value(
      value: _fileListCubit!,
      child: widget.child,
    );
  }

  void _replaceCubit(String? projectPath) {
    final previous = _fileListCubit;
    _activeProjectPath = projectPath;
    _fileListCubit = projectPath == null
        ? FileListCubit(const [], widget.bridge.fileList)
        : FileListCubit(
            widget.bridge.fileListForProject(projectPath),
            widget.bridge
                .fileListMessagesForProject(projectPath)
                .map((message) => message.files),
          );
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(previous.close());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_fileListCubit?.close());
    super.dispose();
  }
}

String? _firstNonEmpty(String? primary, String? fallback) {
  final normalizedPrimary = primary?.trim();
  if (normalizedPrimary?.isNotEmpty == true) return normalizedPrimary;
  final normalizedFallback = fallback?.trim();
  return normalizedFallback?.isNotEmpty == true ? normalizedFallback : null;
}
