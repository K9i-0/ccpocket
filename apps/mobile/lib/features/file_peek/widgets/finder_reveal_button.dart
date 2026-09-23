import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../state/finder_reveal_cubit.dart';
import '../state/finder_reveal_state.dart';

class FinderRevealButton extends StatelessWidget {
  final BridgeService bridge;
  final String projectPath;
  final String filePath;

  const FinderRevealButton({
    super.key,
    required this.bridge,
    required this.projectPath,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FinderRevealCubit(bridge),
      child: BlocConsumer<FinderRevealCubit, FinderRevealState>(
        listener: (context, state) {
          if (state.errorCode == null) return;
          final l10n = AppLocalizations.of(context);
          final message = switch (state.errorCode) {
            'not_local_mac' => l10n.finderRevealLocalOnly,
            'bridge_update_required' => l10n.finderRevealUpdateBridge,
            _ => l10n.finderRevealFailed,
          };
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) => IconButton(
          key: const ValueKey('file_peek_reveal_finder_button'),
          tooltip: AppLocalizations.of(context).finderReveal,
          onPressed: state.busy
              ? null
              : () => context.read<FinderRevealCubit>().reveal(
                  projectPath,
                  filePath,
                ),
          icon: state.busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open_outlined, size: 18),
        ),
      ),
    );
  }
}
