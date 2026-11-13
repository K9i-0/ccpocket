import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../utils/command_parser.dart';
import '../adaptive_context_menu.dart';

enum _UserMessageAction { rewind, restoreFiles }

class UserBubble extends StatefulWidget {
  final String text;
  final MessageStatus status;
  final VoidCallback? onRetry;

  /// Legacy rewind (Bridges without in-place edit).
  final VoidCallback? onRewind;

  /// Edit and resend this message (Codex App style). Null hides the pencil.
  final ValueChanged<String>? onEdit;

  /// Claude only: restore files to this message's checkpoint.
  final VoidCallback? onRestoreFiles;
  final List<String> imageUrls;
  final String? httpBaseUrl;
  final List<Uint8List> imageBytesList;

  /// Number of images attached (from history restoration when actual data is unavailable).
  final int imageCount;

  const UserBubble({
    super.key,
    required this.text,
    this.status = MessageStatus.sent,
    this.onRetry,
    this.onRewind,
    this.onEdit,
    this.onRestoreFiles,
    this.imageUrls = const [],
    this.httpBaseUrl,
    this.imageBytesList = const [],
    this.imageCount = 0,
  });

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  bool _editing = false;
  TextEditingController? _editController;

  @override
  void didUpdateWidget(covariant UserBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Editing ends when it is no longer allowed (e.g. a turn started).
    if (_editing && widget.onEdit == null) _stopEditing();
  }

  @override
  void dispose() {
    _editController?.dispose();
    super.dispose();
  }

  void _startEditing() {
    _editController?.dispose();
    _editController = TextEditingController(text: widget.text);
    setState(() => _editing = true);
  }

  void _stopEditing() {
    setState(() => _editing = false);
  }

  void _submitEdit() {
    final text = _editController?.text.trim() ?? '';
    if (text.isEmpty) return;
    _stopEditing();
    widget.onEdit?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing && _editController != null) {
      return _EditingBubble(
        controller: _editController!,
        onCancel: _stopEditing,
        onSend: _submitEdit,
      );
    }
    final onEdit = widget.onEdit == null ? null : _startEditing;
    // Detect command message with XML tags
    final parsed = parseCommandMessage(widget.text);
    return _UserMessageActionsScope(
      builder: (actionsButtonKey) {
        if (parsed != null) {
          return _CommandBubble(
            command: parsed,
            status: widget.status,
            onRetry: widget.onRetry,
            onRewind: widget.onRewind,
            onRestoreFiles: widget.onRestoreFiles,
            onEdit: null,
            onCopy: _copyText,
            actionsButtonKey: actionsButtonKey,
            onShowContextMenu: (position) =>
                _showContextMenu(context, position: position, onEdit: null),
          );
        }

        return _StandardBubble(
          displayText: widget.text,
          status: widget.status,
          onRetry: widget.onRetry,
          onRewind: widget.onRewind,
          onRestoreFiles: widget.onRestoreFiles,
          onEdit: onEdit,
          imageBytesList: widget.imageBytesList,
          imageUrls: widget.imageUrls,
          httpBaseUrl: widget.httpBaseUrl,
          onCopy: _copyText,
          actionsButtonKey: actionsButtonKey,
          onShowContextMenu: (position) =>
              _showContextMenu(context, position: position, onEdit: onEdit),
        );
      },
    );
  }

  void _showContextMenu(
    BuildContext context, {
    Offset? position,
    VoidCallback? onEdit,
  }) async {
    final l = AppLocalizations.of(context);
    final action = await showAdaptiveActionMenu<String>(
      context: context,
      position: position,
      items: [
        AdaptiveActionMenuItem(
          value: 'copy',
          icon: Icons.copy,
          label: l.copyEntireMessage,
        ),
        if (onEdit != null)
          AdaptiveActionMenuItem(
            value: 'edit',
            icon: Icons.edit_outlined,
            label: l.editMessage,
          ),
        if (widget.onRewind != null)
          AdaptiveActionMenuItem(
            value: 'rewind',
            icon: Icons.history,
            label: l.rewindToHere,
          ),
        if (widget.onRestoreFiles != null)
          AdaptiveActionMenuItem(
            value: 'restoreFiles',
            icon: Icons.restore_page_outlined,
            label: l.restoreFilesToHere,
          ),
      ],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case 'copy':
        _copyText();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.copied),
            duration: const Duration(seconds: 1),
          ),
        );
      case 'edit':
        onEdit?.call();
      case 'rewind':
        widget.onRewind?.call();
      case 'restoreFiles':
        widget.onRestoreFiles?.call();
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.text));
  }
}

