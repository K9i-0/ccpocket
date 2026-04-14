import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/revenuecat_service.dart';

@RoutePage()
class SupporterScreen extends StatefulWidget {
  const SupporterScreen({super.key});

  @override
  State<SupporterScreen> createState() => _SupporterScreenState();
}

class _SupporterScreenState extends State<SupporterScreen> {
  late final int _emojiSeed;

  @override
  void initState() {
    super.initState();
    _emojiSeed = Random().nextInt(1 << 32);
  }

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

          return _SupportEmojiSeedScope(
            seed: _emojiSeed,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _SupportHeroArea(state: state),
                const SizedBox(height: 24),
                const _SupportImpactCard(),
                const SizedBox(height: 24),
                _SupportPackageSection(
                  state: state,
                  onRetry: revenueCat.refresh,
                ),
                const SizedBox(height: 32),
                const _SupportPurchaseInfoCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupportEmojiSeedScope extends InheritedWidget {
  const _SupportEmojiSeedScope({required this.seed, required super.child});

  final int seed;

  static int of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SupportEmojiSeedScope>();
    return scope?.seed ?? 0;
  }

  @override
  bool updateShouldNotify(_SupportEmojiSeedScope oldWidget) {
    return seed != oldWidget.seed;
  }
}

class _SupportHeroArea extends StatelessWidget {
  const _SupportHeroArea({required this.state});
  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasSummary = state.summary.hasActivity;

    if (!state.isSupporter && !hasSummary) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? cs.primary.withValues(alpha: 0.12)
            : cs.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SupportStatusTile(state: state),
          if (hasSummary) ...[
            const SizedBox(height: 12),
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
              icon: Icons.favorite_outline,
              title: l.supporterImpactMotivationTitle,
              body: l.supporterImpactMotivationBody,
            ),
            const SizedBox(height: 12),
            _SupportImpactItem(
              icon: Icons.auto_awesome_outlined,
              title: l.supporterImpactAiTitle,
              body: l.supporterImpactAiBody,
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportPurchaseInfoCard extends StatelessWidget {
  const _SupportPurchaseInfoCard();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.supporterPurchaseInfoTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              l.supporterPurchaseInfoBody,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _SupportTextLink(
              label: l.supporterPurchaseInfoLink,
              onTap: () => _openSupporterDoc(context),
            ),
          ],
        ),
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
      final recurringPackages = state.packages
          .where((package) => package.isSubscription)
          .toList();
      final oneTimePackages =
          state.packages.where((package) => !package.isSubscription).toList()
            ..sort(
              (a, b) => _packageDisplayPriority(
                a,
              ).compareTo(_packageDisplayPriority(b)),
            );

      if (recurringPackages.isNotEmpty) {
        children.add(
          _SupportPackageGroup(
            title: l.supporterSubscriptionGroupTitle,
            body: l.supporterSubscriptionGroupBody,
            packages: recurringPackages,
            state: state,
            showRestoreButton: !state.isSupporter,
          ),
        );
      }
      if (oneTimePackages.isNotEmpty) {
        if (recurringPackages.isNotEmpty) {
          children.add(const SizedBox(height: 20));
        }
        children.add(
          _SupportPackageGroup(
            title: l.supporterOneTimeGroupTitle,
            body: l.supporterOneTimeGroupBody,
            packages: oneTimePackages,
            state: state,
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

class _SupportPackageGroup extends StatelessWidget {
  const _SupportPackageGroup({
    required this.title,
    required this.body,
    required this.packages,
    required this.state,
    this.showRestoreButton = false,
  });

  final String title;
  final String body;
  final List<SupportPackage> packages;
  final SupportCatalogState state;
  final bool showRestoreButton;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final revenueCat = context.read<RevenueCatService>();
    final children = <Widget>[
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(body, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 12),
    ];

    for (var i = 0; i < packages.length; i++) {
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: i < packages.length - 1 ? 12 : 0),
          child: _SupportPackageCard(
            package: packages[i],
            state: state,
            isPremium: packages[i].isSubscription,
          ),
        ),
      );
    }
    if (showRestoreButton) {
      children.add(const SizedBox(height: 8));
      children.add(
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
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
        ),
      );
    }

