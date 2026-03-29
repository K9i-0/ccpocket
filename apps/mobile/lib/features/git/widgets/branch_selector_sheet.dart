import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/bridge_service.dart';
import '../state/branch_cubit.dart';
import '../state/branch_state.dart';

/// Shows the branch selector bottom sheet.
void showBranchSelectorSheet(BuildContext context, String projectPath) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider(
      create: (_) => BranchCubit(
        bridge: context.read<BridgeService>(),
        projectPath: projectPath,
      )..loadBranches(),
      child: const _BranchSelectorContent(),
    ),
  );
}

class _BranchSelectorContent extends StatefulWidget {
  const _BranchSelectorContent();

  @override
  State<_BranchSelectorContent> createState() => _BranchSelectorContentState();
}

class _BranchSelectorContentState extends State<_BranchSelectorContent> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BranchCubit, BranchState>(
      builder: (context, state) {
        final cubit = context.read<BranchCubit>();
        final cs = Theme.of(context).colorScheme;
        final filtered = cubit.filteredBranches;

        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Branches',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          key: const ValueKey('create_branch_button'),
                          icon: const Icon(Icons.add),
                          tooltip: 'New Branch',
                          onPressed: () => _showCreateBranchDialog(context, cubit),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      key: const ValueKey('branch_search_field'),
                      controller: _searchController,
                      onChanged: cubit.search,
                      decoration: const InputDecoration(
                        hintText: 'Search branches...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),

                  const Divider(height: 1),

                  // Loading / Error / Branch list
                  if (state.loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        state.error!,
                        style: TextStyle(color: cs.error),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final branch = filtered[index];
                          final isCurrent = branch == state.current;

                          return ListTile(
                            key: ValueKey('branch_$branch'),
                            leading: Icon(
                              isCurrent ? Icons.check_circle : Icons.circle_outlined,
                              color: isCurrent ? cs.primary : cs.outline,
                              size: 20,
                            ),
                            title: Text(
                              branch,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight:
                                    isCurrent ? FontWeight.w600 : FontWeight.normal,
                                color: isCurrent ? cs.primary : cs.onSurface,
                              ),
                            ),
                            dense: true,
                            onTap: isCurrent
                                ? null
                                : () {
                                    cubit.checkout(branch);
                                    Navigator.of(context).pop();
                                  },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateBranchDialog(BuildContext context, BranchCubit cubit) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('New Branch'),
          content: TextField(
            key: const ValueKey('new_branch_name_field'),
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Branch name (e.g. feat/login)',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('create_branch_confirm'),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  cubit.createBranch(name);
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text('Create & Checkout'),
            ),
          ],
        );
      },
    );
  }
}
