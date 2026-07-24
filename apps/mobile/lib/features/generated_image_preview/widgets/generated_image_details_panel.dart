import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../generated_image_preview_item.dart';

class GeneratedImageDetailsPanel extends StatelessWidget {
  final GeneratedImagePreviewItem item;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const GeneratedImageDetailsPanel({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.44;
    return Container(
      key: const ValueKey('generated_image_details_panel'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xE6000000), Colors.black],
          stops: [0, 0.2, 1],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              physics: expanded || !item.hasDetails
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: _DetailsContent(
                item: item,
                expanded: expanded,
                onToggleExpanded: onToggleExpanded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsContent extends StatelessWidget {
  final GeneratedImagePreviewItem item;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  const _DetailsContent({
    required this.item,
    required this.expanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF69D5C3), size: 15),
            const SizedBox(width: 8),
            Text(
              l.generatedImagePromptLabel,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            _ImageFormatBadge(mimeType: item.mimeType),
          ],
        ),
        const SizedBox(height: 8),
        SelectableText(
          item.prompt,
          key: const ValueKey('generated_image_prompt_text'),
          maxLines: expanded || !item.hasDetails ? null : 3,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        if (item.hasDetails) ...[
          const SizedBox(height: 8),
          _DetailsToggle(expanded: expanded, onPressed: onToggleExpanded),
          if (expanded) ...[
            const Divider(color: Colors.white24, height: 20),
            _TechnicalDetails(item: item),
          ],
        ],
      ],
    );
  }
}

class _ImageFormatBadge extends StatelessWidget {
  final String mimeType;

  const _ImageFormatBadge({required this.mimeType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        mimeType.replaceFirst('image/', '').toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DetailsToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  const _DetailsToggle({required this.expanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextButton.icon(
      key: const ValueKey('generated_image_details_button'),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
      ),
      icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 17),
      label: Text(
        expanded
            ? l.generatedImageHideDetailsLabel
            : l.generatedImageDetailsLabel,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _TechnicalDetails extends StatelessWidget {
  final GeneratedImagePreviewItem item;

  const _TechnicalDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.status case final status? when status.isNotEmpty)
          _MetadataRow(label: l.generatedImageStatusLabel, value: status),
        if (item.savedPath case final savedPath? when savedPath.isNotEmpty)
          _MetadataRow(label: l.generatedImageSavedPathLabel, value: savedPath),
        if (item.details case final details? when details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              details,
              key: const ValueKey('generated_image_raw_details'),
              style: const TextStyle(
                color: Colors.white60,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
