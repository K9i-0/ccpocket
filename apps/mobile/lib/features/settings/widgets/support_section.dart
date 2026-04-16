import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;

import '../../../l10n/app_localizations.dart';
import '../../../services/revenuecat_service.dart';
import '../../../router/app_router.dart';

enum _SupportEntryVariant { inactive, oneTime, active }

class SupportSectionCard extends StatelessWidget {
  const SupportSectionCard({super.key, this.highlighted = false});

  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final revenueCat = context.read<RevenueCatService>();
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return ValueListenableBuilder<SupportCatalogState>(
      valueListenable: revenueCat.catalogState,
      builder: (context, state, _) {
        if (!state.isAvailable && state.errorMessage == null) {
          return const SizedBox.shrink();
        }

        final variant = _variantForState(state);
        final title = _titleForVariant(l, variant);
        final subtitle = _subtitleForVariant(context, l, state, variant);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: highlighted
                  ? [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: highlighted
                      ? cs.primary.withValues(alpha: 0.75)
                      : cs.outlineVariant.withValues(alpha: 0.18),
                  width: highlighted ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                key: const ValueKey('supporter_entry_button'),
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  context.pushRoute(const SupporterRoute());
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: _iconDecorationForVariant(cs, variant),
                        child: Icon(
                          _iconForVariant(variant),
                          color: _iconColorForVariant(cs, variant),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _SupportEntryVariant _variantForState(SupportCatalogState state) {
    if (state.isSupporter) return _SupportEntryVariant.active;
    if (state.summary.hasActivity) return _SupportEntryVariant.oneTime;
    return _SupportEntryVariant.inactive;
  }

  String _titleForVariant(AppLocalizations l, _SupportEntryVariant variant) {
    return switch (variant) {
      _SupportEntryVariant.inactive => l.supportEntryInactiveTitle,
      _SupportEntryVariant.oneTime => l.supportEntryOneTimeTitle,
      _SupportEntryVariant.active => l.supportEntryActiveTitle,
    };
  }

  String _subtitleForVariant(
    BuildContext context,
    AppLocalizations l,
    SupportCatalogState state,
    _SupportEntryVariant variant,
  ) {
    return switch (variant) {
      _SupportEntryVariant.inactive => l.supportEntryInactiveSubtitle,
      _SupportEntryVariant.oneTime => l.supportEntryOneTimeSubtitle,
      _SupportEntryVariant.active when state.summary.supporterSince != null =>
        l.supportEntryActiveSubtitle(
          _formatSupportMonthYear(context, state.summary.supporterSince!),
        ),
      _SupportEntryVariant.active => l.supporterStatusActive,
    };
  }

  IconData _iconForVariant(_SupportEntryVariant variant) {
    return switch (variant) {
      _SupportEntryVariant.inactive => Icons.favorite_border,
      _SupportEntryVariant.oneTime => Icons.favorite_outline,
      _SupportEntryVariant.active => Icons.favorite,
    };
  }

  Decoration _iconDecorationForVariant(
    ColorScheme cs,
    _SupportEntryVariant variant,
  ) {
    if (variant == _SupportEntryVariant.active) {
      return BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      );
    }
    return BoxDecoration(
      color: switch (variant) {
        _SupportEntryVariant.inactive => cs.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        _SupportEntryVariant.oneTime => cs.primaryContainer.withValues(
          alpha: 0.5,
        ),
        _SupportEntryVariant.active => Colors.transparent, // unreachable
      },
      shape: BoxShape.circle,
    );
  }

  Color _iconColorForVariant(ColorScheme cs, _SupportEntryVariant variant) {
    return switch (variant) {
      _SupportEntryVariant.inactive => cs.onSurfaceVariant,
      _SupportEntryVariant.oneTime => cs.primary,
      _SupportEntryVariant.active => cs.onPrimary,
    };
  }

  String _formatSupportMonthYear(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return intl.DateFormat.yMMMM(locale).format(date);
  }
}
