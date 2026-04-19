import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../services/connection_url_parser.dart';
import 'session_list_screen.dart';

const _twoPaneBreakpoint = 600.0;
const _twoPaneDividerWidth = 1.0;

double _leftPaneWidth(double width) {
  if (width >= 1024) return 360;
  if (width >= 720) return 320;
  return 280;
}

@RoutePage()
class WorkspaceShellScreen extends StatelessWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;

  const WorkspaceShellScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      builder: (routerContext, content) {
        final childRouter = AutoRouter.of(routerContext, watch: true);
        final currentChild = childRouter.currentChild;
        final isPlaceholder =
            currentChild == null ||
            currentChild.name == 'WorkspacePlaceholderRoute';

        return LayoutBuilder(
          builder: (context, constraints) {
            final isTwoPane = constraints.maxWidth >= _twoPaneBreakpoint;
            final sessionList = SessionListScreen(
              deepLinkNotifier: deepLinkNotifier,
              debugRecentSessions: debugRecentSessions,
              embedded: isTwoPane,
            );

            if (!isTwoPane) {
              return isPlaceholder ? sessionList : content;
            }

            final leftWidth = _leftPaneWidth(constraints.maxWidth);
            return Row(
              children: [
                SizedBox(
                  width: leftWidth,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surface,
                    child: sessionList,
                  ),
                ),
                Container(
                  width: _twoPaneDividerWidth,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
                ),
                Expanded(child: content),
              ],
            );
          },
        );
      },
    );
  }
}

@RoutePage()
class WorkspacePlaceholderScreen extends StatelessWidget {
  const WorkspacePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l.appTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a session on the left, or start a new one.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
