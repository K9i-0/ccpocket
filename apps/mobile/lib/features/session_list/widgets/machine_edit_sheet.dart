import 'package:flutter/material.dart';

import '../../../models/machine.dart';
import '../../../services/ssh_startup_service.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet for adding or editing a remote machine configuration.
class MachineEditSheet extends StatefulWidget {
  /// Existing machine to edit, or null for adding new
  final Machine? machine;

  /// Existing API key (for edit mode)
  final String? existingApiKey;

  /// Existing SSH password (for edit mode)
  final String? existingSshPassword;

  /// Callback when save is pressed
  final Future<void> Function({
    required Machine machine,
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
  })
  onSave;

  /// Optional callback to connect after saving (add mode only).
  /// When provided, the save button label changes to "Add & Connect".
  final void Function(Machine machine, String? apiKey)? onSaveAndConnect;

  /// Callback to test SSH connection
  final Future<SshResult> Function({
    required String host,
    required int sshPort,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKey,
  })
  onTestConnection;

  const MachineEditSheet({
    super.key,
    this.machine,
    this.existingApiKey,
    this.existingSshPassword,
    required this.onSave,
    this.onSaveAndConnect,
    required this.onTestConnection,
  });

  @override
  State<MachineEditSheet> createState() => _MachineEditSheetState();
}

