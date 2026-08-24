import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';
import '../theme/app_theme.dart';

/// Compact, active-only status shown above the chat composer.
class ComposerActivityIndicator extends StatefulWidget {
  final ProcessStatus status;
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final DateTime Function()? now;

  const ComposerActivityIndicator({
    super.key,
    required this.status,
    this.startedAt,
    this.lastActivityAt,
    this.now,
  });

  @override
  State<ComposerActivityIndicator> createState() =>
      _ComposerActivityIndicatorState();
}

class _ComposerActivityIndicatorState extends State<ComposerActivityIndicator> {
  Timer? _timer;
  DateTime? _fallbackStartedAt;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ComposerActivityIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasActive = _isActive(oldWidget.status);
    final isActive = _isActive(widget.status);
    if (wasActive != isActive) _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_isActive(widget.status)) {
      _fallbackStartedAt = null;
      return;
    }
    _fallbackStartedAt ??= _now;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isActive(widget.status)) return const SizedBox.shrink();

    final appColors = Theme.of(context).extension<AppColors>();
    final color = switch (widget.status) {
      ProcessStatus.starting =>
        appColors?.statusStarting ?? Theme.of(context).colorScheme.primary,
      ProcessStatus.compacting =>
        appColors?.statusCompacting ?? Theme.of(context).colorScheme.primary,
      _ => appColors?.statusRunning ?? Theme.of(context).colorScheme.primary,
    };
    final now = _now;
    final elapsed = now.difference(
      widget.startedAt ?? _fallbackStartedAt ?? now,
    );
    final elapsedLabel = _formatElapsed(elapsed);
    final lastActivityAt = widget.lastActivityAt;
    final quietDuration = lastActivityAt == null
        ? Duration.zero
        : now.difference(lastActivityAt);
    final showLastActivity = quietDuration.inMinutes >= 1;
    final workingLabel = _withoutTrailingEllipsis(
      AppLocalizations.of(context).working,
    );
    final lastActivityLabel = showLastActivity
        ? AppLocalizations.of(context).minutesAgo(quietDuration.inMinutes)
        : null;

    return Semantics(
      key: const ValueKey('composer_activity_indicator'),
      container: true,
      excludeSemantics: true,
      label: [workingLabel, elapsedLabel, ?lastActivityLabel].join(', '),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color,
                backgroundColor: color.withValues(alpha: 0.16),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              workingLabel,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' · $elapsedLabel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (lastActivityLabel != null) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.history_rounded,
                size: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                lastActivityLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime get _now => widget.now?.call() ?? DateTime.now();
}

bool _isActive(ProcessStatus status) =>
    status == ProcessStatus.starting ||
    status == ProcessStatus.running ||
    status == ProcessStatus.compacting;

String _withoutTrailingEllipsis(String value) =>
    value.endsWith('...') ? value.substring(0, value.length - 3) : value;

String _formatElapsed(Duration elapsed) {
  final seconds = elapsed.inSeconds.clamp(0, 359999);
  if (seconds < 60) return '${seconds}s';
  final minutes = seconds ~/ 60;
  final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
  if (minutes < 60) return '$minutes:$remainingSeconds';
  final hours = minutes ~/ 60;
  final remainingMinutes = (minutes % 60).toString().padLeft(2, '0');
  return '$hours:$remainingMinutes:$remainingSeconds';
}
