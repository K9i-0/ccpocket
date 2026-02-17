import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'guide_page.dart';

/// Page 2: Bridge Server のセットアップ
class GuidePageBridgeSetup extends StatelessWidget {
  const GuidePageBridgeSetup({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final bodyStyle = Theme.of(context).textTheme.bodyLarge;

    return GuidePage(
      icon: Icons.dns,
      title: l.guideBridgeTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.guideBridgeDescription, style: bodyStyle),
          const SizedBox(height: 16),
          // Prerequisites
          _InfoCard(
            colorScheme: cs,
            icon: Icons.checklist,
            title: l.guideBridgePrerequisites,
            items: [l.guideBridgePrereq1, l.guideBridgePrereq2],
          ),
          const SizedBox(height: 16),
          // Steps
          _StepCard(
            colorScheme: cs,
            steps: [
              _Step(
                number: '1',
                title: l.guideBridgeStep1,
                code: l.guideBridgeStep1Command,
              ),
              _Step(
                number: '2',
                title: l.guideBridgeStep2,
                code: l.guideBridgeStep2Command,
              ),
              _Step(
                number: '3',
                title: l.guideBridgeStep3,
                code: l.guideBridgeStep3Command,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code, size: 20, color: cs.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.guideBridgeQrNote,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final IconData icon;
  final String title;
  final List<String> items;

  const _InfoCard({
    required this.colorScheme,
    required this.icon,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: colorScheme.onSurface)),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
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

class _Step {
  final String number;
  final String title;
  final String code;

  const _Step({required this.number, required this.title, required this.code});
}

class _StepCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<_Step> steps;

  const _StepCard({required this.colorScheme, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildStep(context, steps[i]),
        ],
      ],
    );
  }

  Widget _buildStep(BuildContext context, _Step step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step.number,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  step.code,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
