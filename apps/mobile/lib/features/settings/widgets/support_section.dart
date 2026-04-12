import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/revenuecat_service.dart';
import '../../../widgets/supporter_badge.dart';

final Uri _supporterDocUri = Uri.parse(
  'https://github.com/K9i-0/ccpocket/blob/main/docs/supporter.md',
);

class SupportSectionCard extends StatelessWidget {
  const SupportSectionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final revenueCat = context.read<RevenueCatService>();

    return ValueListenableBuilder<SupportCatalogState>(
      valueListenable: revenueCat.catalogState,
      builder: (context, state, _) {
        if (!state.isAvailable && state.errorMessage == null) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _SupportStatusTile(state: state),
              if (state.summary.hasActivity) ...[
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _SupportSummaryTile(state: state),
              ],
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              if (state.isLoading && !state.hasPackages)
                const _SupportLoadingTile()
              else if (state.hasPackages)
                ..._buildPackageTiles(context, state)
              else
                _SupportEmptyTile(
                  errorMessage: state.errorMessage,
                  onRetry: revenueCat.refresh,
                ),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const _SupportRestoreNoticeTile(),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const _SupportLearnMoreTile(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPackageTiles(
    BuildContext context,
    SupportCatalogState state,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < state.packages.length; i++) {
      final package = state.packages[i];
      widgets.add(_SupportPackageTile(package: package, state: state));
      if (i < state.packages.length - 1) {
        widgets.add(
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        );
      }
    }
    return widgets;
  }
}

class _SupportStatusTile extends StatelessWidget {
  const _SupportStatusTile({required this.state});

  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final revenueCat = context.read<RevenueCatService>();

    final subtitle = state.isSupporter
        ? l.supporterStatusActive
        : state.isLoading
        ? l.supporterStatusLoading
        : l.supporterStatusInactive;

    return ListTile(
      leading: Icon(Icons.favorite, color: cs.primary),
      title: Row(
        children: [
          Text(l.supporterTitle),
          if (state.isSupporter) ...[
            const SizedBox(width: 8),
            const SupporterBadge(),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: state.isBusy
            ? null
            : () async {
                final result = await revenueCat.restorePurchases();
                if (!context.mounted) return;
                _showResultSnackBar(context, result, isRestore: true);
              },
        child: state.isRestoring
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(l.supporterRestoreButton),
      ),
    );
  }
}

class _SupportLoadingTile extends StatelessWidget {
  const _SupportLoadingTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return ListTile(
      leading: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text(l.supporterStatusLoading),
    );
  }
}

class _SupportRestoreNoticeTile extends StatelessWidget {
  const _SupportRestoreNoticeTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.info_outline, color: cs.primary),
      title: Text(l.supporterRestoreNoticeTitle),
      subtitle: Text(l.supporterRestoreNoticeBody),
    );
  }
}

class _SupportLearnMoreTile extends StatelessWidget {
  const _SupportLearnMoreTile();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.open_in_new, color: cs.primary),
      title: Text(l.supporterLearnMoreTitle),
      subtitle: Text(l.supporterLearnMoreBody),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openSupporterDoc(context),
    );
  }
}

class _SupportSummaryTile extends StatelessWidget {
  const _SupportSummaryTile({required this.state});

  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    final summary = state.summary;

    if (summary.supporterSince != null) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummarySinceChip(
            _formatSupportMonthYear(context, summary.supporterSince!),
          ),
        ),
      );
    }
    if (state.isSupporter && summary.supporterSince != null) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummaryStreakChip(
            _formatSupportDuration(
              l,
              summary.supporterSince!,
              DateTime.now(),
            ),
          ),
        ),
      );
    }
    if (summary.oneTimeSupportCount > 0) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummaryOneTimeCount(summary.oneTimeSupportCount),
        ),
      );
    }
    if (summary.coffeeSupportCount > 0) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummaryCoffeeCount(summary.coffeeSupportCount),
        ),
      );
    }
    if (summary.lunchSupportCount > 0) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummaryLunchCount(summary.lunchSupportCount),
        ),
      );
    }

    return ListTile(
      leading: Icon(Icons.auto_awesome, color: cs.primary),
      title: Text(l.supporterSummaryTitle),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      ),
    );
  }
}

