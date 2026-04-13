import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/revenuecat_service.dart';
import '../../../widgets/supporter_badge.dart';

@RoutePage()
class SupporterScreen extends StatelessWidget {
  const SupporterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final revenueCat = context.read<RevenueCatService>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.sectionSupport)),
      body: ValueListenableBuilder<SupportCatalogState>(
        valueListenable: revenueCat.catalogState,
        builder: (context, state, _) {
          if (!state.isAvailable && state.errorMessage == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              _SupportHeroArea(state: state),
              const SizedBox(height: 24),
              const _SupportImpactCard(),
              const SizedBox(height: 24),
              _SupportPackageSection(state: state, onRetry: revenueCat.refresh),
              const SizedBox(height: 32),
              const _SupportFooterInfo(),
            ],
          );
        },
      ),
    );
  }
}

class _SupportHeroArea extends StatelessWidget {
  const _SupportHeroArea({required this.state});
  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = state.isSupporter;

    if (!isActive) {
      return Card(
        margin: EdgeInsets.zero,
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _SupportStatusTile(state: state),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SupportStatusTile(state: state),
          if (state.isSupporter && state.summary.hasActivity) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: cs.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            _SupportSummaryContent(state: state),
          ],
        ],
      ),
    );
  }
}

class _SupportImpactCard extends StatelessWidget {
  const _SupportImpactCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      key: const ValueKey('supporter_impact_card'),
      margin: EdgeInsets.zero,
      color: cs.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.supporterImpactTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l.supporterImpactBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _SupportImpactItem(
              icon: Icons.auto_awesome_outlined,
              title: l.supporterImpactAiTitle,
              body: l.supporterImpactAiBody,
            ),
            const SizedBox(height: 12),
            _SupportImpactItem(
              icon: Icons.devices_outlined,
              title: l.supporterImpactDevicesTitle,
              body: l.supporterImpactDevicesBody,
            ),
            const SizedBox(height: 12),
            _SupportImpactItem(
              icon: Icons.favorite_outline,
              title: l.supporterImpactMotivationTitle,
              body: l.supporterImpactMotivationBody,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportFooterInfo extends StatelessWidget {
  const _SupportFooterInfo();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const _SupportRestoreNoticeTile(),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
          const _SupportLearnMoreTile(),
        ],
      ),
    );
  }
}

class _SupportPackageSection extends StatelessWidget {
  const _SupportPackageSection({required this.state, required this.onRetry});

  final SupportCatalogState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[
      Text(
        l.supporterPackagesTitle,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
    ];

    if (state.isLoading && !state.hasPackages) {
      children.add(const Card(child: _SupportLoadingTile()));
    } else if (state.hasPackages) {
      for (var i = 0; i < state.packages.length; i++) {
        final package = state.packages[i];
        final isPremium = package.kind == SupportPackageKind.monthly;
        children.add(
          Padding(
            padding: EdgeInsets.only(
              bottom: i < state.packages.length - 1 ? 12 : 0,
            ),
            child: _SupportPackageCard(
              package: package,
              state: state,
              isPremium: isPremium,
            ),
          ),
        );
      }
    } else {
      children.add(
        Card(
          child: _SupportEmptyTile(
            errorMessage: state.errorMessage,
            onRetry: onRetry,
          ),
        ),
      );
    }

    return Column(
      key: const ValueKey('supporter_packages_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SupportPackageCard extends StatelessWidget {
  const _SupportPackageCard({
    required this.package,
    required this.state,
    this.isPremium = false,
  });

  final SupportPackage package;
  final SupportCatalogState state;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPremium
            ? BorderSide(color: cs.primary.withValues(alpha: 0.5), width: 1.5)
            : BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _SupportPackageTile(package: package, state: state),
      ),
    );
  }
}

class _SupportImpactItem extends StatelessWidget {
  const _SupportImpactItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
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
      contentPadding: state.isSupporter ? EdgeInsets.zero : null,
      leading: state.isSupporter
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.favorite, color: cs.primary, size: 28),
            )
          : Icon(Icons.favorite, color: cs.primary),
      title: Row(
        children: [
          Text(
            l.supporterTitle,
            style: state.isSupporter
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  )
                : null,
          ),
          if (state.isSupporter) ...[
            const SizedBox(width: 8),
            const SupporterBadge(),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: state.isSupporter
              ? TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.8))
              : null,
        ),
      ),
      trailing: !state.isSupporter
          ? TextButton(
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
            )
          : null,
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

class _SupportSummaryContent extends StatelessWidget {
  const _SupportSummaryContent({required this.state});

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
          isActive: true,
        ),
      );
    }
    if (state.isSupporter && summary.supporterSince != null) {
      chips.add(
        _SupportSummaryChip(
          label: l.supporterSummaryStreakChip(
            _formatSupportDuration(l, summary.supporterSince!, DateTime.now()),
          ),
          isActive: true,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: state.isSupporter ? cs.primary : cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              l.supporterSummaryTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: state.isSupporter ? cs.primary : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: chips),
      ],
    );
  }
}

class _SupportSummaryChip extends StatelessWidget {
  const _SupportSummaryChip({required this.label, this.isActive = false});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? cs.primary : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isActive ? cs.onPrimary : cs.onSecondaryContainer,
          fontWeight: FontWeight.bold,
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
      leading: Icon(_iconForPackage(package), color: cs.primary, size: 28),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _titleForPackage(l, package),
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            package.priceLabel,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(_descriptionForPackage(l, package)),
      ),
      trailing: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: state.isBusy || isCurrentSubscription
            ? null
            : () async {
                final result = await revenueCat.purchasePackage(package.id);
                if (!context.mounted) return;
                _showResultSnackBar(context, result);
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
}) {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final text = switch (result.type) {
    SupportActionResultType.success when isRestore => l.supporterRestoreSuccess,
    SupportActionResultType.success => l.supporterPurchaseSuccess,
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
  final locale = Localizations.localeOf(context).languageCode;
  final uri = switch (locale) {
    'ja' => Uri.parse(
      'https://github.com/K9i-0/ccpocket/blob/main/docs/supporter_ja.md',
    ),
    'zh' => Uri.parse(
      'https://github.com/K9i-0/ccpocket/blob/main/docs/supporter_zh.md',
    ),
    _ => Uri.parse(
      'https://github.com/K9i-0/ccpocket/blob/main/docs/supporter.md',
    ),
  };
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l.supporterOpenLinkFailed)));
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
