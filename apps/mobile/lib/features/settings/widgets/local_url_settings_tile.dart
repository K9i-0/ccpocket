import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/local_url_settings.dart';
import '../state/settings_cubit.dart';
import '../state/settings_state.dart';

String localUrlModeLabel(AppLocalizations l, LocalUrlMode mode) =>
    switch (mode) {
      LocalUrlMode.original => l.localUrlOriginal,
      LocalUrlMode.replace => l.localUrlReplace,
      LocalUrlMode.ask => l.localUrlAsk,
    };

class LocalUrlSettingsTile extends StatelessWidget {
  const LocalUrlSettingsTile({super.key, required this.bridgeUrl});
  final String bridgeUrl;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = context.read<SettingsCubit>().localUrlSettingsFor(
          bridgeUrl,
        );
        return ListTile(
          key: const ValueKey('local_url_settings_button'),
          leading: const Icon(Icons.link),
          title: Text(l.localUrlTitle),
          subtitle: Text(localUrlModeLabel(l, settings.mode)),
          onTap: () async {
            final cubit = context.read<SettingsCubit>();
            final result = await showDialog<LocalUrlSettings>(
              context: context,
              builder: (_) => LocalUrlSettingsDialog(
                settings: settings,
                bridgeHost: Uri.tryParse(bridgeUrl)?.host ?? '',
              ),
            );
            if (result != null && !cubit.isClosed) {
              await cubit.setLocalUrlSettings(bridgeUrl, result);
            }
          },
        );
      },
    );
  }
}

class LocalUrlSettingsDialog extends StatefulWidget {
  const LocalUrlSettingsDialog({
    super.key,
    required this.settings,
    required this.bridgeHost,
  });
  final LocalUrlSettings settings;
  final String bridgeHost;

  @override
  State<LocalUrlSettingsDialog> createState() => _LocalUrlSettingsDialogState();
}

class _LocalUrlSettingsDialogState extends State<LocalUrlSettingsDialog> {
  late LocalUrlMode _mode = widget.settings.mode;
  late final _host = TextEditingController(
    text: widget.settings.host.isEmpty
        ? (widget.bridgeHost.contains(':')
              ? '[${widget.bridgeHost}]'
              : widget.bridgeHost)
        : widget.settings.host,
  );
  bool _invalid = false;

  @override
  void dispose() {
    _host.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.localUrlTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.localUrlDescription),
              const SizedBox(height: 16),
              DropdownButtonFormField<LocalUrlMode>(
                key: const ValueKey('local_url_mode_field'),
                initialValue: _mode,
                isExpanded: true,
                items: [
                  for (final mode in LocalUrlMode.values)
                    DropdownMenuItem(
                      value: mode,
                      child: Text(localUrlModeLabel(l, mode)),
                    ),
                ],
                onChanged: (value) => setState(() => _mode = value ?? _mode),
              ),
              if (_mode != LocalUrlMode.original) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('local_url_host_field'),
                  controller: _host,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: l.localUrlHost,
                    hintText: '192.168.1.10',
                    errorText: _invalid ? l.localUrlInvalidHost : null,
                  ),
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  },
                ),
                const SizedBox(height: 12),
                Text(l.localUrlHostHelp),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const ValueKey('local_url_save_button'),
          onPressed: () {
            final host = normalizeLocalUrlHost(_host.text);
            if (_mode != LocalUrlMode.original && host == null) {
              setState(() => _invalid = true);
              return;
            }
            Navigator.pop(
              context,
              LocalUrlSettings(mode: _mode, host: host ?? ''),
            );
          },
          child: Text(l.save),
        ),
      ],
    );
  }
}
