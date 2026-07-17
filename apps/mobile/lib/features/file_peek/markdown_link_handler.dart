import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/markdown_style.dart';
import 'file_path_syntax.dart';

enum MarkdownLinkTargetKind { external, file, unsupported }

@immutable
class MarkdownLinkTarget {
  final MarkdownLinkTargetKind kind;
  final String value;
  final Uri? uri;

  const MarkdownLinkTarget._(this.kind, this.value, this.uri);

  const MarkdownLinkTarget.file(String path)
    : this._(MarkdownLinkTargetKind.file, path, null);

  const MarkdownLinkTarget.external(Uri uri)
    : this._(MarkdownLinkTargetKind.external, '', uri);

  const MarkdownLinkTarget.unsupported(String value)
    : this._(MarkdownLinkTargetKind.unsupported, value, null);
}

final _windowsAbsolutePath = RegExp(r'^[A-Za-z]:[\\/]');
final _lineColumnSuffix = RegExp(r'(:\d+){1,2}$');

/// Classifies a markdown destination before deciding how the app opens it.
MarkdownLinkTarget classifyMarkdownLink(
  String href, {
  Set<String> knownPathSuffixes = const {},
}) {
  final raw = href.trim();
  if (raw.isEmpty) return const MarkdownLinkTarget.unsupported('');

  if (_windowsAbsolutePath.hasMatch(raw) || raw.startsWith(r'\\')) {
    return MarkdownLinkTarget.file(_stripLineColumn(raw));
  }

  final uri = Uri.tryParse(raw);
  if (uri == null) return MarkdownLinkTarget.unsupported(raw);

  if (uri.scheme == 'file') {
    try {
      return MarkdownLinkTarget.file(uri.toFilePath());
    } on UnsupportedError {
      return MarkdownLinkTarget.unsupported(raw);
    }
  }

  if (uri.hasScheme) return MarkdownLinkTarget.external(uri);

  if (uri.hasAuthority) {
    return MarkdownLinkTarget.external(Uri.parse('https:$raw'));
  }

  final path = _stripLineColumn(Uri.decodeComponent(uri.path));
  if (path.startsWith('/')) return MarkdownLinkTarget.file(path);

  if (_matchesKnownPath(path, knownPathSuffixes) || _looksLikeFilePath(path)) {
    return MarkdownLinkTarget.file(path);
  }

  return MarkdownLinkTarget.unsupported(raw);
}

MarkdownTapLinkCallback buildChatMarkdownLinkHandler(
  BuildContext context, {
  required FilePathTapCallback? onFileTap,
  Set<String> knownPathSuffixes = const {},
}) {
  return (text, href, title) {
    if (href == null) return;
    final target = classifyMarkdownLink(
      href,
      knownPathSuffixes: knownPathSuffixes,
    );
    unawaited(_openMarkdownTarget(context, target, onFileTap));
  };
}

Future<void> _openMarkdownTarget(
  BuildContext context,
  MarkdownLinkTarget target,
  FilePathTapCallback? onFileTap,
) async {
  switch (target.kind) {
    case MarkdownLinkTargetKind.file:
      if (onFileTap != null) {
        onFileTap(target.value);
        return;
      }
      if (context.mounted) {
        _showLinkError(context, target.value, fileUnavailable: true);
      }
      return;
    case MarkdownLinkTargetKind.external:
      final uri = target.uri!;
      final launched = await launchMarkdownUri(uri);
      if (!launched && context.mounted) {
        _showLinkError(context, uri.toString());
      }
      return;
    case MarkdownLinkTargetKind.unsupported:
      if (context.mounted) {
        _showLinkError(context, target.value, unsupported: true);
      }
      return;
  }
}

void _showLinkError(
  BuildContext context,
  String destination, {
  bool fileUnavailable = false,
  bool unsupported = false,
}) {
  final l10n = AppLocalizations.of(context);
  final message = unsupported
      ? l10n.markdownLinkUnsupported
      : fileUnavailable
      ? l10n.markdownFileUnavailable
      : l10n.markdownLinkOpenFailed;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: destination.isEmpty
            ? null
            : SnackBarAction(
                label: l10n.copy,
                onPressed: () {
                  unawaited(
                    Clipboard.setData(ClipboardData(text: destination)),
                  );
                },
              ),
      ),
    );
}

bool _matchesKnownPath(String path, Set<String> knownPathSuffixes) {
  if (knownPathSuffixes.contains(path)) return true;
  final normalized = path.replaceAll('\\', '/');
  return knownPathSuffixes.contains(normalized);
}

bool _looksLikeFilePath(String path) {
  if (path.isEmpty || !path.contains(RegExp(r'[/\\]'))) return false;
  final name = path.split(RegExp(r'[/\\]')).last;
  return name.contains('.') && !name.endsWith('.');
}

String _stripLineColumn(String path) {
  return path.replaceFirst(_lineColumnSuffix, '');
}
