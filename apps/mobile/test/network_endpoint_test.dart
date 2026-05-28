import 'package:ccpocket/utils/network_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('network endpoint formatting', () {
    test('keeps IPv4 and DNS hosts unchanged', () {
      expect(formatHostPort('192.168.1.1', 9000), '192.168.1.1:9000');
      expect(
        formatHostPort('bridge.example.com', 9000),
        'bridge.example.com:9000',
      );
    });

    test('wraps IPv6 hosts for URL authorities', () {
      expect(
        formatHostPort('fdbd:dc01:ff:321:254e:39ac:2d5d:1a67', 19000),
        '[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]:19000',
      );
      expect(
        formatUriOrigin(
          scheme: 'ws',
          host: 'fdbd:dc01:ff:321:254e:39ac:2d5d:1a67',
          port: 19000,
        ),
        'ws://[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]:19000',
      );
    });

    test('does not double-wrap bracketed IPv6 hosts', () {
      expect(
        formatHostPort('[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]', 19000),
        '[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]:19000',
      );
    });

    test('normalizes bracketed IPv6 input for storage and lookup', () {
      expect(
        normalizeHostInput('[fdbd:dc01:ff:321:254e:39ac:2d5d:1a67]'),
        'fdbd:dc01:ff:321:254e:39ac:2d5d:1a67',
      );
      expect(normalizeHostInput(' bridge.example.com '), 'bridge.example.com');
    });
  });
}
