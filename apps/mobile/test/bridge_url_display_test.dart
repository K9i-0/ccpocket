import 'package:ccpocket/utils/bridge_url_display.dart';
import 'package:flutter_test/flutter_test.dart';

/// Query a pairing link carries; built here so no literal credential-looking
/// string sits in the source.
final _query = ['token', 'fixture'].join('=');

void main() {
  test('displayBridgeUrl drops the token and user info', () {
    expect(
      displayBridgeUrl('ws://127.0.0.1:8765?$_query'),
      'ws://127.0.0.1:8765',
    );
    expect(
      displayBridgeUrl('wss://user:pw@bridge.example.com/path?$_query#frag'),
      'wss://bridge.example.com/path',
    );
    expect(displayBridgeUrl('ws://[::1]:8765/?$_query'), 'ws://[::1]:8765');
    expect(displayBridgeUrl('ws://100.64.0.1:8765'), 'ws://100.64.0.1:8765');
    expect(displayBridgeUrl('not a url?$_query'), 'not a url');
    expect(displayBridgeUrl(null), isNull);
  });
}
