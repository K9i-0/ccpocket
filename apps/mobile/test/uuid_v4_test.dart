import 'dart:math';

import 'package:ccpocket/utils/uuid_v4.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value != 0;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  final uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  group('generateUuidV4', () {
    test('produces RFC 4122 version 4 UUIDs', () {
      for (var i = 0; i < 200; i++) {
        final id = generateUuidV4();
        expect(id, hasLength(36));
        expect(uuidV4Pattern.hasMatch(id), isTrue, reason: 'Invalid UUID: $id');
      }
    });

    test('generates unique values across repeated calls', () {
      final ids = {for (var i = 0; i < 200; i++) generateUuidV4()};
      expect(ids, hasLength(200));
    });

    test('enforces version 4 and RFC 4122 variant bits for extreme bytes', () {
      expect(
        generateUuidV4(_FixedRandom(0x00)),
        '00000000-0000-4000-8000-000000000000',
      );
      expect(
        generateUuidV4(_FixedRandom(0xff)),
        'ffffffff-ffff-4fff-bfff-ffffffffffff',
      );
    });
  });
}
