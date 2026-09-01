import 'package:ccpocket/models/protocol_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtocolCompatibility', () {
    test('treats a Bridge without metadata as protocol 1', () {
      final compatibility = ProtocolCompatibility.forBridge();

      expect(compatibility.isCompatible, isTrue);
      expect(compatibility.selectedVersion, 1);
      expect(compatibility.assumedLegacyBridge, isTrue);
    });

    test('selects the highest overlapping protocol version', () {
      final compatibility = ProtocolCompatibility.forBridge(
        minimumProtocolVersion: 1,
        protocolVersion: 1,
      );

      expect(compatibility.isCompatible, isTrue);
      expect(compatibility.selectedVersion, 1);
      expect(compatibility.assumedLegacyBridge, isFalse);
    });

    test('rejects a non-overlapping Bridge protocol range', () {
      final compatibility = ProtocolCompatibility.forBridge(
        minimumProtocolVersion: 2,
        protocolVersion: 2,
      );

      expect(compatibility.isCompatible, isFalse);
      expect(compatibility.selectedVersion, isNull);
      expect(compatibility.updateTarget, ProtocolUpdateTarget.app);
    });

    test('rejects malformed Bridge protocol metadata', () {
      final compatibility = ProtocolCompatibility.forBridge(
        minimumProtocolVersion: 1,
      );

      expect(compatibility.isCompatible, isFalse);
      expect(compatibility.malformedBridgeRange, isTrue);
      expect(compatibility.updateTarget, ProtocolUpdateTarget.both);
    });

    test('rejects malformed Bridge JSON declarations fail-closed', () {
      for (final declaration in <Map<String, dynamic>>[
        {'minimumProtocolVersion': 1},
        {'protocolVersion': 0},
        {'protocolVersion': -1},
        {'protocolVersion': 1.0},
        {'protocolVersion': '1'},
        {'minimumProtocolVersion': 2, 'protocolVersion': 1},
      ]) {
        final compatibility = ProtocolCompatibility.fromBridgeJson(declaration);

        expect(
          compatibility.isCompatible,
          isFalse,
          reason: '$declaration must not bypass protocol negotiation',
        );
      }
    });

    test('treats malformed rejection ranges as an update-both failure', () {
      for (final declaration in <Map<String, dynamic>>[
        <String, dynamic>{},
        {'minimumProtocolVersion': 1},
        {'protocolVersion': '2', 'minimumProtocolVersion': 1},
        {'protocolVersion': 1, 'minimumProtocolVersion': 2},
        {'protocolVersion': 0, 'minimumProtocolVersion': 0},
      ]) {
        final compatibility = ProtocolCompatibility.fromBridgeRejectionJson(
          declaration,
        );

        expect(compatibility.isCompatible, isFalse);
        expect(compatibility.malformedBridgeRange, isTrue);
        expect(compatibility.updateTarget, ProtocolUpdateTarget.both);
      }
    });
  });
}
