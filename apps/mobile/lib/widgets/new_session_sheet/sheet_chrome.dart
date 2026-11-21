import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../models/new_session_tab.dart';
import '../../theme/app_theme.dart';
import '../../theme/provider_style.dart';

class NewSessionDragHandle extends StatelessWidget {
  final AppColors appColors;

  const NewSessionDragHandle({super.key, required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            color: appColors.subtleText.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class NewSessionSheetTitle extends StatelessWidget {
  final Provider provider;
  final bool lockProvider;
  final List<NewSessionTab> visibleTabs;
  final ValueChanged<Provider> onProviderChanged;

  const NewSessionSheetTitle({
    super.key,
    required this.provider,
    required this.lockProvider,
    required this.visibleTabs,
    required this.onProviderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final showToggle = visibleTabs.length > 1 && !lockProvider;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.newSession,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('new_session_dismiss_keyboard_button'),
                tooltip: l.dismissKeyboard,
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                icon: const Icon(Icons.keyboard_hide),
              ),
            ],
          ),
          if (showToggle) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  for (final tab in visibleTabs)
                    Expanded(
                      child: _ProviderToggleButton(
                        key: ValueKey('new_session_tab_${tab.value}'),
                        provider: tab.toProvider(),
                        isSelected: provider == tab.toProvider(),
                        isLocked: lockProvider,
                        onTap: () {
                          if (!lockProvider) {
                            onProviderChanged(tab.toProvider());
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NewSessionSheetActions extends StatelessWidget {
  final Provider provider;
  final bool canStart;
  final VoidCallback onStart;

  const NewSessionSheetActions({
    super.key,
    required this.provider,
    required this.canStart,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providerStyle = providerStyleFor(context, provider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(l.cancel),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                key: const ValueKey('dialog_start_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: canStart ? providerStyle.background : null,
                  foregroundColor: canStart ? providerStyle.foreground : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: canStart ? onStart : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Start with ${provider.label}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderToggleButton extends StatelessWidget {
  final Provider provider;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _ProviderToggleButton({
    super.key,
    required this.provider,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = providerStyleFor(context, provider);
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isLocked ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? style.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ProviderIcon(
              provider,
              size: 16,
              color: isSelected ? style.foreground : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            // Three tabs share the row when Antigravity is available.
            Flexible(
              child: Text(
                provider.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? style.foreground : cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
