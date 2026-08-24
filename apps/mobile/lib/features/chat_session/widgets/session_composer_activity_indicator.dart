import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../widgets/composer_activity_indicator.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';
import '../state/streaming_state.dart';
import '../state/streaming_state_cubit.dart';

/// Connects composer activity feedback to the current chat session.
class SessionComposerActivityIndicator extends StatefulWidget {
  final ProcessStatus status;
  final DateTime Function()? now;

  const SessionComposerActivityIndicator({
    super.key,
    required this.status,
    @visibleForTesting this.now,
  });

  @override
  State<SessionComposerActivityIndicator> createState() =>
      _SessionComposerActivityIndicatorState();
}

class _SessionComposerActivityIndicatorState
    extends State<SessionComposerActivityIndicator> {
  DateTime? _activeSince;
  DateTime? _lastActivityAt;
  var _initialized = false;
  var _awaitingHistoryBaseline = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!_isActive(widget.status)) return;

    final entries = context.read<ChatSessionCubit>().state.entries;
    if (activeTurnStartedAt(entries) == null) {
      _awaitingHistoryBaseline = true;
      return;
    }
    _applyEntryBaseline(entries);
  }

  @override
  void didUpdateWidget(SessionComposerActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = _isActive(oldWidget.status);
    final isActive = _isActive(widget.status);
    if (wasActive == isActive) return;
    if (isActive) {
      _activeSince = _now;
      _lastActivityAt = _activeSince;
      _awaitingHistoryBaseline = false;
    } else {
      _activeSince = null;
      _lastActivityAt = null;
      _awaitingHistoryBaseline = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoadingSession = context.select<ChatSessionCubit, bool>(
      (cubit) => cubit.state.bulkLoading,
    );
    return MultiBlocListener(
      listeners: [
        BlocListener<ChatSessionCubit, ChatSessionState>(
          listenWhen: (previous, current) =>
              !listEquals(previous.entries, current.entries),
          listener: (_, state) => _handleEntriesChanged(state.entries),
        ),
        BlocListener<StreamingStateCubit, StreamingState>(
          listenWhen: (previous, current) =>
              previous.text != current.text ||
              previous.thinking != current.thinking ||
              previous.isStreaming != current.isStreaming,
          listener: (_, _) => _recordActivity(),
        ),
      ],
      child: ComposerActivityIndicator(
        // A newly opened session starts in ProcessStatus.starting while its
        // history is still loading. Do not present that placeholder state as
        // active agent work until a turn or stream confirms activity.
        status: isLoadingSession || _activeSince == null
            ? ProcessStatus.idle
            : widget.status,
        startedAt: _activeSince,
        lastActivityAt: _lastActivityAt,
        now: widget.now,
      ),
    );
  }

  void _recordActivity() {
    if (!_isActive(widget.status)) return;
    setState(() {
      final now = _now;
      _activeSince ??= now;
      _lastActivityAt = now;
      _awaitingHistoryBaseline = false;
    });
  }

  void _handleEntriesChanged(List<ChatEntry> entries) {
    if (!_isActive(widget.status)) return;
    if (_awaitingHistoryBaseline) {
      if (activeTurnStartedAt(entries) != null) {
        setState(() {
          _applyEntryBaseline(entries);
          _awaitingHistoryBaseline = false;
        });
      }
      return;
    }
    _recordActivity();
  }

  void _applyEntryBaseline(List<ChatEntry> entries) {
    _activeSince = activeTurnStartedAt(entries) ?? _now;
    final latestEntryAt = entries.lastOrNull?.timestamp;
    _lastActivityAt =
        latestEntryAt == null || latestEntryAt.isBefore(_activeSince!)
        ? _activeSince
        : latestEntryAt;
  }

  DateTime get _now => widget.now?.call() ?? DateTime.now();
}

@visibleForTesting
DateTime? activeTurnStartedAt(List<ChatEntry> entries) {
  for (final entry in entries.reversed) {
    if (entry is UserChatEntry) return entry.timestamp;
  }
  return null;
}

bool _isActive(ProcessStatus status) =>
    status == ProcessStatus.starting ||
    status == ProcessStatus.running ||
    status == ProcessStatus.compacting;
