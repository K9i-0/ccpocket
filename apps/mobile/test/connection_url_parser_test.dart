import 'package:ccpocket/services/connection_url_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectionUrlParser.parse', () {
    group('ws:// and wss:// URLs', () {
      test('parses ws:// URL', () {
        final result = ConnectionUrlParser.parse('ws://192.168.1.1:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, isNull);
      });

      test('parses wss:// URL', () {
        final result = ConnectionUrlParser.parse('wss://example.com:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'wss://example.com:8765');
        expect(result.token, isNull);
      });

      test('parses ws:// without port', () {
        final result = ConnectionUrlParser.parse('ws://192.168.1.1');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1');
      });

      test('parses ws:// with path', () {
        final result = ConnectionUrlParser.parse('ws://192.168.1.1:8765/ws');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765/ws');
      });
    });

    group('bare host:port', () {
      test('parses IP:port and prepends ws://', () {
        final result = ConnectionUrlParser.parse('192.168.1.1:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, isNull);
      });

      test('parses hostname:port', () {
        final result = ConnectionUrlParser.parse('my-server:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://my-server:8765');
      });

      test('parses Tailscale IP:port', () {
        final result = ConnectionUrlParser.parse('100.64.0.1:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://100.64.0.1:8765');
      });

      test('parses localhost:port', () {
        final result = ConnectionUrlParser.parse('localhost:8765');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://localhost:8765');
      });
    });

    group('deep link (ccpocket://)', () {
      test('parses deep link with url and token', () {
        final result = ConnectionUrlParser.parse(
          'ccpocket://connect?url=ws://192.168.1.1:8765&token=my-secret',
        );

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
        expect(result.token, 'my-secret');
      });

      test('parses deep link with url only (no token)', () {
        final result = ConnectionUrlParser.parse(
          'ccpocket://connect?url=ws://192.168.1.1:8765',
        );

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
        final result = ConnectionUrlParser.parse(
          'ccpocket://connect?url=',
        );

        expect(result, isNull);
      });

      test('treats empty token as null', () {
        final result = ConnectionUrlParser.parse(
          'ccpocket://connect?url=ws://192.168.1.1:8765&token=',
        );

        expect(result, isNotNull);
        expect(result!.token, isNull);
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
    });

    group('whitespace handling', () {
      test('trims leading and trailing whitespace', () {
        final result = ConnectionUrlParser.parse('  ws://192.168.1.1:8765  ');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
      });

      test('trims bare host:port', () {
        final result = ConnectionUrlParser.parse(' 192.168.1.1:8765 ');

        expect(result, isNotNull);
        expect(result!.serverUrl, 'ws://192.168.1.1:8765');
      });
    });
  });
}
