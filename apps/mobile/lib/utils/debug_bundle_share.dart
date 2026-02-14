import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';

Future<void> copyDebugBundleForAgent(
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
    final text = buildAgentInvestigationPrompt(bundle);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Agent prompt copied. Paste it into your AI chat.'),
      ),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Failed to build debug bundle')),
    );
  } finally {
    await sub.cancel();
  }
}

@Deprecated('Use copyDebugBundleForAgent instead.')
Future<void> shareDebugBundle(
  BuildContext context,
  String sessionId, {
  int traceLimit = 400,
  bool includeDiff = true,
  Duration timeout = const Duration(seconds: 5),
}) {
  return copyDebugBundleForAgent(
    context,
    sessionId,
    traceLimit: traceLimit,
    includeDiff: includeDiff,
    timeout: timeout,
  );
}

String buildAgentInvestigationPrompt(DebugBundleMessage bundle) {
  final recipe = bundle.reproRecipe;
  final agentPrompt = bundle.agentPrompt.isNotEmpty
      ? bundle.agentPrompt
      : _defaultAgentPrompt(bundle);
  final files = _extractChangedFiles(bundle.diff);
  final maxFiles = 20;
  final shownFiles = files.take(maxFiles).toList();
  final moreFiles = files.length - shownFiles.length;
  final savedBundlePath = (bundle.savedBundlePath ?? '').trim();
  final traceFilePath = (bundle.traceFilePath ?? '').trim();

  final lines = <String>[
    'ccpocket agent investigation prompt',
    'generatedAt: ${bundle.generatedAt}',
    'sessionId: ${bundle.sessionId}',
    'provider: ${bundle.session.provider}',
    'projectPath: ${bundle.session.projectPath}',
    if ((bundle.session.worktreePath ?? '').isNotEmpty)
      'worktreePath: ${bundle.session.worktreePath}',
    if ((bundle.session.worktreeBranch ?? '').isNotEmpty)
      'worktreeBranch: ${bundle.session.worktreeBranch}',
    if (savedBundlePath.isNotEmpty) 'bundlePath: $savedBundlePath',
    if (traceFilePath.isNotEmpty) 'tracePath: $traceFilePath',
    '',
  ];

  lines.add('investigation_request:');
  lines.add(
    'Please investigate this chat issue on the remote machine using the files above.',
  );
  var step = 1;
  if (savedBundlePath.isNotEmpty) {
    lines.add(
      '$step. Open bundlePath and inspect historySummary/debugTrace/reproRecipe.',
    );
    step += 1;
  }
  if (traceFilePath.isNotEmpty) {
    lines.add('$step. Open tracePath and inspect timeline around the failure.');
    step += 1;
  }
  if (shownFiles.isNotEmpty) {
    lines.add('$step. Inspect these changed files if related:');
    for (final path in shownFiles) {
      lines.add('- $path');
    }
    if (moreFiles > 0) {
      lines.add('...and $moreFiles more changed files');
    }
  }
  lines.add('');
  lines.add('expected_output:');
  lines.add('- root-cause hypotheses (ranked)');
  lines.add('- concrete verification steps');
  lines.add('- minimal fix proposal');
  lines.add('');
  lines.add('agent_prompt:');
  lines.add(agentPrompt);
  lines.add('');

  if (recipe.startBridgeCommand.isNotEmpty ||
      recipe.wsUrlHint.isNotEmpty ||
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

  if (savedBundlePath.isEmpty && traceFilePath.isEmpty) {
    lines.add('fallback_bundle_json:');
    lines.add(
      const JsonEncoder.withIndent(
        '  ',
      ).convert(_buildDebugBundlePayload(bundle)),
    );
  }

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

List<String> _extractChangedFiles(String diffText) {
  if (diffText.isEmpty) return const [];

  final files = <String>{};
  for (final line in const LineSplitter().convert(diffText)) {
    if (!line.startsWith('diff --git a/')) {
      continue;
    }
    final parts = line.split(' ');
    if (parts.length < 4) {
      continue;
    }
    var file = parts[2];
    if (file.startsWith('a/')) {
      file = file.substring(2);
    }
    if (file.isNotEmpty) {
      files.add(file);
    }
  }
  return files.toList(growable: false);
}
