import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/bridge_service.dart';
import '../../../widgets/directory_browser_sheet.dart';
import '../state/project_setup_cubit.dart';

class NewProjectResult {
  const NewProjectResult(this.path, this.prompt);
  final String path;
  final String prompt;
}

Future<NewProjectResult?> showNewProjectSheet(
  BuildContext context,
  BridgeService bridge,
  List<String> sources,
) => showModalBottomSheet<NewProjectResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BlocProvider(
    create: (_) => ProjectSetupCubit(bridge),
    child: NewProjectSheet(sources: sources),
  ),
);

class NewProjectSheet extends StatefulWidget {
  const NewProjectSheet({super.key, required this.sources});
  final List<String> sources;
  @override
  State<NewProjectSheet> createState() => _NewProjectSheetState();
}

class _NewProjectSheetState extends State<NewProjectSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String get _parentPreferenceKey =>
      'new_project_parent_${context.read<ProjectSetupCubit>().bridge.lastUrl ?? "default"}';
  final _parent = TextEditingController();
  final _description = TextEditingController();
  String? _source;
  String? _createdPath;
  bool _git = true;
  bool _trust = false;
  List<String> _copiedFiles = [];
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted && _parent.text.isEmpty) {
        _parent.text =
            prefs.getString(_parentPreferenceKey) ??
            (widget.sources.isEmpty
                ? ''
                : widget.sources.first.replaceFirst(
                    RegExp(r'[/\\][^/\\]+$'),
                    '',
                  ));
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _parent.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _browse({bool source = false}) async {
    final path = await showDirectoryBrowserSheet(
      context: context,
      bridge: context.read<ProjectSetupCubit>().bridge,
      initialPath: source ? _source : _parent.text,
    );
    if (path != null && mounted) {
      setState(() {
        if (source) {
          _source = path;
        } else {
          _parent.text = path;
        }
      });
    }
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final cubit = context.read<ProjectSetupCubit>();
    final parentPreferenceKey = _parentPreferenceKey;
    final parentPath = _parent.text.trim();
    final l = AppLocalizations.of(context);
    if (_createdPath == null) {
      final result = await cubit.request({
        'type': 'bootstrap_project',
        'parentPath': parentPath,
        'name': _name.text.trim(),
        'initializeGit': _git,
        if (_source != null) 'sourcePath': _source,
      }, updateHint: l.projectSetupUpdateHint);
      if (result == null || !mounted) return;
      setState(() {
        _createdPath = result.projectPath;
        _copiedFiles = result.copiedFiles;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(parentPreferenceKey, parentPath);
    }
    if (!mounted) return;
    if (_trust) {
      final result = await cubit.request({
        'type': 'trust_project',
        'projectPath': _createdPath,
      }, updateHint: l.projectSetupUpdateHint);
      if (result == null || !mounted) return;
    }
    if (!mounted) return;
    final prompt = [
      _description.text.trim(),
      if (_copiedFiles.isNotEmpty) l.projectSetupAdaptPrompt,
    ].where((s) => s.isNotEmpty).join('\n\n');
    Navigator.pop(context, NewProjectResult(_createdPath!, prompt));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BlocBuilder<ProjectSetupCubit, ProjectSetupState>(
      builder: (context, state) {
        final editable = !state.busy && _createdPath == null;
        return PopScope(
          canPop: !state.busy,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.newProject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      validator: (value) =>
                          value == null ||
                              value.trim().isEmpty ||
                              RegExp(r'[<>:"/\\|?*]').hasMatch(value) ||
                              value.trim() == '..' ||
                              value.trim() == '.'
                          ? l.newProjectName
                          : null,
                      key: const ValueKey('new_project_name_field'),
                      controller: _name,
                      enabled: editable,
                      decoration: InputDecoration(labelText: l.newProjectName),
                    ),
                    TextFormField(
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l.newProjectParent
                          : null,
                      key: const ValueKey('new_project_parent_field'),
                      controller: _parent,
                      enabled: editable,
                      decoration: InputDecoration(
                        labelText: l.newProjectParent,
                        suffixIcon: IconButton(
                          onPressed: editable ? () => _browse() : null,
                          icon: const Icon(Icons.folder_open),
                        ),
                      ),
                    ),
                    TextField(
                      key: const ValueKey('new_project_description_field'),
                      controller: _description,
                      enabled: !state.busy,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 12000,
                      decoration: InputDecoration(
                        labelText: l.newProjectDescription,
                      ),
                    ),
                    CheckboxListTile(
                      key: const ValueKey('new_project_git_toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.newProjectGit),
                      value: _git,
                      onChanged: editable
                          ? (value) => setState(() => _git = value!)
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('new_project_source_field'),
                      initialValue: _source,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l.newProjectSettingsSource,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l.newProjectNoSource),
                        ),
                        for (final path in {...widget.sources, ?_source})
                          DropdownMenuItem(
                            value: path,
                            child: Tooltip(
                              message: path,
                              child: Text(
                                path.split(RegExp(r'[/\\]')).last,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                      onChanged: editable
                          ? (value) => setState(() => _source = value)
                          : null,
                    ),
                    TextButton.icon(
                      key: const ValueKey('new_project_source_browse_button'),
                      onPressed: editable ? () => _browse(source: true) : null,
                      icon: const Icon(Icons.folder_open),
                      label: Text(l.browseDirectory),
                    ),
                    if (_source != null)
                      Text(
                        l.newProjectSettingsHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    CheckboxListTile(
                      key: const ValueKey('new_project_trust_toggle'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.trustProject),
                      subtitle: Text(l.trustProjectHint),
                      value: _trust,
                      onChanged: !state.busy
                          ? (value) => setState(() => _trust = value!)
                          : null,
                    ),
                    if (_createdPath != null)
                      Text('${l.projectSetupCreated}: $_createdPath'),
                    if (state.error != null)
                      Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('new_project_create_button'),
                      onPressed: state.busy ? null : _create,
                      child: Text(
                        state.busy ? l.projectSetupWorking : l.newProjectCreate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
