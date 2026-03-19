import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth troubleshooting docs', () {
    test('Japanese markdown exists with localized guidance', () {
      final file = File('assets/docs/auth-troubleshooting.ja.md');

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('手元に Bridge マシンがない場合'));
      expect(content, contains('ターミナルアプリから Bridge マシンに接続'));
      expect(content, contains('`claude`'));
      expect(content, contains('`/login`'));
    });

    test('English markdown exists with localized guidance', () {
      final file = File('assets/docs/auth-troubleshooting.en.md');

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('If You Are Not Near Your Bridge Machine'));
      expect(
        content,
        contains('Connect to the Bridge machine from a terminal app'),
      );
      expect(content, contains('`claude`'));
      expect(content, contains('`/login`'));
    });

    test('Simplified Chinese markdown exists with localized guidance', () {
      final file = File('assets/docs/auth-troubleshooting.zh-CN.md');

      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content, contains('当你不在 Bridge 机器旁边时'));
      expect(content, contains('用终端应用连接到 Bridge 机器'));
      expect(content, contains('`claude`'));
      expect(content, contains('`/login`'));
    });
  });
}
