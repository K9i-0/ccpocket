import 'package:ccpocket/features/session_list/widgets/machine_edit_sheet.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestConnectionCall {
  final String host;
  final int sshPort;
  final String username;
  final String? jumpHost;
  final int jumpPort;
  final String? jumpUsername;

  const _TestConnectionCall({
    required this.host,
    required this.sshPort,
    required this.username,
    required this.jumpHost,
    required this.jumpPort,
    required this.jumpUsername,
  });
}

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    Machine? machine,
    void Function(_TestConnectionCall call)? onTestConnectionCall,
    String? existingSshPassword,
    required Future<void> Function({
      required Machine machine,
      String? apiKey,
      String? sshPassword,
      String? sshPrivateKey,
    })
    onSave,
  }) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MachineEditSheet(
            machine: machine,
            existingSshPassword: existingSshPassword,
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
                  password,
                  privateKey,
                }) async {
                  onTestConnectionCall?.call(
                    _TestConnectionCall(
                      host: host,
                      sshPort: sshPort,
                      username: username,
                      jumpHost: jumpHost,
                      jumpPort: jumpPort,
                      jumpUsername: jumpUsername,
                    ),
                  );
                  return SshResult.success();
                },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('MachineEditSheet secure connection', () {
    testWidgets('loads existing SSL setting into the toggle', (tester) async {
      await pumpSheet(
        tester,
        machine: const Machine(
          id: 'm1',
          host: 'secure.example.com',
          useSsl: true,
        ),
        onSave:
            ({required machine, apiKey, sshPassword, sshPrivateKey}) async {},
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
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
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
    testWidgets('loads and saves SSH jump host fields', (tester) async {
      Machine? savedMachine;

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
        onSave: ({required machine, apiKey, sshPassword, sshPrivateKey}) async {
          savedMachine = machine;
        },
      );

      expect(find.text('SSH Jump Host'), findsOneWidget);
      expect(find.text('jump.example.com'), findsOneWidget);
      expect(find.text('2222'), findsOneWidget);
      expect(find.text('jump-user'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedMachine, isNotNull);
      expect(savedMachine!.sshJumpHost, 'jump.example.com');
      expect(savedMachine!.sshJumpPort, 2222);
      expect(savedMachine!.sshJumpUsername, 'jump-user');
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
        existingSshPassword: 'pw',
        onTestConnectionCall: (value) => call = value,
        onSave:
            ({required machine, apiKey, sshPassword, sshPrivateKey}) async {},
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
    });
  });
}
