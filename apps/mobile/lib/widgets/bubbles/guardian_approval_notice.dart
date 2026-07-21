import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../theme/app_theme.dart';

/// A quiet activity notice for medium/high-risk actions approved by Codex.
///
/// This deliberately avoids the warning/error palette so actual warnings keep
/// their visual priority. Details stay collapsed until the user asks for them.
class GuardianApprovalNotice extends StatefulWidget {
  final GuardianApprovalMessage message;
  const GuardianApprovalNotice({super.key, required this.message});

  @override
  State<GuardianApprovalNotice> createState() => _GuardianApprovalNoticeState();
}

class _GuardianApprovalNoticeState extends State<GuardianApprovalNotice> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final riskLabel = switch (widget.message.risk) {
      GuardianApprovalRisk.medium => l.guardianApprovalMediumRisk,
      GuardianApprovalRisk.high => l.guardianApprovalHighRisk,
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Semantics(
            button: true,
            label: '${l.guardianApprovalTitle}, $riskLabel',
            hint: _expanded
                ? l.guardianApprovalHideDetails
                : l.guardianApprovalDetails,
            child: Material(
              color: appColors.systemChip.withValues(alpha: 0.62),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('guardian_approval_details_button'),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GuardianApprovalHeader(
                        riskLabel: riskLabel,
                        expanded: _expanded,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        child: _expanded
                            ? _GuardianApprovalDetails(message: widget.message)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuardianApprovalHeader extends StatelessWidget {
  final String riskLabel;
  final bool expanded;
  const _GuardianApprovalHeader({
    required this.riskLabel,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: appColors.subtleText,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 16, color: appColors.subtleText),
        const SizedBox(width: 7),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              Text(l.guardianApprovalTitle, style: textStyle),
              Text('· $riskLabel', style: textStyle),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          expanded ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: appColors.subtleText,
        ),
      ],
    );
  }
}

class _GuardianApprovalDetails extends StatelessWidget {
  final GuardianApprovalMessage message;
  const _GuardianApprovalDetails({required this.message});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final authorization = message.authorization?.trim();
    final detailStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: appColors.subtleText, height: 1.4);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 8),
          Text(message.reason, style: detailStyle),
          if (authorization != null && authorization.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.guardianApprovalAuthorization(authorization),
              style: detailStyle?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
