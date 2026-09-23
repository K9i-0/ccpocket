import '../file_browser/open_file_browser.dart';
import '../../services/photo_library_service.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/bridge_service.dart';
import '../file_transfer/widgets/file_transfer_dialog.dart';
import '../../theme/app_theme.dart';
import '../../theme/code_text_style.dart';
import '../../theme/markdown_style.dart'
    show
        buildMarkdownStyle,
        colorCodeInlineSyntaxes,
        handleMarkdownLink,
        highlightToTextSpans,
        markdownBuilders;
import '../../utils/media_file_types.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/file_type_icon.dart';
import 'html_preview_document.dart';
import 'widgets/html_file_preview.dart';
import 'widgets/file_peek_media_preview.dart';
import 'widgets/file_peek_model_preview.dart';
import 'glb_preview_data.dart';
import 'widgets/finder_reveal_button.dart';

/// Resolves a potentially partial file path against the project's file list,
/// then shows the file peek sheet.
///
/// If the path matches exactly or resolves to a single candidate, opens
/// directly. If multiple candidates match, shows a picker first.
Future<void> openFilePeek(
  BuildContext context, {
  required BridgeService bridge,
  required String projectPath,
  required String filePath,
  required List<String> projectFiles,
  ValueChanged<String>? onResolvedFilePath,
}) async {
  final resolved = resolveFilePeekPaths(
    filePath,
    projectFiles,
    modifiedAt: bridge.fileModificationTimesForProject(projectPath),
  );

  switch (resolved.length) {
    case 1:
      // Single match — open directly.
      onResolvedFilePath?.call(resolved.first);
      return showFilePeekSheet(
        context,
        bridge: bridge,
        projectFiles: projectFiles,
        projectPath: projectPath,
        filePath: resolved.first,
      );
    case 0:
      // No match — try the original path as-is (Bridge may still find it).
      onResolvedFilePath?.call(filePath);
      return showFilePeekSheet(
        context,
        bridge: bridge,
        projectFiles: projectFiles,
        projectPath: projectPath,
        filePath: filePath,
      );
    default:
      // Multiple matches — let the user pick.
      final picked = await _showFilePickerSheet(context, filePath, resolved);
      if (picked != null && context.mounted) {
        onResolvedFilePath?.call(picked);
        return showFilePeekSheet(
          context,
          bridge: bridge,
          projectFiles: projectFiles,
          projectPath: projectPath,
          filePath: picked,
        );
      }
  }
}

/// Returns project file paths whose suffix matches [filePath].
List<String> resolveFilePeekPaths(
  String filePath,
  List<String> projectFiles, {
  Map<String, int> modifiedAt = const {},
}) {
  if (filePath.startsWith('/') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(filePath)) {
    return [filePath];
  }
  final lineSuffix =
      RegExp(r'(:\d+){1,2}$').firstMatch(filePath)?.group(0) ?? '';
  final normalized = filePath
      .substring(0, filePath.length - lineSuffix.length)
      .replaceFirst(RegExp(r'/$'), '');
  final paths = <String>{};
  for (final file in projectFiles) {
    final parts = file.split('/').where((p) => p.isNotEmpty).toList();
    for (var end = 1; end <= parts.length; end++) {
      paths.add(parts.take(end).join('/'));
    }
  }
  final filesOnly = paths;
  // Exact match first.
  if (filesOnly.contains(normalized)) return ['$normalized$lineSuffix'];

  // Suffix match: e.g. "lib/main.dart" matches "apps/mobile/lib/main.dart".
  final suffix = normalized.startsWith('/') ? normalized : '/$normalized';
  final candidates = filesOnly.where((f) => '/$f'.endsWith(suffix)).toList()
    ..sort((a, b) {
      final modifiedComparison = (modifiedAt[b] ?? 0).compareTo(
        modifiedAt[a] ?? 0,
      );
      return modifiedComparison != 0 ? modifiedComparison : a.compareTo(b);
    });

  return candidates.map((path) => '$path$lineSuffix').toList();
}

