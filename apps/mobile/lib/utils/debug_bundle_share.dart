import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';

Future<void> shareDebugBundle(
  BuildContext context,
  String sessionId, {
  int traceLimit = 400,
  bool includeDiff = true,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final bridge = context.read<BridgeService>();
  final messenger = ScaffoldMessenger.of(context);
  final completer = Completer<DebugBundleMessage>();

  late final StreamSubscription<DebugBundleMessage> sub;
  sub = bridge.debugBundles.listen((bundle) {
    if (bundle.sessionId == sessionId && !completer.isCompleted) {
      completer.complete(bundle);
    }
  });

  bridge.requestDebugBundle(
    sessionId,
    traceLimit: traceLimit,
    includeDiff: includeDiff,
  );

  try {
    final bundle = await completer.future.timeout(timeout);
    final text = buildDebugBundleShareText(bundle);
    await SharePlus.instance.share(ShareParams(text: text));
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Failed to build debug bundle')),
    );
  } finally {
    await sub.cancel();
  }
}

String buildDebugBundleShareText(DebugBundleMessage bundle) {
  final map = _buildDebugBundlePayload(bundle);
  final jsonText = const JsonEncoder.withIndent('  ').convert(map);
  final recipe = bundle.reproRecipe;
  final agentPrompt = bundle.agentPrompt.isNotEmpty
      ? bundle.agentPrompt
      : _defaultAgentPrompt(bundle);
  final lines = <String>[
    'ccpocket debug bundle',
    'generatedAt: ${bundle.generatedAt}',
    'sessionId: ${bundle.sessionId}',
    '',
    'agent_prompt:',
    agentPrompt,
    '',
  ];

  if (recipe.wsUrlHint.isNotEmpty ||
      recipe.startBridgeCommand.isNotEmpty ||
      recipe.notes.isNotEmpty) {
    lines.add('repro_hints:');
    if (recipe.startBridgeCommand.isNotEmpty) {
      lines.add('start_bridge: ${recipe.startBridgeCommand}');
    }
    if (recipe.wsUrlHint.isNotEmpty) {
      lines.add('ws_url: ${recipe.wsUrlHint}');
    }
    for (final note in recipe.notes) {
      lines.add('- $note');
    }
    lines.add('');
  }

  lines.add('bundle_json:');
  lines.add(jsonText);
  return lines.join('\n');
}

Map<String, dynamic> _buildDebugBundlePayload(DebugBundleMessage bundle) {
  const maxDiffLength = 20000;
  final diffTruncated = bundle.diff.length > maxDiffLength;
  final diff = diffTruncated
      ? '${bundle.diff.substring(0, maxDiffLength)}\n...[diff truncated]'
      : bundle.diff;
  return <String, dynamic>{
    'type': 'ccpocket_debug_bundle',
    'generatedAt': bundle.generatedAt,
    'sessionId': bundle.sessionId,
    'session': <String, dynamic>{
      'id': bundle.session.id,
      'provider': bundle.session.provider,
      'status': bundle.session.status,
      'projectPath': bundle.session.projectPath,
      'worktreePath': bundle.session.worktreePath,
      'worktreeBranch': bundle.session.worktreeBranch,
      'claudeSessionId': bundle.session.claudeSessionId,
      'createdAt': bundle.session.createdAt,
      'lastActivityAt': bundle.session.lastActivityAt,
    },
    'pastMessageCount': bundle.pastMessageCount,
    'historySummary': bundle.historySummary,
    'debugTrace': bundle.debugTrace
        .map(
          (e) => <String, dynamic>{
            'ts': e.ts,
            'sessionId': e.sessionId,
            'direction': e.direction,
            'channel': e.channel,
            'type': e.type,
            'detail': e.detail,
          },
        )
        .toList(),
    'traceFilePath': bundle.traceFilePath,
    'savedBundlePath': bundle.savedBundlePath,
    'reproRecipe': <String, dynamic>{
      'wsUrlHint': bundle.reproRecipe.wsUrlHint,
      'startBridgeCommand': bundle.reproRecipe.startBridgeCommand,
      'resumeSessionMessage': bundle.reproRecipe.resumeSessionMessage,
      'getHistoryMessage': bundle.reproRecipe.getHistoryMessage,
      'getDebugBundleMessage': bundle.reproRecipe.getDebugBundleMessage,
      'notes': bundle.reproRecipe.notes,
    },
    'agentPrompt': bundle.agentPrompt,
    'diff': diff,
    'diffError': bundle.diffError,
    'diffTruncated': diffTruncated,
  };
}

String _defaultAgentPrompt(DebugBundleMessage bundle) {
  return [
    'Investigate this ccpocket chat bug from debugTrace/historySummary/diff.',
    'Return root-cause hypotheses and concrete verification steps.',
    'Session provider: ${bundle.session.provider}',
  ].join('\n');
}
