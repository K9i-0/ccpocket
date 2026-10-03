import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../settings/state/settings_cubit.dart';
import '../../settings/state/settings_state.dart';
import '../state/chat_session_cubit.dart';
import '../state/chat_session_state.dart';

Future<void> showChatDisplayModeSheet(BuildContext context, String sessionId) {
  final settings = context.read<SettingsCubit>();
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => BlocProvider.value(
      value: settings,
      child: _DisplayModeSheet(sessionId: sessionId),
    ),
  );
}

class _DisplayModeSheet extends StatelessWidget {
  const _DisplayModeSheet({required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = context.watch<SettingsCubit>();
    final selected = settings.state.sessionLiteModes[sessionId];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.chatDisplayMode,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final option in <(bool?, String, String)>[
            (
              null,
              '${l.followDefaultMode} (${settings.state.liteMode ? l.liteMode : l.standardMode})',
              'default',
            ),
            (false, l.standardMode, 'standard'),
            (true, l.liteMode, 'lite'),
          ])
            ListTile(
              key: ValueKey('display_mode_${option.$3}'),
              title: Text(option.$2),
              trailing: selected == option.$1 ? const Icon(Icons.check) : null,
              onTap: () {
                settings.setSessionLiteMode(sessionId, option.$1);
                Navigator.pop(context);
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l.liteModeDescription),
          ),
        ],
      ),
    );
  }
}

/// Kept outside the transcript: ticking must never rebuild the message list.
class LiteModeActivityBar extends StatelessWidget {
  const LiteModeActivityBar({super.key, required this.sessionId});
  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsCubit, SettingsState, bool>(
      selector: (state) => state.liteModeForSession(sessionId),
      builder: (context, enabled) =>
          enabled ? const _ActivityStatus() : const SizedBox.shrink(),
    );
  }
}

class _ActivityStatus extends StatefulWidget {
  const _ActivityStatus();

  @override
  State<_ActivityStatus> createState() => _ActivityStatusState();
}

class _ActivityStatusState extends State<_ActivityStatus> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          context.read<ChatSessionCubit>().state.status != ProcessStatus.idle) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<ChatSessionCubit>();
    final l = AppLocalizations.of(context);
    final status = cubit.state.status;
    final active = status != ProcessStatus.idle;
    final label = switch (status) {
      ProcessStatus.running => l.liteModeRunning,
      ProcessStatus.starting => l.liteModeStarting,
      ProcessStatus.compacting => l.liteModeCompacting,
      ProcessStatus.waitingApproval => l.liteModeWaiting,
      ProcessStatus.idle => l.liteModeIdle,
    };
    final now = DateTime.now();
    final summary = [
      label,
      if (active && cubit.activityObservedSince != null)
        l.liteModeObserved(
          formatLiteModeDuration(
            now.difference(cubit.activityObservedSince!),
            l,
          ),
        ),
      if (active && cubit.lastAgentActivityAt != null)
        l.liteModeLastActivity(
          formatLiteModeDuration(now.difference(cubit.lastAgentActivityAt!), l),
        ),
      if (active && cubit.latestActivityTool != null) cubit.latestActivityTool!,
    ].join(' · ');
    return Padding(
      key: const ValueKey('lite_mode_activity_indicator'),
      padding: EdgeInsets.fromLTRB(
        16,
        6,
        16,
        6 +
            (cubit.state.approval is ApprovalNone
                ? 0
                : MediaQuery.paddingOf(context).bottom),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tooltip(
                    message: summary,
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!cubit.supportsPerformanceMode)
                    Text(l.performanceModeBridgeUpdate),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uses at most two adjacent units, including for multi-day goal sessions.
String formatLiteModeDuration(Duration duration, AppLocalizations l) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  if (seconds < 60) return l.liteModeDurationSeconds(seconds);
  if (seconds < 3600) {
    return l.liteModeDurationMinutes(seconds ~/ 60, seconds % 60);
  }
  if (seconds < 86400) {
    return l.liteModeDurationHours(seconds ~/ 3600, seconds ~/ 60 % 60);
  }
  return l.liteModeDurationDays(seconds ~/ 86400, seconds ~/ 3600 % 24);
}
