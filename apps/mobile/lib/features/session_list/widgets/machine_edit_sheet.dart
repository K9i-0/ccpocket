import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/machine.dart';
import '../../../services/ssh_startup_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/network_endpoint.dart';

/// Bottom sheet for adding or editing a remote machine configuration.
class MachineEditSheet extends StatefulWidget {
  /// Existing machine to edit, or null for adding new
  final Machine? machine;

  /// Existing API key (for edit mode)
  final String? existingApiKey;

  /// Existing SSH password (for edit mode)
  final String? existingSshPassword;

  /// Existing SSH private key (for edit mode). Used for testing/saving only;
  /// never prefilled into the text field.
  final String? existingSshPrivateKey;

  /// Existing SSH jump host password (for edit mode)
  final String? existingSshJumpPassword;

  /// Existing SSH jump host private key (for edit mode). Used for
  /// testing/saving only; never prefilled into the text field.
  final String? existingSshJumpPrivateKey;

  /// Callback when save is pressed
  final Future<void> Function({
    required Machine machine,
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
    String? sshJumpPassword,
    String? sshJumpPrivateKey,
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
    String? jumpHost,
    required int jumpPort,
    String? jumpUsername,
    SshAuthType? jumpAuthType,
    String? jumpPassword,
    String? jumpPrivateKey,
    String? password,
    String? privateKey,
  })
  onTestConnection;

  const MachineEditSheet({
    super.key,
    this.machine,
    this.existingApiKey,
    this.existingSshPassword,
    this.existingSshPrivateKey,
    this.existingSshJumpPassword,
    this.existingSshJumpPrivateKey,
    required this.onSave,
    this.onSaveAndConnect,
    required this.onTestConnection,
  });

  @override
  State<MachineEditSheet> createState() => _MachineEditSheetState();
}

class _MachineEditSheetState extends State<MachineEditSheet> {
  static const _keyboardInsetAnimationDuration = Duration(milliseconds: 180);
  static const _footerClearance = 88.0;
  static const _focusedFieldClearance = 160.0;

  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _sshUsernameController;
  late final TextEditingController _sshPortController;
  late final TextEditingController _sshJumpHostController;
  late final TextEditingController _sshJumpPortController;
  late final TextEditingController _sshJumpUsernameController;
  late final TextEditingController _sshJumpPasswordController;
  late final TextEditingController _sshJumpPrivateKeyController;
  late final TextEditingController _sshPasswordController;
  late final TextEditingController _sshPrivateKeyController;
  bool _useSsl = false;
  bool _sshEnabled = false;
  bool _sshJumpEnabled = false;
  SshAuthType _sshAuthType = SshAuthType.password;
  SshAuthType _sshJumpAuthType = SshAuthType.password;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  bool get isEditing => widget.machine != null;

  bool get _hasExistingSshPrivateKey =>
      widget.existingSshPrivateKey?.isNotEmpty ?? false;

  bool get _hasExistingSshJumpPassword =>
      widget.existingSshJumpPassword?.isNotEmpty ?? false;

  bool get _hasExistingSshJumpPrivateKey =>
      widget.existingSshJumpPrivateKey?.isNotEmpty ?? false;

  bool get _hasSshPrivateKey =>
      _sshPrivateKeyController.text.isNotEmpty || _hasExistingSshPrivateKey;

  bool get _hasSshJumpPrivateKey =>
      _sshJumpPrivateKeyController.text.isNotEmpty ||
      _hasExistingSshJumpPrivateKey;

  bool get _hasSavedJumpHostConfiguration {
    final m = widget.machine;
    if (m == null) return false;
    return (m.sshJumpHost?.trim().isNotEmpty ?? false) ||
        m.hasJumpCredentials ||
        _hasExistingSshJumpPassword ||
        _hasExistingSshJumpPrivateKey;
  }

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
    _sshJumpHostController = TextEditingController(text: m?.sshJumpHost ?? '');
    _sshJumpPortController = TextEditingController(
      text: (m?.sshJumpPort ?? 22).toString(),
    );
    _sshJumpUsernameController = TextEditingController(
      text: m?.sshJumpUsername ?? '',
    );
    _sshJumpPasswordController = TextEditingController();
    _sshJumpPrivateKeyController = TextEditingController();
    _sshPasswordController = TextEditingController(
      text: widget.existingSshPassword ?? '',
    );
    _sshPrivateKeyController = TextEditingController();