class _SupportSummaryChip extends StatelessWidget {
  const _SupportSummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SupportEmptyTile extends StatelessWidget {
  const _SupportEmptyTile({required this.errorMessage, required this.onRetry});

  final String? errorMessage;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(Icons.info_outline, color: cs.primary),
      title: Text(l.supporterProductsUnavailable),
      subtitle: errorMessage == null ? null : Text(errorMessage!),
      trailing: TextButton(
        onPressed: onRetry,
        child: Text(l.supporterRetryButton),
      ),
    );
  }
}

class _SupportPackageTile extends StatelessWidget {
  const _SupportPackageTile({required this.package, required this.state});

  final SupportPackage package;
  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final revenueCat = context.read<RevenueCatService>();
    final isCurrentSubscription = package.isSubscription && state.isSupporter;
    final isPurchasing = state.purchasingPackageId == package.id;

    return ListTile(
      leading: Icon(_iconForPackage(package), color: cs.primary),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _titleForPackage(l, package),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            package.priceLabel,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      subtitle: Text(_descriptionForPackage(l, package)),
      trailing: FilledButton(
        onPressed: state.isBusy || isCurrentSubscription
            ? null
            : () async {
                final result = await revenueCat.purchasePackage(package.id);
                if (!context.mounted) return;
                _showResultSnackBar(context, result, package: package);
              },
        child: isPurchasing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                isCurrentSubscription
                    ? l.supporterActiveButton
                    : l.supporterBuyButton,
              ),
      ),
    );
  }

  IconData _iconForPackage(SupportPackage package) {
    switch (package.kind) {
      case SupportPackageKind.monthly:
        return Icons.favorite;
      case SupportPackageKind.coffee:
        return Icons.local_cafe;
      case SupportPackageKind.lunch:
        return Icons.lunch_dining;
      case SupportPackageKind.other:
        return Icons.volunteer_activism_outlined;
    }
  }

  String _descriptionForPackage(AppLocalizations l, SupportPackage package) {
    switch (package.kind) {
      case SupportPackageKind.monthly:
        return l.supporterMonthlyDescription;
      case SupportPackageKind.coffee:
        return l.supporterCoffeeDescription;
      case SupportPackageKind.lunch:
        return l.supporterLunchDescription;
      case SupportPackageKind.other:
        return l.supporterStatusInactive;
    }
  }

  String _titleForPackage(AppLocalizations l, SupportPackage package) {
    switch (package.kind) {
      case SupportPackageKind.monthly:
        return l.supporterMonthlyTitle;
      case SupportPackageKind.coffee:
        return l.supporterCoffeeTitle;
      case SupportPackageKind.lunch:
        return l.supporterLunchTitle;
      case SupportPackageKind.other:
        return package.title;
    }
  }
}

void _showResultSnackBar(
  BuildContext context,
  SupportActionResult result, {
  bool isRestore = false,
  SupportPackage? package,
}) {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final packageTitle = switch (package?.kind) {
    SupportPackageKind.monthly => l.supporterMonthlyTitle,
    SupportPackageKind.coffee => l.supporterCoffeeTitle,
    SupportPackageKind.lunch => l.supporterLunchTitle,
    SupportPackageKind.other => package?.title,
    null => null,
  };

  final text = switch (result.type) {
    SupportActionResultType.success when isRestore => l.supporterRestoreSuccess,
    SupportActionResultType.success => l.supporterPurchaseSuccess(
      packageTitle ?? l.supporterTitle,
    ),
    SupportActionResultType.cancelled => l.supporterPurchaseCancelled,
    SupportActionResultType.error when isRestore => l.supporterRestoreFailed(
      result.message ?? 'unknown',
    ),
    SupportActionResultType.error => l.supporterPurchaseFailed(
      result.message ?? 'unknown',
    ),
  };

  messenger.showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _openSupporterDoc(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final launched = await launchUrl(
    _supporterDocUri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched && context.mounted) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.supporterOpenLinkFailed)),
    );
  }
}

String _formatSupportMonthYear(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return intl.DateFormat.yMMM(locale).format(date);
}

String _formatSupportDuration(
  AppLocalizations l,
  DateTime start,
  DateTime end,
) {
  final months = _completedMonthsBetween(start, end);
  if (months <= 0) {
    return l.supporterSummaryLessThanMonth;
  }
  return l.supporterSummaryDurationMonths(months);
}

int _completedMonthsBetween(DateTime start, DateTime end) {
  var months = (end.year - start.year) * 12 + end.month - start.month;
  if (end.day < start.day) {
    months -= 1;
  }
  return months < 0 ? 0 : months;
}