class _MachineEditSheetState extends State<MachineEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _sshUsernameController;
  late final TextEditingController _sshPortController;
  late final TextEditingController _sshPasswordController;
  late final TextEditingController _sshPrivateKeyController;
  bool _sshEnabled = false;
  SshAuthType _sshAuthType = SshAuthType.password;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  bool get isEditing => widget.machine != null;

  @override
  void initState() {
    super.initState();
    final m = widget.machine;

    _nameController = TextEditingController(text: m?.name ?? '');
    _hostController = TextEditingController(text: m?.host ?? '')
      ..addListener(() => setState(() {}));
    _portController = TextEditingController(text: (m?.port ?? 8765).toString());
    _apiKeyController = TextEditingController(
      text: widget.existingApiKey ?? '',
    );
    _sshUsernameController = TextEditingController(text: m?.sshUsername ?? '');
    _sshPortController = TextEditingController(
      text: (m?.sshPort ?? 22).toString(),
    );
    _sshPasswordController = TextEditingController(
      text: widget.existingSshPassword ?? '',
    );
    _sshPrivateKeyController = TextEditingController();

    if (m != null) {
      _sshEnabled = m.sshEnabled;
      _sshAuthType = m.sshAuthType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _apiKeyController.dispose();
    _sshUsernameController.dispose();
    _sshPortController.dispose();
    _sshPasswordController.dispose();
    _sshPrivateKeyController.dispose();
    super.dispose();
  }

  bool get _isValid {
    // Name is now optional (will display host:port if not set)
    return _hostController.text.isNotEmpty;
  }

  bool get _sshConfigValid {
    if (!_sshEnabled) return true;
    if (_sshUsernameController.text.isEmpty) return false;
    if (_sshAuthType == SshAuthType.password) {
      return _sshPasswordController.text.isNotEmpty;
    } else {
      return _sshPrivateKeyController.text.isNotEmpty;
    }
  }

  Future<void> _testConnection() async {
    if (!_sshConfigValid) {
      setState(() {
        _testResult = 'Please fill in SSH credentials';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final result = await widget.onTestConnection(
        host: _hostController.text,
        sshPort: int.tryParse(_sshPortController.text) ?? 22,
        username: _sshUsernameController.text,
        authType: _sshAuthType,
        password: _sshAuthType == SshAuthType.password
            ? _sshPasswordController.text
            : null,
        privateKey: _sshAuthType == SshAuthType.privateKey
            ? _sshPrivateKeyController.text
            : null,
      );

      setState(() {
        _testResult = result.success ? 'Connection successful!' : result.error;
        _testSuccess = result.success;
      });
    } catch (e) {
      setState(() {
        _testResult = e.toString();
        _testSuccess = false;
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      final machine = Machine(
        id: widget.machine?.id ?? '',
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
        host: _hostController.text.trim(),
        port: int.tryParse(_portController.text) ?? 8765,
        sshEnabled: _sshEnabled,
        sshUsername: _sshEnabled ? _sshUsernameController.text.trim() : null,
        sshPort: int.tryParse(_sshPortController.text) ?? 22,
        sshAuthType: _sshAuthType,
      );

      final apiKey = _apiKeyController.text.isNotEmpty
          ? _apiKeyController.text
          : null;

      await widget.onSave(
        machine: machine,
        apiKey: apiKey,
        sshPassword: _sshEnabled && _sshAuthType == SshAuthType.password
            ? _sshPasswordController.text
            : null,
        sshPrivateKey: _sshEnabled && _sshAuthType == SshAuthType.privateKey
            ? _sshPrivateKeyController.text
            : null,
      );

      // Capture callback before pop() dismisses the sheet
      final connectCallback = widget.onSaveAndConnect;
      if (mounted) Navigator.of(context).pop();

      // Trigger connect after sheet is dismissed
      connectCallback?.call(machine, apiKey);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      isEditing ? 'Edit Machine' : 'Add Machine',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Form
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Basic Info
                    _SectionHeader(title: 'Basic Info'),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'Home Mac',
                        prefixIcon: Icon(Icons.label),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host (IP or hostname)',
                        hintText: '100.64.1.2',
                        prefixIcon: Icon(Icons.computer),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '8765',
                              prefixIcon: Icon(Icons.numbers),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _apiKeyController,
                            decoration: const InputDecoration(
                              labelText: 'API Key',
                              hintText: 'Optional',
                              prefixIcon: Icon(Icons.key),
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // SSH Configuration
                    _SectionHeader(title: 'SSH Configuration'),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Enable SSH remote startup',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              'Remotely start Bridge Server when offline',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: _sshEnabled,
                            onChanged: (v) => setState(() => _sshEnabled = v),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_sshEnabled) ...[
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _sshUsernameController,
                              decoration: const InputDecoration(
                                labelText: 'SSH Username',
                                hintText: 'myuser',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _sshPortController,
                              decoration: const InputDecoration(
                                labelText: 'SSH Port',
                                hintText: '22',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Auth type selector
                      SegmentedButton<SshAuthType>(
                        segments: const [
                          ButtonSegment(
                            value: SshAuthType.password,
                            label: Text('Password'),
                            icon: Icon(Icons.password),
                          ),
                          ButtonSegment(
                            value: SshAuthType.privateKey,
                            label: Text('Private Key'),
                            icon: Icon(Icons.vpn_key),
                          ),
                        ],
                        selected: {_sshAuthType},
                        onSelectionChanged: (set) {
                          setState(() => _sshAuthType = set.first);
                        },
                      ),
                      const SizedBox(height: 12),

                      if (_sshAuthType == SshAuthType.password)
                        TextField(
                          controller: _sshPasswordController,
                          decoration: const InputDecoration(
                            labelText: 'SSH Password',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                        )
                      else
                        TextField(
                          controller: _sshPrivateKeyController,
                          decoration: const InputDecoration(
                            labelText: 'SSH Private Key (PEM)',
                            hintText: '-----BEGIN OPENSSH PRIVATE KEY-----',
                            prefixIcon: Icon(Icons.vpn_key),
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),

                      const SizedBox(height: 16),

                      // Test connection button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isTesting ? null : _testConnection,
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_find),
                          label: Text(
                            _isTesting ? 'Testing...' : 'Test Connection',
                          ),
                        ),
                      ),

                      if (_testResult != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testSuccess
                                ? appColors.statusRunning.withValues(alpha: 0.1)
                                : colorScheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testSuccess ? Icons.check_circle : Icons.error,
                                color: _testSuccess
                                    ? appColors.statusRunning
                                    : colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _testResult!,
                                  style: TextStyle(
                                    color: _testSuccess
                                        ? appColors.statusRunning
                                        : colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  16 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onSurfaceVariant,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(elevation: 0),
                        onPressed: _isValid && !_isSaving ? _save : null,
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Save'
                                    : widget.onSaveAndConnect != null
                                    ? 'Add & Connect'
                                    : 'Add',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
