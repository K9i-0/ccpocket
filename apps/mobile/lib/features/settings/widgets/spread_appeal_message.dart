import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/in_app_review_service.dart';
import '../../../services/support_banner_service.dart';

class SpreadAppealMessage extends StatefulWidget {
  const SpreadAppealMessage({super.key});

  @override
  State<SpreadAppealMessage> createState() => _SpreadAppealMessageState();
}

class _SpreadAppealMessageState extends State<SpreadAppealMessage> {
  Future<InAppReviewEligibility>? _eligibilityFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_eligibilityFuture != null) return;
    final reviewService = context.read<InAppReviewService?>();
    _eligibilityFuture = reviewService?.getSupportBannerEligibility();
  }

  @override
  Widget build(BuildContext context) {
    final supportBannerService = context.watch<SupportBannerService?>();
    if (supportBannerService?.shouldForceShowInDebug ?? false) {
      return const _SpreadAppealMessageContent();
    }

    final eligibilityFuture = _eligibilityFuture;
    if (eligibilityFuture == null) return const SizedBox.shrink();

    return FutureBuilder<InAppReviewEligibility>(
      future: eligibilityFuture,
      builder: (context, snapshot) {
        if (!(snapshot.data?.isEligible ?? false)) {
          return const SizedBox.shrink();
        }

        return const _SpreadAppealMessageContent();
      },
    );
  }
}

class _SpreadAppealMessageContent extends StatelessWidget {
  const _SpreadAppealMessageContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          key: const ValueKey('spread_appeal_message'),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.campaign_outlined, color: cs.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l.spreadAppealMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),
      ],
    );
  }
}