    return Column(
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
    final isOneTimeOnly = !state.isSupporter && state.summary.hasActivity;

    final subtitle = state.isSupporter
        ? l.supporterStatusActive
        : isOneTimeOnly
        ? l.supportEntryOneTimeSubtitle
        : state.isLoading
        ? l.supporterStatusLoading
        : l.supportEntryInactiveSubtitle;

    return ListTile(
      contentPadding: (state.isSupporter || isOneTimeOnly)
          ? EdgeInsets.zero
          : null,
      leading: (state.isSupporter || isOneTimeOnly)
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.isSupporter ? Icons.favorite : Icons.favorite_outline,
                color: cs.primary,
                size: 28,
              ),
            )
          : Icon(Icons.favorite, color: cs.primary),
      title: Row(
        children: [
          Text(
            state.isSupporter
                ? l.supporterTitle
                : isOneTimeOnly
                ? l.supportEntryOneTimeTitle
                : l.supportEntryInactiveTitle,
            style: (state.isSupporter || isOneTimeOnly)
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  )
                : null,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: (state.isSupporter || isOneTimeOnly)
              ? TextStyle(color: cs.onPrimaryContainer.withValues(alpha: 0.8))
              : null,
        ),
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

class _SupportSummaryContent extends StatelessWidget {
  const _SupportSummaryContent({required this.state});

  final SupportCatalogState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final summary = state.summary;
    final activityChips = <Widget>[
      if (summary.oneTimeSupportCount > 0 &&
          summary.coffeeSupportCount == 0 &&
          summary.lunchSupportCount == 0)
        _SupportSummaryBadge(
          label: l.supporterSummaryOneTimeCount(summary.oneTimeSupportCount),
        ),
      if (summary.lunchSupportCount > 0)
        _SupportSummaryBadge(
          label: l.supporterSummaryLunchCount(summary.lunchSupportCount),
        ),
      if (summary.coffeeSupportCount > 0)
        _SupportSummaryBadge(
          label: l.supporterSummaryCoffeeCount(summary.coffeeSupportCount),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                l.supporterSummaryTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (summary.supporterSince != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SupportSummaryStat(
                    label: l.supporterSummarySinceLabel,
                    value: _formatSupportMonthYear(
                      context,
                      summary.supporterSince!,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SupportSummaryStat(
                    label: state.isSupporter
                        ? l.supporterSummaryOngoingLabel
                        : l.supporterSummarySupportPeriodLabel,
                    value: _formatSupportDuration(
                      l,
                      summary.supporterSince!,
                      DateTime.now(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (activityChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: activityChips),
          ],
        ],
      ),
    );
  }
}

class _SupportSummaryStat extends StatelessWidget {
  const _SupportSummaryStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSummaryBadge extends StatelessWidget {
  const _SupportSummaryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportTextLink extends StatelessWidget {
  const _SupportTextLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 16, color: cs.primary),
          ],
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
    final textTheme = Theme.of(context).textTheme;
    final revenueCat = context.read<RevenueCatService>();
    final isCurrentSubscription = package.isSubscription && state.isSupporter;
    final isPurchasing = state.purchasingPackageId == package.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SupportPackageLeading(package: package),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _titleForPackage(l, package),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (package.kind == SupportPackageKind.monthly)
                  _MonthlySupportDescription(
                    description: l.supporterMonthlyDescription,
                    perkLabel: l.supporterMonthlyPerkLabel,
                  )
                else
                  Text(
                    _descriptionForPackage(l, package),
                    style: textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 10),
                Text(
                  package.priceLabel,
                  style: textTheme.titleLarge?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 44),
                ),
                onPressed: state.isBusy || isCurrentSubscription
                    ? null
                    : () async {
                        final result = await revenueCat.purchasePackage(
                          package.id,
                        );
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
            ],
          ),
        ],
      ),
    );
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

class _MonthlySupportDescription extends StatelessWidget {
  const _MonthlySupportDescription({
    required this.description,
    required this.perkLabel,
  });

  final String description;
  final String perkLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          perkLabel,
          style: textTheme.labelMedium?.copyWith(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

int _packageDisplayPriority(SupportPackage package) {
  return switch (package.kind) {
    SupportPackageKind.monthly => 0,
    SupportPackageKind.lunch => 1,
    SupportPackageKind.coffee => 2,
    SupportPackageKind.other => 3,
  };
}

class _SupportPackageLeading extends StatelessWidget {
  const _SupportPackageLeading({required this.package});

  final SupportPackage package;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final emoji = _emojiForPackage(context, package);
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: emoji != null
            ? Text(emoji, style: const TextStyle(fontSize: 28))
            : Icon(_iconForPackage(package), color: cs.primary, size: 28),
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

  String? _emojiForPackage(BuildContext context, SupportPackage package) {
    final candidates = switch (package.kind) {
      SupportPackageKind.coffee => [
        '☕',
        '🍵',
        '🧃',
        '🥤',
        '🧋',
        '🍹',
        '🍺',
        '🍻',
        '🥛',
      ],
      SupportPackageKind.lunch => [
        '🍔',
        '🍕',
        '🍜',
        '🍛',
        '🍣',
        '🥪',
        '🌭',
        '🥟',
        '🍱',
        '🥙',
      ],
      _ => const <String>[],
    };
    if (candidates.isEmpty) return null;
    final seed = _SupportEmojiSeedScope.of(context);
    final index = Object.hash(seed, package.id).abs() % candidates.length;
    return candidates[index];
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
