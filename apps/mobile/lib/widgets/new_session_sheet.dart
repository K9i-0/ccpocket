import 'package:flutter/material.dart';

import '../models/messages.dart';
import '../screens/session_list_screen.dart' show shortenPath;
import '../theme/app_theme.dart';

/// Result returned when the user submits the new session sheet.
class NewSessionParams {
  final String projectPath;
  final PermissionMode permissionMode;
  final bool continueMode;

  const NewSessionParams({
    required this.projectPath,
    required this.permissionMode,
    required this.continueMode,
  });
}

/// Shows a modal bottom sheet for creating a new Claude Code session.
///
/// Returns [NewSessionParams] if the user starts a session, or null on cancel.
Future<NewSessionParams?> showNewSessionSheet({
  required BuildContext context,
  required List<({String path, String name})> recentProjects,
}) {
  return showModalBottomSheet<NewSessionParams>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) =>
        _NewSessionSheetContent(recentProjects: recentProjects),
  );
}

class _NewSessionSheetContent extends StatefulWidget {
  final List<({String path, String name})> recentProjects;

  const _NewSessionSheetContent({required this.recentProjects});

  @override
  State<_NewSessionSheetContent> createState() =>
      _NewSessionSheetContentState();
}

class _NewSessionSheetContentState extends State<_NewSessionSheetContent> {
  final _pathController = TextEditingController();
  var _permissionMode = PermissionMode.acceptEdits;
  var _continueMode = false;

  bool get _hasPath => _pathController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _start() {
    final path = _pathController.text.trim();
    Navigator.pop(
      context,
      NewSessionParams(
        projectPath: path,
        permissionMode: _permissionMode,
        continueMode: _continueMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(appColors),
            _buildTitle(),
            const SizedBox(height: 12),
            if (widget.recentProjects.isNotEmpty) ...[
              _buildRecentProjectsSection(appColors),
              _buildDivider(appColors),
            ],
            _buildPathInput(),
            const SizedBox(height: 12),
            _buildOptions(),
            const SizedBox(height: 12),
            _buildActions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(AppColors appColors) {
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

  Widget _buildTitle() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'New Session',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRecentProjectsSection(AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent Projects',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appColors.subtleText,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        for (final project in widget.recentProjects)
          _buildProjectTile(project, appColors),
      ],
    );
  }

  Widget _buildProjectTile(
    ({String path, String name}) project,
    AppColors appColors,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _pathController.text == project.path;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.folder_outlined,
        size: 22,
        color: isSelected ? cs.primary : appColors.subtleText,
      ),
      title: Text(
        project.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isSelected ? cs.primary : null,
        ),
      ),
      subtitle: Text(
        shortenPath(project.path),
        style: TextStyle(fontSize: 11, color: appColors.subtleText),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, size: 20, color: cs.primary)
          : null,
      onTap: () => setState(() => _pathController.text = project.path),
    );
  }

  Widget _buildDivider(AppColors appColors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: appColors.subtleText.withValues(alpha: 0.2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'or enter path',
              style: TextStyle(fontSize: 11, color: appColors.subtleText),
            ),
          ),
          Expanded(
            child: Divider(color: appColors.subtleText.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  Widget _buildPathInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const ValueKey('dialog_project_path'),
        controller: _pathController,
        decoration: const InputDecoration(
          labelText: 'Project Path',
          hintText: '/path/to/your/project',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<PermissionMode>(
              key: const ValueKey('dialog_permission_mode'),
              initialValue: _permissionMode,
              decoration: const InputDecoration(
                labelText: 'Permission',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: PermissionMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(
                        m.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _permissionMode = value);
              },
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Continue', style: TextStyle(fontSize: 13)),
            selected: _continueMode,
            onSelected: (val) => setState(() => _continueMode = val),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const ValueKey('dialog_start_button'),
              onPressed: _hasPath ? _start : null,
              child: const Text('Start'),
            ),
          ),
        ],
      ),
    );
  }
}
