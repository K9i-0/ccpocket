import 'package:ccpocket/services/connection_url_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionUrlParser.parse', () {
    group('ws:// and wss:// URLs', () {
      test('parses ws:// URL', () {
        final result =
            ConnectionUrlParser.parse('ws://192.168.1.1:8765')
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, isNull);
      });

      test('parses wss:// URL', () {
        final result =
            ConnectionUrlParser.parse('wss://example.com:8765')
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'wss://example.com:8765');
        expect(result.token, isNull);
      });

      test('parses ws:// without port', () {
        final result =
            ConnectionUrlParser.parse('ws://192.168.1.1') as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1');
      });

      test('parses ws:// with path', () {
        final result =
            ConnectionUrlParser.parse('ws://192.168.1.1:8765/ws')
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765/ws');
      });
    });

    group('bare host:port', () {
      test('parses IP:port and prepends ws://', () {
        final result =
            ConnectionUrlParser.parse('192.168.1.1:8765') as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, isNull);
      });

      test('parses hostname:port', () {
        final result =
            ConnectionUrlParser.parse('my-server:8765') as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://my-server:8765');
      });

      test('parses Tailscale IP:port', () {
        final result =
            ConnectionUrlParser.parse('100.64.0.1:8765') as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://100.64.0.1:8765');
      });

      test('parses localhost:port', () {
        final result =
            ConnectionUrlParser.parse('localhost:8765') as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://localhost:8765');
      });
    });

    group('deep link - connect (ccpocket://connect)', () {
      test('parses deep link with url and token', () {
        final result =
            ConnectionUrlParser.parse(
                  'ccpocket://connect?url=ws://192.168.1.1:8765&token=my-secret',
                )
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, 'my-secret');
      });

      test('parses deep link with url only (no token)', () {
        final result =
            ConnectionUrlParser.parse(
                  'ccpocket://connect?url=ws://192.168.1.1:8765',
                )
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, isNull);
      });

      test('returns null for deep link without url param', () {
        final result = ConnectionUrlParser.parse(
          'ccpocket://connect?token=my-secret',
        );

        expect(result, isNull);
      });

      test('returns null for deep link with empty url param', () {
        final result = ConnectionUrlParser.parse('ccpocket://connect?url=');

        expect(result, isNull);
      });

      test('treats empty token as null', () {
        final result =
            ConnectionUrlParser.parse(
                  'ccpocket://connect?url=ws://192.168.1.1:8765&token=',
                )
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.token, isNull);
      });
    });

    group('deep link - session (ccpocket://session)', () {
      test('parses session link with sessionId', () {
        final result =
            ConnectionUrlParser.parse('ccpocket://session/abc-123-def')
                as SessionLinkParams?;

        expect(result, isNotNull);
        expect(result!.sessionId, 'abc-123-def');
      });

      test('parses session link with UUID sessionId', () {
        final result =
            ConnectionUrlParser.parse(
                  'ccpocket://session/550e8400-e29b-41d4-a716-446655440000',
                )
                as SessionLinkParams?;

        expect(result, isNotNull);
        expect(result!.sessionId, '550e8400-e29b-41d4-a716-446655440000');
      });

      test('returns null for session link without sessionId', () {
        final result = ConnectionUrlParser.parse('ccpocket://session/');

        expect(result, isNull);
      });

      test('returns null for session link with empty path', () {
        final result = ConnectionUrlParser.parse('ccpocket://session');

        expect(result, isNull);
      });

      test('returns correct type for session vs connect', () {
        final sessionResult = ConnectionUrlParser.parse(
          'ccpocket://session/abc',
        );
        final connectResult = ConnectionUrlParser.parse(
          'ccpocket://connect?url=ws://localhost:8765',
        );

        expect(sessionResult, isA<SessionLinkParams>());
        expect(connectResult, isA<ConnectionParams>());
      });
    });

    group('invalid inputs', () {
      test('returns null for empty string', () {
        expect(ConnectionUrlParser.parse(''), isNull);
      });

      test('returns null for whitespace only', () {
        expect(ConnectionUrlParser.parse('   '), isNull);
      });

      test('returns null for http:// URL', () {
        expect(ConnectionUrlParser.parse('http://example.com:8765'), isNull);
      });

      test('returns null for https:// URL', () {
        expect(ConnectionUrlParser.parse('https://example.com:8765'), isNull);
      });

      test('returns null for bare hostname without port', () {
        expect(ConnectionUrlParser.parse('my-server'), isNull);
      });

      test('returns null for bare IP without port', () {
        expect(ConnectionUrlParser.parse('192.168.1.1'), isNull);
      });

      test('returns null for random text', () {
        expect(ConnectionUrlParser.parse('not a url at all'), isNull);
      });

      test('returns null for unknown ccpocket host', () {
        expect(ConnectionUrlParser.parse('ccpocket://unknown/path'), isNull);
      });
    });

    group('whitespace handling', () {
      test('trims leading and trailing whitespace', () {
        final result =
            ConnectionUrlParser.parse('  ws://192.168.1.1:8765  ')
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
      });

      test('trims bare host:port', () {
        final result =
            ConnectionUrlParser.parse(' 192.168.1.1:8765 ')
                as ConnectionParams?;

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
      });
    });
  });
}
