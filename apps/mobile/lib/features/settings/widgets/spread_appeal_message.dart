import 'package:material_ui/material_ui.dart';
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
    return Container(
      key: const ValueKey('spread_appeal_message'),
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.spreadAppealMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