/// Bottom sheet that lists candidate file paths for the user to pick from.
Future<String?> _showFilePickerSheet(
  BuildContext context,
  String originalPath,
  List<String> candidates,
) {
  final appColors = Theme.of(context).extension<AppColors>()!;

  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appColors.subtleText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 18, color: appColors.subtleText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$originalPath — ${candidates.length} files found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appColors.subtleText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final path = candidates[index];
                final fileName = path.split('/').last;
                final dir = path.contains('/')
                    ? path.substring(0, path.lastIndexOf('/'))
                    : '';
                return ListTile(
                  leading: FileTypeIcon(path: path),
                  title: Text(fileName, style: const TextStyle(fontSize: 14)),
                  subtitle: dir.isNotEmpty
                      ? Text(
                          dir,
                          style: TextStyle(
                            fontSize: 12,
                            color: appColors.subtleText,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  dense: true,
                  onTap: () => Navigator.of(context).pop(path),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shows a bottom sheet that loads and displays file content from Bridge.
///
/// [projectPath] is the project root on the server.
/// [filePath] is the relative path within the project (e.g. "lib/main.dart").
Future<void> showFilePeekSheet(
  BuildContext context, {
  required BridgeService bridge,
  required String projectPath,
  required String filePath,
  VoidCallback? onOpened,
  List<String> projectFiles = const [],
}) {
  onOpened?.call();
  return showFileBrowser(
    context,
    bridge: bridge,
    projectPath: projectPath,
    target: filePath,
    initialFiles: projectFiles,
  );
}

class FilePeekContent extends StatefulWidget {
  final BridgeService bridge;
  final String projectPath;
  final String filePath;
  final ScrollController scrollController;
  final int? initialLine;

  const FilePeekContent({
    super.key,
    required this.bridge,
    required this.projectPath,
    required this.filePath,
    required this.scrollController,
    this.initialLine,
  });

  @override
  State<FilePeekContent> createState() => FilePeekContentState();
}

class FilePeekContentState extends State<FilePeekContent> {
  static int _nextConsumerId = 0;
  static const _responseFamily = 'file-content';

  FileContentMessage? _result;
  bool _loading = true;
  bool _showRaw = false;
  StreamSubscription<FileContentMessage>? _sub;
  StreamSubscription<ServerMessage>? _bridgeErrorSub;
  late final String _consumerId;
  late String _requestId;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _showRaw = widget.initialLine != null;
    _consumerId = 'file-peek-${++_nextConsumerId}';
    widget.bridge.registerProjectResponseConsumer(_responseFamily, _consumerId);
    _requestId = widget.bridge.createProjectRequestId('file-content');
    _sub = widget.bridge.fileContent.listen((msg) {
      final isScopedMatch =
          msg.projectPath == widget.projectPath && msg.requestId == _requestId;
      final isSafeLegacy =
          msg.requestId == null &&
          (msg.projectPath == null || msg.projectPath == widget.projectPath) &&
          widget.bridge.canAcceptLegacyProjectResponse(
            _responseFamily,
            _consumerId,
          );
      if (msg.filePath == widget.filePath && (isScopedMatch || isSafeLegacy)) {
        _timeout?.cancel();
        setState(() {
          _result = msg;
          _loading = false;
        });
        if (widget.initialLine case final line?) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !widget.scrollController.hasClients) return;
            final style = codeTextSettingsOf(context).style(height: 1.5);
            final height =
                MediaQuery.textScalerOf(context).scale(style.fontSize ?? 13) *
                1.5;
            widget.scrollController.jumpTo(
              ((line - 1) * height).clamp(
                0,
                widget.scrollController.position.maxScrollExtent,
              ),
            );
          });
        }
      }
    });
    _bridgeErrorSub = widget.bridge.messages.listen((msg) {
      if (msg
          case ErrorMessage(
            errorCode: 'unsupported_message',
            message: final action,
          )
          when action ==
              (isGlbPath(widget.filePath)
                  ? 'read_model_file'
                  : 'read_media_file')) {
        setState(() {
          _timeout?.cancel();
          _result = FileContentMessage(
            filePath: widget.filePath,
            content: '',
            error: 'bridge_update_required',
          );
          _loading = false;
        });
      }
    });
    _loadFile();
  }

  void _loadFile() {
    _timeout?.cancel();
    _requestId = widget.bridge.createProjectRequestId('file-content');
    setState(() {
      _loading = true;
      _result = null;
    });
    _timeout = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _result = FileContentMessage(
          filePath: widget.filePath,
          content: '',
          error: 'timeout',
        );
      });
    });
    final isMediaFile = mediaFileTypeForPath(widget.filePath) != null;
    widget.bridge.send(
      isGlbPath(widget.filePath)
          ? ClientMessage.readModelFile(
              widget.projectPath,
              widget.filePath,
              requestId: widget.bridge.projectRequestIdForWire(_requestId),
            )
          : isMediaFile
          ? ClientMessage.readMediaFile(
              widget.projectPath,
              widget.filePath,
              requestId: widget.bridge.projectRequestIdForWire(_requestId),
            )
          : ClientMessage.readFile(
              widget.projectPath,
              widget.filePath,
              requestId: widget.bridge.projectRequestIdForWire(_requestId),
            ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final raw = PageStorage.maybeOf(context)
        ?.readState(context, identifier: ('source', widget.filePath));
    if (raw is bool && widget.initialLine == null) _showRaw = raw;
  }

  void _toggleSource() {
    setState(() => _showRaw = !_showRaw);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _showRaw, identifier: ('source', widget.filePath));
  }

  @override
  void dispose() {
    _timeout?.cancel();
    widget.bridge.unregisterProjectResponseConsumer(
      _responseFamily,
      _consumerId,
    );
    _sub?.cancel();
    _bridgeErrorSub?.cancel();
    super.dispose();
  }

  void _copyPath() {
    Clipboard.setData(ClipboardData(text: '@${widget.filePath}'));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).copied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final fileName = widget.filePath.split('/').lastOrNull ?? widget.filePath;
    final isMarkdown = widget.filePath.endsWith('.md');
    final isHtml = isHtmlPreviewPath(widget.filePath);
    final isImage = _result?.kind == 'image';
    final isModel = isGlbPath(widget.filePath);
    final isMedia = _result?.kind == 'audio' || _result?.kind == 'video';
    final canPreviewHtml = isHtml && supportsEmbeddedHtmlPreview;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              FileTypeIcon(path: widget.filePath, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((isMarkdown || canPreviewHtml) &&
                  !isImage &&
                  !_loading &&
                  _result?.error == null)
                IconButton(
                  key: const ValueKey('file_peek_source_toggle_button'),
                  icon: Icon(
                    _showRaw ? Icons.preview_outlined : Icons.code,
                    size: 18,
                    color: _showRaw
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: _toggleSource,
                  tooltip: _showRaw
                      ? AppLocalizations.of(context).filePreviewShowPreview
                      : AppLocalizations.of(context).filePreviewShowSource,
                ),
              if (isMacOSPlatform)
                FinderRevealButton(
                  bridge: widget.bridge,
                  projectPath: widget.projectPath,
                  filePath: widget.filePath,
                ),
              PopupMenuButton<VoidCallback>(
                key: const ValueKey('file_peek_actions_button'),
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (action) => action(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const ValueKey('file_peek_copy_path_button'),
                    value: _copyPath,
                    child: Text(AppLocalizations.of(context).browserCopyPath),
                  ),
                  if (supportsProjectFileTransfer)
                    PopupMenuItem(
                      key: const ValueKey('file_peek_share_button'),
                      value: () => showProjectFileTransferDialog(
                        context,
                        bridge: widget.bridge,
                        projectPath: widget.projectPath,
                        filePath: widget.filePath,
                      ),
                      child: Text(
                        AppLocalizations.of(context).fileTransferShareOrSave,
                      ),
                    ),
                  if (PhotoLibraryService.supported &&
                      !_loading &&
                      _result?.error == null &&
                      (isImage && _result?.mimeType != 'image/svg+xml' ||
                          _result?.kind == 'video'))
                    PopupMenuItem(
                      key: const ValueKey('file_peek_save_to_photos_button'),
                      value: () => showProjectFileTransferDialog(
                        context,
                        bridge: widget.bridge,
                        projectPath: widget.projectPath,
                        filePath: widget.filePath,
                        saveToPhotos: true,
                      ),
                      child: Text(AppLocalizations.of(context).saveToPhotos),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Full path
        if (widget.filePath != fileName)
          Padding(
            padding: const EdgeInsets.only(left: 42, right: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.filePath,
                style: TextStyle(
                  fontSize: 11,
                  color: appColors.subtleText,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        if (_result != null && _result!.totalLines != null)
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 2, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_result!.totalLines} lines${_result!.truncated ? ' (truncated)' : ''}${_result!.language != null ? ' \u00b7 ${_result!.language}' : ''}',
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
              ),
            ),
          ),
        if (_result != null && (isImage || isMedia || isModel))
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 2, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (_result!.sizeBytes != null)
                    _formatFileSize(_result!.sizeBytes!),
                  if (_result!.mimeType != null) _result!.mimeType!,
                ].join(' · '),
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
              ),
            ),
          ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _result?.error != null
              ? FilePeekError(error: _result!.error!, onRetry: _loadFile)
              : _result?.kind == 'image'
              ? FilePeekImage(result: _result!)
              : isModel
              ? FilePeekModelPreview(
                  modelUrl: resolveFilePeekMediaUrl(
                    widget.bridge.httpBaseUrl,
                    _result?.mediaUrl,
                  ),
                )
              : isMedia
              ? FilePeekMediaPreview(
                  mediaUrl: resolveFilePeekMediaUrl(
                    widget.bridge.httpBaseUrl,
                    _result?.mediaUrl,
                  ),
                  isVideo: _result?.kind == 'video',
                  formatLabel: mediaFileExtensionForPath(widget.filePath)
                      ?.toUpperCase(),
                )
              : (canPreviewHtml && !_showRaw)
              ? HtmlFilePreview(html: _result!.content)
              : (isMarkdown && !_showRaw)
              ? FilePeekMarkdown(
                  content: _result!.content,
                  controller: widget.scrollController,
                )
              : FilePeekCode(
                  content: _result!.content,
                  language: _result!.language,
                  initialLine: widget.initialLine,
                  controller: widget.scrollController,
                ),
        ),
      ],
    );
  }
}

