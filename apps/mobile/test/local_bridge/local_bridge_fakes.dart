import 'dart:convert';

import 'package:ccpocket/features/local_bridge/data/local_bridge_client.dart';
import 'package:ccpocket/features/local_bridge/data/local_bridge_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const pairingFixture = 'fixture-pairing-value';

/// In-memory Bridge that answers the local management API.
class FakeLocalBridge {
  bool running = true;
  bool hasSecret = true;
  bool adminSupported = true;
  bool toolsSupported = true;
  bool supervised = true;
  String apiKeySource = 'stored';
  int pid = 100;
  Map<String, Object?> fileSettings = {};
  Map<String, Object?> loadedSettings = {};
  Map<String, String> envSettings = {'port': '8765'};
  Map<String, String> rejectSettings = {};
  final requests = <http.Request>[];

  bool get restartRequired =>
      jsonEncode(fileSettings) != jsonEncode(loadedSettings);

  LocalBridgeClient client(int port) => LocalBridgeClient(
    port: port,
    httpClient: MockClient(_handle),
    readPairingSecret: (_) async => hasSecret ? pairingFixture : null,
    timeout: const Duration(seconds: 1),
  );

  http.Response _json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Map<String, Object?> _setting(String key, String type, Object? fallback) {
    final env = envSettings.containsKey(key);
    return {
      'key': key,
      'env': 'BRIDGE_${key.toUpperCase()}',
      'type': type,
      'source': env
          ? 'env'
          : loadedSettings.containsKey(key)
          ? 'file'
          : 'default',
      'value': type == 'secret'
          ? null
          : env
          ? int.tryParse(envSettings[key]!) ?? envSettings[key]
          : loadedSettings[key] ?? fallback,
      'fileValue': type == 'secret' ? null : fileSettings[key],
      if (type == 'secret') 'configured': loadedSettings.containsKey(key),
      if (type == 'secret') 'fileConfigured': fileSettings.containsKey(key),
      if (type == 'enum') 'values': ['private', 'managed', 'external'],
    };
  }

  Map<String, Object?> _config() => {
    'version': 1,
    'path': '/home/u/.ccpocket/bridge-config.json',
    'restartRequired': restartRequired,
    'settings': [
      _setting('port', 'port', 8765),
      _setting('host', 'string', '0.0.0.0'),
      _setting('allowedDirs', 'dirs', ['/home/u']),
      _setting('allowClaudeOAuth', 'boolean', false),
      _setting('codexAppServerMode', 'enum', 'private'),
      _setting('antigravityApiKey', 'secret', null),
    ],
  };

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    if (!running) throw http.ClientException('Connection refused');
    final path = request.url.path;
    if (path == '/health') return _json({'status': 'ok'});
    if (path == '/tools') {
      if (!toolsSupported) return http.Response('Not Found', 404);
      if (request.headers['Authorization'] != 'Bearer fixture-api-key') {
        return _json({'error': 'unauthorized'}, 401);
      }
      return _json({
        'platform': 'darwin',
        'ready': false,
        'tools': [
          {
            'id': 'node',
            'name': 'Node.js',
            'requirement': 'required',
            'installed': true,
            'ready': true,
            'version': 'v24.1.0',
            'installCommands': [
              {'label': 'Homebrew', 'command': 'brew install node'},
            ],
            'docsUrl': 'https://nodejs.org/en/download',
          },
          {
            'id': 'codex',
            'name': 'Codex',
            'requirement': 'agent',
            'installed': true,
            'ready': false,
            'message': 'Not authenticated',
            'setupCommand': 'codex login',
            'installCommands': [
              {'label': 'npm', 'command': 'npm install -g @openai/codex'},
            ],
            'docsUrl': 'https://github.com/openai/codex',
          },
          {
            'id': 'antigravity',
            'name': 'Antigravity',
            'requirement': 'agent',
            'installed': false,
            'ready': false,
            'installCommands': <Object>[],
            'docsUrl': 'https://antigravity.google/docs/install/',
          },
        ],
      });
    }
    if (request.headers[LocalBridgeClient.pairingSecretHeader] !=
        pairingFixture) {
      return http.Response('Forbidden', 403);
    }
    if (path == '/pairing') {
      return _json({
        'auth': 'required',
        'token': 'fixture-api-key',
        'connections': [
          {
            'label': 'Tailscale',
            'wsUrl': 'ws://100.64.0.1:8765',
            'deepLink': 'ccpocket://connect?url=ws%3A%2F%2F100.64.0.1%3A8765',
          },
          {
            'label': 'LAN',
            'wsUrl': 'ws://192.168.1.5:8765',
            'deepLink': 'ccpocket://connect?url=ws%3A%2F%2F192.168.1.5%3A8765',
          },
        ],
      });
    }
    if (!adminSupported) return http.Response('Not Found', 404);
    switch ('${request.method} $path') {
      case 'GET /admin/status':
        return _json({
          'adminApiVersion': 1,
          'version': '1.120.0',
          'port': request.url.port,
          'pid': pid,
          'supervised': supervised,
          'apiKeySource': apiKeySource,
          'restartRequired': restartRequired,
          'sessions': 2,
          'clients': 1,
        });
      case 'GET /admin/config':
        return _json(_config());
      case 'PUT /admin/config':
        if (rejectSettings.isNotEmpty) {
          return _json({
            'error': 'invalid_settings',
            'errors': rejectSettings,
          }, 400);
        }
        final patch =
            (jsonDecode(request.body) as Map)['settings']
                as Map<String, Object?>;
        fileSettings = {...fileSettings, ...patch}
          ..removeWhere((_, value) => value == null);
        return _json(_config());
      case 'POST /admin/restart':
        if (!supervised) return _json({'error': 'not_supervised'}, 409);
        pid += 1;
        loadedSettings = {...fileSettings};
        return _json({'restarting': true}, 202);
      case 'POST /admin/api-key/rotate':
        if (apiKeySource == 'configured') {
          return _json({'error': 'api_key_configured'}, 409);
        }
        return _json({'restartRequired': true});
      case 'GET /admin/logs':
        return _json({
          'entries': [
            {'time': 1000, 'level': 'warn', 'message': 'careful'},
          ],
        });
    }
    return _json({'error': 'not_found'}, 404);
  }
}

/// Launcher that starts and stops a [FakeLocalBridge].
class FakeLauncher implements LocalBridgeLauncher {
  FakeLauncher(this.bridge, {this.available = true});

  final FakeLocalBridge bridge;
  bool available;
  LauncherRegistration registration = LauncherRegistration.notRegistered;

  /// What registering leads to instead of a running Bridge.
  LauncherStatus? problemOnStart;
  bool approvalRequired = false;
  int? savedPort;
  LauncherStatus? status;
  final actions = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<int?> configuredPort() async => savedPort;

  @override
  Future<LauncherStatus?> readStatus() async => status;

  @override
  Future<LauncherResult> run(String action) async {
    actions.add(action);
    if (action == 'register') {
      if (approvalRequired) {
        registration = LauncherRegistration.requiresApproval;
        return LauncherResult(ok: false, registration: registration);
      }
      registration = LauncherRegistration.enabled;
      if (problemOnStart != null) {
        status = problemOnStart;
      } else {
        bridge.running = true;
      }
    } else if (action == 'unregister') {
      registration = LauncherRegistration.notRegistered;
      bridge.running = false;
    }
    return LauncherResult(ok: true, registration: registration);
  }
}
