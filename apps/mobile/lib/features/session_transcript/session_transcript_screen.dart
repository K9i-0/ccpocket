import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_localizations.dart';
import '../../services/bridge_service.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../chat_session/lite_mode_projection.dart';
import 'state/session_transcript_cubit.dart';
import 'state/session_transcript_state.dart';

/// Opens the read-only full transcript of [sessionId].
void openSessionTranscript(
  BuildContext context, {
  required String sessionId,
  required String? httpBaseUrl,
  required bool isCodex,
  required bool liteMode,
}) {
  final bridge = context.read<BridgeService>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider(
        create: (_) => SessionTranscriptCubit(
          messages: bridge.messages,
          send: bridge.send,
          sessionId: sessionId,
        )..load(),
        child: SessionTranscriptScreen(
          httpBaseUrl: httpBaseUrl,
          isCodex: isCodex,
          liteMode: liteMode,
        ),
      ),
    ),
  );
}

/// Earlier messages of a session, including those summarized by context
/// compaction or dropped from the live history window.
class SessionTranscriptScreen extends StatelessWidget {
  const SessionTranscriptScreen({
    super.key,
    required this.httpBaseUrl,
    required this.isCodex,
    required this.liteMode,
  });

  final String? httpBaseUrl;
  final bool isCodex;
  final bool liteMode;

  @override
  Widget build(BuildContext context) {
    final chrome = resolveStandalonePaneChrome(context);
    return Scaffold(
      appBar: chrome.wrapAppBar(
        AppBar(title: Text(AppLocalizations.of(context).transcriptTitle)),
      ),
      body: BlocBuilder<SessionTranscriptCubit, SessionTranscriptState>(
        builder: (context, state) => switch (state.status) {
          SessionTranscriptStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          SessionTranscriptStatus.failed => _TranscriptMessage(
            text: AppLocalizations.of(context).transcriptLoadFailed,
            onRetry: context.read<SessionTranscriptCubit>().load,
          ),
          SessionTranscriptStatus.bridgeUpdateRequired => _TranscriptMessage(
            text: AppLocalizations.of(context).transcriptBridgeUpdate,
          ),
          SessionTranscriptStatus.loaded => _TranscriptList(
            state: state,
            httpBaseUrl: httpBaseUrl,
            isCodex: isCodex,
            liteMode: liteMode,
          ),
        },
      ),
    );
  }
}

class _TranscriptList extends StatelessWidget {
  const _TranscriptList({
    required this.state,
    required this.httpBaseUrl,
    required this.isCodex,
    required this.liteMode,
  });

  final SessionTranscriptState state;
  final String? httpBaseUrl;
  final bool isCodex;
  final bool liteMode;

  @override
  Widget build(BuildContext context) {
    final entries = liteMode ? liteModeEntries(state.entries) : state.entries;
    if (entries.isEmpty && !state.hasOlder) {
      return _TranscriptMessage(
        text: AppLocalizations.of(context).transcriptEmpty,
      );
    }
    final headerCount = state.hasOlder ? 1 : 0;
    final count = entries.length + headerCount;
    // Reversed so the page opens at its newest message: the compaction
    // boundary the user came from.
    return ListView.builder(
      key: const ValueKey('session_transcript_list'),
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: count,
      itemBuilder: (context, index) {
        final entryIndex = count - 1 - index - headerCount;
        if (entryIndex < 0) return _LoadOlderButton(state: state);
        return ChatEntryWidget(
          entry: entries[entryIndex],
          previous: entryIndex > 0 ? entries[entryIndex - 1] : null,
          httpBaseUrl: httpBaseUrl,
          isCodex: isCodex,
        );
      },
    );
  }
}

class _LoadOlderButton extends StatelessWidget {
  const _LoadOlderButton({required this.state});

  final SessionTranscriptState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: state.loadingOlder
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton.icon(
                key: const ValueKey('transcript_load_older_button'),
                onPressed: context.read<SessionTranscriptCubit>().loadOlder,
                icon: Icon(
                  state.olderFailed ? Icons.refresh : Icons.expand_less,
                ),
                label: Text(
                  state.olderFailed
                      ? l.transcriptLoadFailed
                      : l.transcriptLoadOlder,
                ),
              ),
      ),
    );
  }
}

class _TranscriptMessage extends StatelessWidget {
  const _TranscriptMessage({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (onRetry case final retry?) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('transcript_retry_button'),
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