/// Inline editor shown in place of the bubble while editing (Codex App).
class _EditingBubble extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _EditingBubble({
    required this.controller,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Container(
      key: const ValueKey('user_message_editor'),
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.bubbleMarginV,
        horizontal: AppSpacing.bubbleMarginH,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('user_message_edit_field'),
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration.collapsed(hintText: l.editMessage),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  key: const ValueKey('user_message_edit_cancel'),
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l.cancel),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  key: const ValueKey('user_message_edit_send'),
                  onPressed: value.text.trim().isEmpty ? null : onSend,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(l.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMessageActionsScope extends StatefulWidget {
  final Widget Function(
    GlobalKey<_UserMessageActionsButtonState> actionsButtonKey,
  )
  builder;

  const _UserMessageActionsScope({required this.builder});

  @override
  State<_UserMessageActionsScope> createState() =>
      _UserMessageActionsScopeState();
}

class _UserMessageActionsScopeState extends State<_UserMessageActionsScope> {
  final actionsButtonKey = GlobalKey<_UserMessageActionsButtonState>();

  @override
  Widget build(BuildContext context) => widget.builder(actionsButtonKey);
}

/// Standard user message bubble.
class _StandardBubble extends StatelessWidget {
  final String displayText;
  final MessageStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final VoidCallback? onRestoreFiles;
  final VoidCallback? onEdit;
  final List<Uint8List> imageBytesList;
  final List<String> imageUrls;
  final String? httpBaseUrl;
  final VoidCallback onCopy;
  final GlobalKey<_UserMessageActionsButtonState> actionsButtonKey;
  final ValueChanged<Offset?> onShowContextMenu;

  const _StandardBubble({
    required this.displayText,
    required this.status,
    required this.onRetry,
    required this.onRewind,
    required this.onRestoreFiles,
    required this.onEdit,
    required this.imageBytesList,
    required this.imageUrls,
    required this.httpBaseUrl,
    required this.onCopy,
    required this.actionsButtonKey,
    required this.onShowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Align(
      alignment: Alignment.centerRight,
      child: AdaptiveContextMenuRegion(
        onOpen: onShowContextMenu,
        enableLongPress: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MessageRetryTapRegion(
              onRetry: status == MessageStatus.failed ? onRetry : null,
              isExcluded: (position) =>
                  actionsButtonKey.currentState?.containsExpandedTapTarget(
                    position,
                  ) ??
                  false,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubbleMarginV,
                  horizontal: AppSpacing.bubbleMarginH,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubblePaddingV,
                  horizontal: AppSpacing.bubblePaddingH,
                ),
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width *
                      AppSpacing.maxBubbleWidthFraction,
                ),
                decoration: BoxDecoration(
                  color: appColors.userBubble,
                  borderRadius: AppSpacing.userBubbleBorderRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (imageBytesList.isNotEmpty ||
                        (imageUrls.isNotEmpty && httpBaseUrl != null))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (final bytes in imageBytesList)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  bytes,
                                  width: imageBytesList.length == 1 ? 200 : 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: imageBytesList.length == 1
                                            ? 200
                                            : 120,
                                        height: 80,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image),
                                      ),
                                ),
                              ),
                            if (imageBytesList.isEmpty)
                              for (final url in imageUrls)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    '$httpBaseUrl$url',
                                    width: imageUrls.length == 1 ? 200 : 120,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: imageUrls.length == 1
                                                  ? 200
                                                  : 120,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.broken_image,
                                              ),
                                            ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    if (displayText.isNotEmpty)
                      SelectionArea(
                        child: Text(
                          displayText,
                          style: TextStyle(color: appColors.userBubbleText),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            _UserMessageFooter(
              status: status,
              onCopy: onCopy,
              onEdit: onEdit,
              onRewind: onRewind,
              onRestoreFiles: onRestoreFiles,
              actionsButtonKey: actionsButtonKey,
            ),
          ],
        ),
      ),
    );
  }
}

/// CLI-style command bubble: "/command-name args" in a single bubble.
class _CommandBubble extends StatelessWidget {
  final ParsedCommand command;
  final MessageStatus status;
  final VoidCallback? onRetry;
  final VoidCallback? onRewind;
  final VoidCallback? onRestoreFiles;
  final VoidCallback? onEdit;
  final VoidCallback onCopy;
  final GlobalKey<_UserMessageActionsButtonState> actionsButtonKey;
  final ValueChanged<Offset?> onShowContextMenu;