    if (m != null) {
      _useSsl = m.useSsl;
      _sshEnabled = m.sshEnabled;
      _sshJumpEnabled = _hasSavedJumpHostConfiguration;
      _sshAuthType = m.sshAuthType;
      _sshJumpAuthType = m.sshJumpAuthType;
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
    _sshJumpHostController.dispose();
    _sshJumpPortController.dispose();
    _sshJumpUsernameController.dispose();
    _sshJumpPasswordController.dispose();
    _sshJumpPrivateKeyController.dispose();
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
      return _hasSshPrivateKey;
    }
  }

  Future<void> _testConnection() async {
    final l = AppLocalizations.of(context);
    if (!_sshConfigValid) {
      setState(() {
        _testResult = l.machineEditFillSshCredentials;
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
        jumpHost:
            _sshJumpEnabled && _sshJumpHostController.text.trim().isNotEmpty
            ? _sshJumpHostController.text.trim()
            : null,
        jumpPort: int.tryParse(_sshJumpPortController.text) ?? 22,
        jumpUsername: _sshJumpUsernameController.text.trim().isNotEmpty
            ? _sshJumpUsernameController.text.trim()
            : null,
        jumpAuthType: _sshJumpAuthType,
        jumpPassword:
            _sshJumpAuthType == SshAuthType.password &&
                (_sshJumpPasswordController.text.isNotEmpty ||
                    _hasExistingSshJumpPassword)
            ? _sshJumpPasswordController.text.isNotEmpty
                  ? _sshJumpPasswordController.text
                  : widget.existingSshJumpPassword
            : null,
        jumpPrivateKey:
            _sshJumpAuthType == SshAuthType.privateKey && _hasSshJumpPrivateKey
            ? _sshJumpPrivateKeyController.text.isNotEmpty
                  ? _sshJumpPrivateKeyController.text
                  : widget.existingSshJumpPrivateKey
            : null,
        password: _sshAuthType == SshAuthType.password
            ? _sshPasswordController.text
            : null,
        privateKey: _sshAuthType == SshAuthType.privateKey && _hasSshPrivateKey
            ? _sshPrivateKeyController.text.isNotEmpty
                  ? _sshPrivateKeyController.text
                  : widget.existingSshPrivateKey
            : null,
      );

      setState(() {
        _testResult = result.success
            ? l.machineEditConnectionSuccessful
            : result.error;
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
        host: normalizeHostInput(_hostController.text),
        port: int.tryParse(_portController.text) ?? 8765,
        useSsl: _useSsl,
        sshEnabled: _sshEnabled,
        sshUsername: _sshEnabled ? _sshUsernameController.text.trim() : null,
        sshPort: int.tryParse(_sshPortController.text) ?? 22,
        sshAuthType: _sshAuthType,
        sshJumpHost:
            _sshEnabled &&
                _sshJumpEnabled &&
                _sshJumpHostController.text.trim().isNotEmpty
            ? _sshJumpHostController.text.trim()
            : null,
        sshJumpPort: int.tryParse(_sshJumpPortController.text) ?? 22,
        sshJumpUsername:
            _sshEnabled &&
                _sshJumpEnabled &&
                _sshJumpUsernameController.text.trim().isNotEmpty
            ? _sshJumpUsernameController.text.trim()
            : null,
        sshJumpAuthType: _sshJumpAuthType,
      );

      final apiKey = _apiKeyController.text.isNotEmpty
          ? _apiKeyController.text
          : null;
      final hasJumpHost = machine.sshJumpHost != null;

      await widget.onSave(
        machine: machine,
        apiKey: apiKey,
        sshPassword: _sshEnabled && _sshAuthType == SshAuthType.password
            ? _sshPasswordController.text
            : null,
        sshPrivateKey:
            _sshEnabled &&
                _sshAuthType == SshAuthType.privateKey &&
                _sshPrivateKeyController.text.isNotEmpty
            ? _sshPrivateKeyController.text
            : null,
        sshJumpPassword:
            hasJumpHost &&
                _sshJumpAuthType == SshAuthType.password &&
                _sshJumpPasswordController.text.isNotEmpty
            ? _sshJumpPasswordController.text
            : null,
        sshJumpPrivateKey:
            hasJumpHost &&
                _sshJumpAuthType == SshAuthType.privateKey &&
                _sshJumpPrivateKeyController.text.isNotEmpty
            ? _sshJumpPrivateKeyController.text
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

  EdgeInsets _fieldScrollPadding(BuildContext context) {
    return EdgeInsets.only(
      top: 24,
      bottom: MediaQuery.viewInsetsOf(context).bottom + _focusedFieldClearance,
    );
  }

  Future<void> _ensureFieldVisible(BuildContext fieldContext) async {
    await Future<void>.delayed(_keyboardInsetAnimationDuration);
    if (!mounted || !fieldContext.mounted) return;

    await Scrollable.ensureVisible(
      fieldContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: 0.25,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final appColors = theme.extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    final listBottomPadding =
        32 + _footerClearance + keyboardInset + bottomSafeArea;

    return AnimatedPadding(
      key: const ValueKey('machine_edit_keyboard_avoidance_padding'),
      duration: _keyboardInsetAnimationDuration,
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
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
                        isEditing
                            ? l.machineEditEditTitle
                            : l.machineEditAddTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('dismiss_keyboard_button'),
                        tooltip: l.dismissKeyboard,
                        onPressed: () =>
                            FocusManager.instance.primaryFocus?.unfocus(),
                        icon: const Icon(Icons.keyboard_hide),
                      ),
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
                    padding: EdgeInsets.fromLTRB(16, 16, 16, listBottomPadding),
                    children: [
                      // Basic Info
                      _SectionHeader(title: l.machineEditBasicInfo),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _nameController,
                        scrollPadding: _fieldScrollPadding(context),
                        decoration: InputDecoration(
                          labelText: l.machineEditName,
                          hintText: l.machineEditNameHint,
                          prefixIcon: const Icon(Icons.label),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _hostController,
                        scrollPadding: _fieldScrollPadding(context),
                        decoration: InputDecoration(
                          labelText: l.machineEditHostLabel,
                          hintText: l.machineEditHostHint,
                          prefixIcon: const Icon(Icons.computer),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _portController,
                              scrollPadding: _fieldScrollPadding(context),
                              decoration: InputDecoration(
                                labelText: l.machineEditPort,
                                hintText: l.machineEditBridgePortHint,
                                prefixIcon: const Icon(Icons.numbers),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _apiKeyController,
                              scrollPadding: _fieldScrollPadding(context),
                              decoration: InputDecoration(
                                labelText: l.machineEditApiKey,
                                hintText: l.machineEditOptional,
                                prefixIcon: const Icon(Icons.key),
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _TileCard(
                        child: SwitchListTile(
                          title: Text(
                            l.machineEditUseSecureConnection,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            l.machineEditUseSecureConnectionSubtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          value: _useSsl,
                          onChanged: (v) => setState(() => _useSsl = v),
                          secondary: const Icon(Icons.lock),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // SSH Configuration
                      _SectionHeader(title: l.machineEditSshConfiguration),
                      const SizedBox(height: 12),

                      _TileCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              title: Text(
                                l.machineEditEnableSshRemoteStartup,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                l.machineEditEnableSshRemoteStartupSubtitle,
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
                                scrollPadding: _fieldScrollPadding(context),
                                decoration: InputDecoration(
                                  labelText: l.machineEditSshUsername,
                                  hintText: l.machineEditSshUsernameHint,
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _sshPortController,
                                scrollPadding: _fieldScrollPadding(context),
                                decoration: InputDecoration(
                                  labelText: l.machineEditSshPort,
                                  hintText: l.machineEditSshPortHint,
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _SectionHeader(
                          title: l.machineEditTargetAuthentication,
                        ),
                        const SizedBox(height: 12),

                        SegmentedButton<SshAuthType>(
                          key: const ValueKey('ssh_auth_type_selector'),
                          segments: [
                            ButtonSegment(
                              value: SshAuthType.password,
                              label: Text(l.password),
                              icon: const Icon(Icons.password),
                            ),
                            ButtonSegment(
                              value: SshAuthType.privateKey,
                              label: Text(l.machineEditPrivateKey),
                              icon: const Icon(Icons.vpn_key),
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
                            scrollPadding: _fieldScrollPadding(context),
                            decoration: InputDecoration(
                              labelText: l.sshPassword,
                              prefixIcon: const Icon(Icons.lock),
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (fieldContext) => TextField(
                                  key: const ValueKey('ssh_private_key_field'),
                                  controller: _sshPrivateKeyController,
                                  scrollPadding: _fieldScrollPadding(context),
                                  decoration: InputDecoration(
                                    labelText: l.machineEditSshPrivateKeyPem,
                                    hintText:
                                        l.machineEditOpenSshPrivateKeyHint,
                                    prefixIcon: const Icon(Icons.vpn_key),
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 4,
                                  onTap: () =>
                                      _ensureFieldVisible(fieldContext),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              if (_hasExistingSshPrivateKey &&
                                  _sshPrivateKeyController.text.isEmpty) ...[
                                const SizedBox(height: 8),
                                _SavedCredentialIndicator(
                                  label: l.machineEditSavedPrivateKeyIndicator,
                                ),
                              ],
                            ],
                          ),

                        const SizedBox(height: 16),

                        _TileCard(
                          child: SwitchListTile(
                            key: const ValueKey('ssh_jump_toggle'),
                            title: Text(
                              l.machineEditUseSshJumpHost,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              l.machineEditUseSshJumpHostSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: _sshJumpEnabled,
                            onChanged: (v) =>
                                setState(() => _sshJumpEnabled = v),
                            secondary: const Icon(Icons.hub),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                        if (_sshJumpEnabled) ...[
                          const SizedBox(height: 12),

                          _SectionHeader(title: l.machineEditSshJumpHost),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey('ssh_jump_host_field'),
                                  controller: _sshJumpHostController,
                                  scrollPadding: _fieldScrollPadding(context),
                                  decoration: InputDecoration(
                                    labelText: l.machineEditJumpHost,
                                    hintText: l.machineEditJumpHostHint,
                                    prefixIcon: const Icon(Icons.hub),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('ssh_jump_port_field'),
                                  controller: _sshJumpPortController,
                                  scrollPadding: _fieldScrollPadding(context),
                                  decoration: InputDecoration(
                                    labelText: l.machineEditJumpPort,
                                    hintText: l.machineEditSshPortHint,
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            key: const ValueKey('ssh_jump_username_field'),
                            controller: _sshJumpUsernameController,
                            scrollPadding: _fieldScrollPadding(context),
                            decoration: InputDecoration(
                              labelText: l.machineEditJumpUsername,
                              hintText: l.machineEditJumpUsernameHint,
                              prefixIcon: const Icon(Icons.person_pin),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),

                          _SectionHeader(
                            title: l.machineEditJumpHostAuthentication,
                            subtitle:
                                l.machineEditJumpHostAuthenticationSubtitle,
                          ),
                          const SizedBox(height: 12),

                          SegmentedButton<SshAuthType>(
                            key: const ValueKey('ssh_jump_auth_type_selector'),
                            segments: [
                              ButtonSegment(
                                value: SshAuthType.password,
                                label: Text(l.password),
                                icon: const Icon(Icons.password),
                              ),
                              ButtonSegment(
                                value: SshAuthType.privateKey,
                                label: Text(l.machineEditPrivateKey),
                                icon: const Icon(Icons.vpn_key),
                              ),
                            ],
                            selected: {_sshJumpAuthType},
                            onSelectionChanged: (set) {
                              setState(() => _sshJumpAuthType = set.first);
                            },
                          ),
                          const SizedBox(height: 12),

                          if (_sshJumpAuthType == SshAuthType.password)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (fieldContext) => TextField(
                                    key: const ValueKey(
                                      'ssh_jump_password_field',
                                    ),
                                    controller: _sshJumpPasswordController,
                                    scrollPadding: _fieldScrollPadding(context),
                                    decoration: InputDecoration(
                                      labelText: l.machineEditJumpPassword,
                                      prefixIcon: const Icon(Icons.lock),
                                      border: OutlineInputBorder(),
                                    ),
                                    obscureText: true,
                                    onTap: () =>
                                        _ensureFieldVisible(fieldContext),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                if (_hasExistingSshJumpPassword &&
                                    _sshJumpPasswordController
                                        .text
                                        .isEmpty) ...[
                                  const SizedBox(height: 8),
                                  _SavedCredentialIndicator(
                                    label: l
                                        .machineEditSavedJumpHostPasswordIndicator,
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (fieldContext) => TextField(
                                    key: const ValueKey(
                                      'ssh_jump_private_key_field',
                                    ),
                                    controller: _sshJumpPrivateKeyController,
                                    scrollPadding: _fieldScrollPadding(context),
                                    decoration: InputDecoration(
                                      labelText: l.machineEditJumpPrivateKeyPem,
                                      hintText:
                                          l.machineEditOpenSshPrivateKeyHint,
                                      prefixIcon: const Icon(Icons.vpn_key),
                                      border: OutlineInputBorder(),
                                    ),
                                    maxLines: 4,
                                    onTap: () =>
                                        _ensureFieldVisible(fieldContext),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                if (_hasExistingSshJumpPrivateKey &&
                                    _sshJumpPrivateKeyController
                                        .text
                                        .isEmpty) ...[
                                  const SizedBox(height: 8),
                                  _SavedCredentialIndicator(
                                    label: l
                                        .machineEditSavedJumpHostPrivateKeyIndicator,
                                  ),
                                ],
                              ],
                            ),
                        ],

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
                              _isTesting
                                  ? l.machineEditTesting
                                  : l.machineEditTestConnection,
                            ),
                          ),
                        ),

                        if (_testResult != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _testSuccess
                                  ? appColors.statusOnline.withValues(
                                      alpha: 0.1,
                                    )
                                  : colorScheme.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _testSuccess
                                      ? Icons.check_circle
                                      : Icons.error,
                                  color: _testSuccess
                                      ? appColors.statusOnline
                                      : colorScheme.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _testResult!,
                                    style: TextStyle(
                                      color: _testSuccess
                                          ? appColors.statusOnline
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
                          child: Text(l.cancel),
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
                                      ? l.save
                                      : widget.onSaveAndConnect != null
                                      ? l.machineEditAddAndConnect
                                      : l.add,
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
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  final Widget child;

  const _TileCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SavedCredentialIndicator extends StatelessWidget {
  final String label;

  const _SavedCredentialIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      key: const ValueKey('saved_ssh_private_key_indicator'),
      children: [
        Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
