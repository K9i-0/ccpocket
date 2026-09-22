import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import '../../../router/app_router.dart';
import '../../../router/session_stack_navigation.dart';
import '../state/workspace_destination.dart';

/// Legacy routes and direct URLs resolve to the same workspace as list taps
/// and notifications. Never create a second, independently owned chat screen.
class WorkspaceSessionRouteAdapter extends StatefulWidget {
  const WorkspaceSessionRouteAdapter({super.key, required this.selection});

  final WorkspaceSessionSelection selection;

  @override
  State<WorkspaceSessionRouteAdapter> createState() =>
      _WorkspaceSessionRouteAdapterState();
}

class _WorkspaceSessionRouteAdapterState
    extends State<WorkspaceSessionRouteAdapter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = context.router;
      if (SessionStackNavigation.openWorkspaceSession(
        router,
        widget.selection,
      )) {
        return;
      }
      router.replaceAll([AdaptiveHomeRoute(initialSession: widget.selection)]);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