class FilePeekError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const FilePeekError({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: appColors.subtleText),
            const SizedBox(height: 12),
            Text(
              error == 'timeout'
                  ? AppLocalizations.of(context).browserTimeout
                  : error == 'bridge_update_required'
                  ? AppLocalizations.of(context)
                        .directoryBrowserBridgeUpdateRequired
                  : error == 'model_too_large'
                  ? AppLocalizations.of(context).filePreviewModelTooLarge
                  : error,
              style: TextStyle(color: appColors.subtleText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey('file_peek_retry_button'),
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).browserRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class FilePeekMarkdown extends StatelessWidget {
  final String content;
  final ScrollController controller;
  const FilePeekMarkdown({
    super.key,
    required this.content,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) {
    return Markdown(
      controller: controller,
      data: content,
      selectable: true,
      styleSheet: buildMarkdownStyle(context),
      onTapLink: handleMarkdownLink,
      inlineSyntaxes: colorCodeInlineSyntaxes,
      builders: markdownBuilders,
      padding: const EdgeInsets.all(16),
    );
  }
}

class FilePeekImage extends StatelessWidget {
  final FileContentMessage result;
  const FilePeekImage({super.key, required this.result});
  Uint8List? _imageBytes() {
    final base64 = result.base64;
    if (base64 == null || base64.isEmpty) return null;
    try {
      return base64Decode(base64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final bytes = _imageBytes();
    if (bytes == null) {
      return Center(
        child: Icon(Icons.broken_image, size: 40, color: appColors.subtleText),
      );
    }
    return _FilePeekImagePreview(
      bytes: bytes,
      isSvg: result.mimeType == 'image/svg+xml',
    );
  }
}

class FilePeekCode extends StatelessWidget {
  final String content;
  final String? language;
  final int? initialLine;
  final ScrollController controller;
  const FilePeekCode({
    super.key,
    required this.content,
    this.language,
    this.initialLine,
    required this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final lines = content.split('\n');
    final gutterWidth = '${lines.length}'.length;

    final baseStyle = codeTextSettingsOf(context)
        .style(height: 1.5, color: Theme.of(context).colorScheme.onSurface);

    final gutterStyle = baseStyle.copyWith(
      color: appColors.subtleText.withValues(alpha: 0.5),
    );

    // Get highlighted spans for each line.
    final highlightedLines = <List<InlineSpan>>[];
    final highlighted = highlightToTextSpans(
      context: context,
      source: content,
      baseStyle: baseStyle,
      language: language,
    );

    // Split highlighted spans into per-line lists.
    if (highlighted.length == 1 && highlighted.first.text == content) {
      // No highlighting — split plain text by line.
      for (final line in lines) {
        highlightedLines.add([TextSpan(text: line, style: baseStyle)]);
      }
    } else {
      highlightedLines.addAll(_splitSpansByLine(highlighted, lines.length));
    }

    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 0),
          child: SelectableText.rich(
            TextSpan(
              style: baseStyle,
              children: [
                for (var i = 0; i < highlightedLines.length; i++) ...[
                  TextSpan(
                    text: '${' ${i + 1}'.padLeft(gutterWidth + 1)}  ',
                    style: gutterStyle,
                  ),
                  TextSpan(
                    style: initialLine == i + 1
                        ? TextStyle(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          )
                        : null,
                    children: highlightedLines[i],
                  ),
                  const TextSpan(text: '\n'),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Splits a flat list of highlighted [TextSpan]s into per-line groups.
  List<List<InlineSpan>> _splitSpansByLine(
    List<TextSpan> spans,
    int lineCount,
  ) {
    final result = List.generate(lineCount, (_) => <InlineSpan>[]);
    var lineIndex = 0;

    void addText(String text, TextStyle? style) {
      final parts = text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0 && lineIndex < lineCount - 1) lineIndex++;
        if (parts[i].isNotEmpty && lineIndex < lineCount) {
          result[lineIndex].add(TextSpan(text: parts[i], style: style));
        }
      }
    }

    void walkSpan(TextSpan span) {
      if (span.text != null) {
        addText(span.text!, span.style);
      }
      if (span.children != null) {
        for (final child in span.children!) {
          if (child is TextSpan) walkSpan(child);
        }
      }
    }

    for (final span in spans) {
      walkSpan(span);
    }
    return result;
  }
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _FilePeekImagePreview extends StatelessWidget {
  final Uint8List bytes;
  final bool isSvg;

  const _FilePeekImagePreview({required this.bytes, required this.isSvg});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('file_peek_image_preview'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: isSvg
              ? SvgPicture.memory(bytes, fit: BoxFit.contain)
              : Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
        ),
      ),
    );
  }
}
