import 'package:ccpocket/features/session_list/widgets/machine_edit_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestConnectionCall {
  final String host;
  final int sshPort;
  final String username;
  final SshAuthType authType;
  final String? password;
  final String? privateKey;
  final String? jumpHost;
  final int jumpPort;
  final String? jumpUsername;
  final SshAuthType? jumpAuthType;
  final String? jumpPassword;
  final String? jumpPrivateKey;

  const _TestConnectionCall({
    required this.host,
    required this.sshPort,
    required this.username,
    required this.authType,
    required this.password,
    required this.privateKey,
    required this.jumpHost,
    required this.jumpPort,
    required this.jumpUsername,
    required this.jumpAuthType,
    this.jumpPassword,
    this.jumpPrivateKey,
  });
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    Machine? machine,
    void Function(_TestConnectionCall call)? onTestConnectionCall,
    String? existingSshPassword,
    String? existingSshPrivateKey,
    String? existingSshJumpPassword,
    String? existingSshJumpPrivateKey,
    Locale locale = const Locale('en'),
    double keyboardInset = 0,
    required Future<void> Function({
      required Machine machine,
      String? apiKey,
      String? sshPassword,
      String? sshPrivateKey,
      String? sshJumpPassword,
      String? sshJumpPrivateKey,
    })
    onSave,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) {
            final sheet = MachineEditSheet(
              machine: machine,
              existingSshPassword: existingSshPassword,
              existingSshPrivateKey: existingSshPrivateKey,
              existingSshJumpPassword: existingSshJumpPassword,
              existingSshJumpPrivateKey: existingSshJumpPrivateKey,
              onSave: onSave,
              onTestConnection:
                  ({
                    required host,
                    required sshPort,
                    required username,
                    required authType,
                    jumpHost,
                    required jumpPort,
                    jumpUsername,
                    jumpAuthType,
                    jumpPassword,
                    jumpPrivateKey,
                    password,
                    privateKey,
                  }) async {
                    onTestConnectionCall?.call(
                      _TestConnectionCall(
                        host: host,
                        sshPort: sshPort,
                        username: username,
                        authType: authType,
                        password: password,
                        privateKey: privateKey,
                        jumpHost: jumpHost,
                        jumpPort: jumpPort,
                        jumpUsername: jumpUsername,
                        jumpAuthType: jumpAuthType,
                        jumpPassword: jumpPassword,
                        jumpPrivateKey: jumpPrivateKey,
                      ),
                    );
                    return SshResult.success();
                  },
            );

            final body = keyboardInset == 0
                ? sheet
                : MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      viewInsets: EdgeInsets.only(bottom: keyboardInset),
                    ),
                    child: sheet,
                  );

            return Scaffold(body: body);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MachineEditSheet secure connection', () {
    testWidgets('header keyboard button dismisses focused text field', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        machine: const Machine(id: 'm8', host: 'bridge.example.com'),
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      await tester.tap(find.widgetWithText(TextField, 'Name'));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tap(find.byKey(const ValueKey('dismiss_keyboard_button')));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('applies keyboard inset and field scroll padding', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm12',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
        ),
        existingSshPassword: 'target-pw',
        keyboardInset: 320,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      final animatedPadding = tester.widget<AnimatedPadding>(
        find.byKey(const ValueKey('machine_edit_keyboard_avoidance_padding')),
      );
      final padding = animatedPadding.padding as EdgeInsets;
      final expectedBottomInset = 320 / tester.view.devicePixelRatio;
      expect(padding.bottom, expectedBottomInset);

      final jumpPasswordField = tester.widget<TextField>(
        find.byKey(const ValueKey('ssh_jump_password_field')),
      );
      expect(jumpPasswordField.scrollPadding.bottom, greaterThan(320));
    });

    testWidgets('loads existing SSL setting into the toggle', (tester) async {
      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm1',
          host: 'secure.example.com',
          useSsl: true,
        ),
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile).first,
      );
      expect(switchTile.value, isTrue);
    });

    testWidgets('saves useSsl when secure connection is enabled', (
      tester,
    ) async {
      Machine? savedMachine;

      await pumpSheet(
        tester,
        machine: const Machine(id: 'm2', host: 'bridge.example.com'),
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedMachine = machine;
            },
      );

      await tester.tap(find.text('Use secure connection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedMachine, isNotNull);
      expect(savedMachine!.useSsl, isTrue);
      expect(savedMachine!.wsUrl, 'wss://bridge.example.com:8765');
    });
  });

  group('MachineEditSheet SSH jump host', () {
    testWidgets('hides SSH jump host fields until enabled', (tester) async {
      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm5',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
        ),
        existingSshPassword: 'target-pw',
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      expect(find.text('Use SSH jump host'), findsOneWidget);
      expect(find.byKey(const ValueKey('ssh_jump_host_field')), findsNothing);
      expect(find.text('Jump Host Authentication'), findsNothing);

      await tester.tap(find.text('Use SSH jump host'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ssh_jump_host_field')), findsOneWidget);
      expect(find.text('Jump Host Authentication'), findsOneWidget);
    });

    testWidgets('loads and saves SSH jump host fields', (tester) async {
      Machine? savedMachine;
      String? savedSshPassword;
      String? savedSshJumpPassword;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm3',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpPort: 2222,
          sshJumpUsername: 'jump-user',
        ),
        existingSshPassword: 'target-pw',
        existingSshJumpPassword: 'jump-pw',
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedMachine = machine;
              savedSshPassword = sshPassword;
              savedSshJumpPassword = sshJumpPassword;
            },
      );

      expect(find.text('SSH Jump Host'), findsOneWidget);
      expect(find.text('Jump Host Authentication'), findsOneWidget);
      expect(find.text('jump.example.com'), findsOneWidget);
      expect(find.text('2222'), findsOneWidget);
      expect(find.text('jump-user'), findsOneWidget);
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('ssh_jump_toggle')),
            )
            .value,
        isTrue,
      );
      expect(find.text('jump-pw'), findsNothing);
      expect(
        find.text(
          'Jump host password is saved. Enter a new one to replace it.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedMachine, isNotNull);
      expect(savedMachine!.sshJumpHost, 'jump.example.com');
      expect(savedMachine!.sshJumpPort, 2222);
      expect(savedMachine!.sshJumpUsername, 'jump-user');
      expect(savedMachine!.sshJumpAuthType, SshAuthType.password);
      expect(savedSshPassword, 'target-pw');
      expect(savedSshJumpPassword, isNull);
    });

    testWidgets('passes SSH jump host fields to Test Connection', (
      tester,
    ) async {
      _TestConnectionCall? call;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm4',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpPort: 2222,
          sshJumpUsername: 'jump-user',
        ),
        existingSshPassword: 'target-pw',
        existingSshJumpPassword: 'jump-pw',
        onTestConnectionCall: (value) => call = value,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(call, isNotNull);
      expect(call!.host, 'target.internal');
      expect(call!.sshPort, 22);
      expect(call!.username, 'target-user');
      expect(call!.jumpHost, 'jump.example.com');
      expect(call!.jumpPort, 2222);
      expect(call!.jumpUsername, 'jump-user');
      expect(call!.jumpAuthType, SshAuthType.password);
      expect(call!.jumpPassword, 'jump-pw');
    });

    testWidgets('normalizes IPv6 hosts for SSH test and save', (tester) async {
      _TestConnectionCall? call;
      Machine? savedMachine;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm-ipv6',
          host: '[fe80::1%25en0]',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: '[fe80::2%25en0]',
          sshJumpUsername: 'jump-user',
        ),
        existingSshPassword: 'target-pw',
        existingSshJumpPassword: 'jump-pw',
        onTestConnectionCall: (value) => call = value,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedMachine = machine;
            },
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();
      expect(call?.host, 'fe80::1%en0');
      expect(call?.jumpHost, 'fe80::2%en0');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedMachine?.host, 'fe80::1%en0');
      expect(savedMachine?.sshJumpHost, 'fe80::2%en0');
    });

    testWidgets('replaces saved SSH jump host password only when entered', (
      tester,
    ) async {
      String? savedSshJumpPassword;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm9',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
        ),
        existingSshPassword: 'target-pw',
        existingSshJumpPassword: 'jump-pw',
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedSshJumpPassword = sshJumpPassword;
            },
      );

      await tester.enterText(
        find.byKey(const ValueKey('ssh_jump_password_field')),
        'new-jump-pw',
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Jump host password is saved. Enter a new one to replace it.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedSshJumpPassword, 'new-jump-pw');
    });

    testWidgets('shows saved SSH jump host private key without displaying it', (
      tester,
    ) async {
      _TestConnectionCall? call;
      String? savedSshJumpPrivateKey;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm10',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
          sshJumpAuthType: SshAuthType.privateKey,
        ),
        existingSshPassword: 'target-pw',
        existingSshJumpPrivateKey: 'saved-jump-private-key',
        onTestConnectionCall: (value) => call = value,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedSshJumpPrivateKey = sshJumpPrivateKey;
            },
      );

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('ssh_jump_toggle')),
            )
            .value,
        isTrue,
      );
      expect(find.text('saved-jump-private-key'), findsNothing);
      expect(
        find.text(
          'Jump host private key is saved. Enter a new one to replace it.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(call, isNotNull);
      expect(call!.jumpAuthType, SshAuthType.privateKey);
      expect(call!.jumpPrivateKey, 'saved-jump-private-key');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedSshJumpPrivateKey, isNull);
    });

    testWidgets('localizes saved private key indicators', (tester) async {
      await pumpSheet(
        tester,
        locale: const Locale('ja'),
        machine: const Machine(
          id: 'm11',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshAuthType: SshAuthType.privateKey,
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
          sshJumpAuthType: SshAuthType.privateKey,
        ),
        existingSshPrivateKey: 'saved-private-key',
        existingSshJumpPrivateKey: 'saved-jump-private-key',
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {},
      );

      expect(find.text('マシンを編集'), findsOneWidget);
      expect(find.text('saved-private-key'), findsNothing);
      expect(find.text('saved-jump-private-key'), findsNothing);
      expect(find.text('Private Key は保存済みです。新しく入力すると置き換えます。'), findsOneWidget);
      expect(
        find.text('Jump Host Private Key は保存済みです。新しく入力すると置き換えます。'),
        findsOneWidget,
      );
    });

    testWidgets('uses saved private key without displaying it', (tester) async {
      _TestConnectionCall? call;
      Machine? savedMachine;
      String? savedSshPrivateKey;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm6',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshAuthType: SshAuthType.privateKey,
        ),
        existingSshPrivateKey: 'saved-private-key',
        onTestConnectionCall: (value) => call = value,
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedMachine = machine;
              savedSshPrivateKey = sshPrivateKey;
            },
      );

      expect(find.text('saved-private-key'), findsNothing);
      expect(
        find.text('Private key is saved. Enter a new one to replace it.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Test Connection'));
      await tester.pumpAndSettle();

      expect(call, isNotNull);
      expect(call!.authType, SshAuthType.privateKey);
      expect(call!.privateKey, 'saved-private-key');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedMachine, isNotNull);
      expect(savedMachine!.sshAuthType, SshAuthType.privateKey);
      expect(savedSshPrivateKey, isNull);
    });

    testWidgets('replaces saved private key only when a new key is entered', (
      tester,
    ) async {
      String? savedSshPrivateKey;

      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm7',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshAuthType: SshAuthType.privateKey,
        ),
        existingSshPrivateKey: 'saved-private-key',
        onSave:
            ({
              required machine,
              apiKey,
              sshPassword,
              sshPrivateKey,
              sshJumpPassword,
              sshJumpPrivateKey,
            }) async {
              savedSshPrivateKey = sshPrivateKey;
            },
      );

      await tester.enterText(
        find.byKey(const ValueKey('ssh_private_key_field')),
        'replacement-private-key',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Private key is saved. Enter a new one to replace it.'),
        findsNothing,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedSshPrivateKey, 'replacement-private-key');
    });
  });
}