  const _CommandBubble({
    required this.command,
    required this.status,
    required this.onRetry,
    required this.onRewind,
    required this.onRestoreFiles,
    required this.onEdit,
    required this.onCopy,
    required this.actionsButtonKey,
    required this.onShowContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasArgs = command.args != null && command.args!.isNotEmpty;

    return Align(
      alignment: Alignment.centerRight,
      child: AdaptiveContextMenuRegion(
        onOpen: onShowContextMenu,
        enableLongPress: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _MessageRetryTapRegion(
              onRetry: status == MessageStatus.failed ? onRetry : null,
              isExcluded: (position) =>
                  actionsButtonKey.currentState?.containsExpandedTapTarget(
                    position,
                  ) ??
                  false,
              child: Container(
                margin: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubbleMarginV,
                  horizontal: AppSpacing.bubbleMarginH,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.bubblePaddingV,
                  horizontal: AppSpacing.bubblePaddingH,
                ),
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width *
                      AppSpacing.maxBubbleWidthFraction,
                ),
                decoration: BoxDecoration(
                  color: appColors.userBubble,
                  borderRadius: AppSpacing.userBubbleBorderRadius,
                ),
                child: SelectionArea(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: command.commandName,
                          style: TextStyle(
                            color: appColors.userBubbleText,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (hasArgs) ...[
                          TextSpan(
                            text: ' ${command.args}',
                            style: TextStyle(color: appColors.userBubbleText),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _UserMessageFooter(
              status: status,
              onCopy: onCopy,
              onEdit: onEdit,
              onRewind: onRewind,
              onRestoreFiles: onRestoreFiles,
              actionsButtonKey: actionsButtonKey,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRetryTapRegion extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRetry;
  final bool Function(Offset position) isExcluded;

  const _MessageRetryTapRegion({
    required this.child,
    required this.onRetry,
    required this.isExcluded,
  });

  @override
  State<_MessageRetryTapRegion> createState() => _MessageRetryTapRegionState();
}

class _MessageRetryTapRegionState extends State<_MessageRetryTapRegion> {
  int? _pointer;
  Offset? _downPosition;
  Duration? _downTimeStamp;
  bool _downWasExcluded = false;

  void _clearPointer() {
    _pointer = null;
    _downPosition = null;
    _downTimeStamp = null;
    _downWasExcluded = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onRetry == null
          ? null
          : (event) {
              if ((event.buttons & kPrimaryButton) == 0) return;
              _pointer = event.pointer;
              _downPosition = event.position;
              _downTimeStamp = event.timeStamp;
              _downWasExcluded = widget.isExcluded(event.position);
            },
      onPointerCancel: widget.onRetry == null
          ? null
          : (event) {
              if (_pointer == event.pointer) _clearPointer();
            },
      onPointerUp: widget.onRetry == null
          ? null
          : (event) {
              if (_pointer != event.pointer) return;
              final downPosition = _downPosition;
              final downTimeStamp = _downTimeStamp;
              final downWasExcluded = _downWasExcluded;
              _clearPointer();
              if (downPosition == null || downTimeStamp == null) return;
              if ((event.position - downPosition).distance > kTouchSlop) return;
              if (event.timeStamp - downTimeStamp >= kLongPressTimeout) return;
              if (downWasExcluded || widget.isExcluded(event.position)) return;
              widget.onRetry?.call();
            },
      child: widget.child,
    );
  }
}

class _UserMessageFooter extends StatelessWidget {
  final MessageStatus status;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onRewind;
  final VoidCallback? onRestoreFiles;
  final GlobalKey<_UserMessageActionsButtonState> actionsButtonKey;

  const _UserMessageFooter({
    required this.status,
    required this.onCopy,
    required this.onEdit,
    required this.onRewind,
    required this.onRestoreFiles,
    required this.actionsButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.bubbleMarginH),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CopyMessageButton(onCopy: onCopy),
          if (onEdit != null)
            _FooterIconButton(
              key: const ValueKey('user_message_edit_button'),
              icon: Icons.edit_outlined,
              tooltip: l.editMessage,
              onPressed: onEdit!,
            ),
          if (onRewind != null || onRestoreFiles != null)
            _UserMessageActionsButton(
              key: actionsButtonKey,
              onRewind: onRewind,
              onRestoreFiles: onRestoreFiles,
            ),
          const SizedBox(width: 2),
          _StatusIndicator(status: status),
        ],
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _FooterIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 14, color: appColors.subtleText),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(30, 18),
        maximumSize: const Size(30, 18),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Copy button that briefly turns into a check mark (Codex App).
class _CopyMessageButton extends StatefulWidget {
  final VoidCallback onCopy;

  const _CopyMessageButton({required this.onCopy});

  @override
  State<_CopyMessageButton> createState() => _CopyMessageButtonState();
}

class _CopyMessageButtonState extends State<_CopyMessageButton> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    widget.onCopy();
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _FooterIconButton(
      key: const ValueKey('user_message_copy_button'),
      icon: _copied ? Icons.check : Icons.copy_outlined,
      tooltip: _copied ? l.copied : l.copyMessage,
      onPressed: _copy,
    );
  }
}

class _UserMessageActionsButton extends StatefulWidget {
  final VoidCallback? onRewind;
  final VoidCallback? onRestoreFiles;

  const _UserMessageActionsButton({
    super.key,
    this.onRewind,
    this.onRestoreFiles,
  });

  @override
  State<_UserMessageActionsButton> createState() =>
      _UserMessageActionsButtonState();
}

class _UserMessageActionsButtonState extends State<_UserMessageActionsButton> {
  static const _minimumTapTargetSize = 44.0;

  final _buttonKey = GlobalKey<PopupMenuButtonState<_UserMessageAction>>();
  Offset? _tapDownPosition;
  Duration? _tapDownTimeStamp;

  Rect? get _expandedTapTarget {
    final renderObject = _buttonKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final buttonRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return Rect.fromCenter(
      center: buttonRect.center,
      width: _minimumTapTargetSize,
      height: _minimumTapTargetSize,
    );
  }

  bool containsExpandedTapTarget(Offset globalPosition) =>
      _expandedTapTarget?.contains(globalPosition) ?? false;

  void _handleTapOutside(PointerDownEvent event) {
    if ((event.buttons & kPrimaryButton) == 0) return;
    if (_expandedTapTarget?.contains(event.position) ?? false) {
      _tapDownPosition = event.position;
      _tapDownTimeStamp = event.timeStamp;
    }
  }

  void _handleTapUpOutside(PointerUpEvent event) {
    final downPosition = _tapDownPosition;
    final downTimeStamp = _tapDownTimeStamp;
    _tapDownPosition = null;
    _tapDownTimeStamp = null;
    if (downPosition == null || downTimeStamp == null) return;
    if (!(_expandedTapTarget?.contains(event.position) ?? false)) return;
    if ((event.position - downPosition).distance > kTouchSlop) return;
    if (event.timeStamp - downTimeStamp >= kLongPressTimeout) return;
    _buttonKey.currentState?.showButtonMenu();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);

    return TapRegion(
      onTapOutside: _handleTapOutside,
      onTapUpOutside: _handleTapUpOutside,
      child: PopupMenuButton<_UserMessageAction>(
        key: _buttonKey,
        icon: Icon(
          Icons.more_horiz,
          key: const ValueKey('user_message_actions_button'),
          size: 14,
          color: appColors.subtleText,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size(24, 14),
          maximumSize: const Size(24, 14),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
        onSelected: (action) {
          switch (action) {
            case _UserMessageAction.rewind:
              widget.onRewind?.call();
            case _UserMessageAction.restoreFiles:
              widget.onRestoreFiles?.call();
          }
        },
        itemBuilder: (context) => [
          if (widget.onRestoreFiles != null)
            PopupMenuItem(
              value: _UserMessageAction.restoreFiles,
              child: _UserMessageActionRow(
                icon: Icons.restore_page_outlined,
                label: l.restoreFilesToHere,
              ),
            ),
          if (widget.onRewind != null)
            PopupMenuItem(
              value: _UserMessageAction.rewind,
              child: _UserMessageActionRow(
                icon: Icons.history,
                label: l.rewindToHere,
              ),
            ),
        ],
      ),
    );
  }
}

class _UserMessageActionRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _UserMessageActionRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final MessageStatus status;

  const _StatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;

    return switch (status) {
      MessageStatus.sending => SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: appColors.subtleText,
        ),
      ),
      MessageStatus.queued => Icon(
        Icons.schedule,
        size: 14,
        color: appColors.subtleText,
      ),
      MessageStatus.sent => Icon(
        Icons.check,
        size: 14,
        color: appColors.subtleText,
      ),
      MessageStatus.failed => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 14,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).tapToRetry,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    };
  }
}
