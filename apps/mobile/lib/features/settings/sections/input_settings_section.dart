import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/image_paste_shortcut.dart';
import '../../../models/input_delivery.dart';
import '../../../models/skill_trigger_style.dart';
import '../models/settings_catalog.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/speech_locale_bottom_sheet.dart';

class InputSettingsSection extends StatelessWidget {
  const InputSettingsSection({
    super.key,
    required this.state,
    required this.visibility,
  });

  final SettingsState state;
  final SettingsVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<SettingsCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.settingsGroupSending,
          children: [
            SettingsItem(
              id: SettingsEntryIds.defaultInputDelivery,
              child: SettingsControlTile(
                key: const ValueKey('default_input_delivery_tile'),
                icon: Icons.low_priority_rounded,
                title: l.defaultInputDelivery,
                description: l.defaultInputDeliverySubtitle,
                control: SegmentedButton<InputDelivery>(
                  key: const ValueKey('default_input_delivery_selector'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: InputDelivery.queue,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(l.inputDeliveryQueue),
                    ),
                    ButtonSegment(
                      value: InputDelivery.steer,
                      icon: const Icon(Icons.subdirectory_arrow_left, size: 18),
                      label: Text(l.inputDeliverySteer),
                    ),
                  ],
                  selected: {state.defaultInputDelivery},
                  onSelectionChanged: (selection) =>
                      cubit.setDefaultInputDelivery(selection.first),
                ),
              ),
            ),
            SettingsItem(
              id: SettingsEntryIds.skillTriggerStyle,
              child: SettingsControlTile(
                key: const ValueKey('skill_trigger_style_tile'),
                icon: Icons.extension_rounded,
                title: l.skillTriggerStyle,
                description: l.skillTriggerStyleSubtitle,
                control: SegmentedButton<SkillTriggerStyle>(
                  key: const ValueKey('skill_trigger_style_selector'),
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: SkillTriggerStyle.both,
                      label: Text(l.skillTriggerStyleBoth),
                    ),
                    ButtonSegment(
                      value: SkillTriggerStyle.slash,
                      label: Text(l.skillTriggerStyleSlash),
                    ),
                    ButtonSegment(
                      value: SkillTriggerStyle.dollar,
                      label: Text(l.skillTriggerStyleDollar),
                    ),
                  ],
                  selected: {state.skillTriggerStyle},
                  onSelectionChanged: (selection) =>
                      cubit.setSkillTriggerStyle(selection.first),
                ),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.voiceInput,
          children: [
            if (!visibility.hideVoiceInput)
              SettingsItem(
                id: SettingsEntryIds.voiceInput,
                child: SettingsNavTile(
                  icon: Icons.record_voice_over_rounded,
                  title: Text(l.voiceInput),
                  subtitle: getSpeechLocaleLabel(context, state.speechLocaleId),
                  onTap: () => showSpeechLocaleBottomSheet(
                    context: context,
                    current: state.speechLocaleId,
                    onChanged: cubit.setSpeechLocaleId,
                  ),
                ),
              ),
            SettingsItem(
              id: SettingsEntryIds.hideVoiceInput,
              child: SettingsSwitchTile(
                icon: Icons.mic_off_rounded,
                title: l.hideVoiceInput,
                subtitle: l.hideVoiceInputSubtitle,
                value: state.hideVoiceInput,
                onChanged: cubit.setHideVoiceInput,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.settingsGroupAttachments,
          children: [
            SettingsItem(
              id: SettingsEntryIds.openGalleryDirectly,
              child: SettingsSwitchTile(
                key: const ValueKey('open_gallery_directly_toggle'),
                icon: Icons.photo_library_rounded,
                title: l.openGalleryDirectly,
                subtitle: l.openGalleryDirectlySubtitle,
                value: state.openGalleryDirectly,
                onChanged: cubit.setOpenGalleryDirectly,
              ),
            ),
            if (visibility.isMacOS)
              SettingsItem(
                id: SettingsEntryIds.imagePasteShortcut,
                child: SettingsControlTile(
                  icon: Icons.content_paste_rounded,
                  title: l.imagePasteShortcut,
                  description: switch (state.imagePasteShortcut) {
                    ImagePasteShortcut.ctrlV =>
                      l.imagePasteShortcutCtrlVDescription,
                    ImagePasteShortcut.commandV =>
                      l.imagePasteShortcutCommandVDescription,
                  },
                  control: SegmentedButton<ImagePasteShortcut>(
                    key: const ValueKey('image_paste_shortcut_segment'),
                    segments: [
                      ButtonSegment(
                        value: ImagePasteShortcut.ctrlV,
                        label: Text(l.imagePasteShortcutCtrlV),
                      ),
                      ButtonSegment(
                        value: ImagePasteShortcut.commandV,
                        label: Text(l.imagePasteShortcutCommandV),
                      ),
                    ],
                    selected: {state.imagePasteShortcut},
                    onSelectionChanged: (selected) =>
                        cubit.setImagePasteShortcut(selected.first),
                    showSelectedIcon: false,
                  ),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: l.settingsGroupPerformance,
          children: [
            SettingsItem(
              id: SettingsEntryIds.liteMode,
              child: SettingsSwitchTile(
                key: const ValueKey('lite_mode_toggle'),
                icon: Icons.bolt_rounded,
                title: l.liteMode,
                subtitle: l.liteModeDescription,
                value: state.liteMode,
                onChanged: cubit.setLiteMode,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
