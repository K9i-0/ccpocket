const appProtocolMinVersion = 1;
const appProtocolMaxVersion = 1;
const legacyBridgeProtocolVersion = 1;
const bridgeStableMajorSetupCommand = 'npx --yes @ccpocket/bridge@1 setup';

enum ProtocolUpdateTarget { app, bridge, both }

class ProtocolCompatibility {
  final int bridgeMinVersion;
  final int bridgeMaxVersion;
  final int? selectedVersion;
  final bool assumedLegacyBridge;
  final bool malformedBridgeRange;

  const ProtocolCompatibility._({
    required this.bridgeMinVersion,
    required this.bridgeMaxVersion,
    required this.selectedVersion,
    required this.assumedLegacyBridge,
    required this.malformedBridgeRange,
  });

  bool get isCompatible => selectedVersion != null;

  ProtocolUpdateTarget get updateTarget {
    if (malformedBridgeRange || bridgeMinVersion < 1 || bridgeMaxVersion < 1) {
      return ProtocolUpdateTarget.both;
    }
    if (bridgeMinVersion > appProtocolMaxVersion) {
      return ProtocolUpdateTarget.app;
    }
    if (appProtocolMinVersion > bridgeMaxVersion) {
      return ProtocolUpdateTarget.bridge;
    }
    return ProtocolUpdateTarget.both;
  }

  factory ProtocolCompatibility.rejectedByBridge({
    int? minimumProtocolVersion,
    int? protocolVersion,
  }) {
    final malformed =
        minimumProtocolVersion == null ||
        protocolVersion == null ||
        minimumProtocolVersion < 1 ||
        protocolVersion < 1 ||
        minimumProtocolVersion > protocolVersion;
    return ProtocolCompatibility._(
      bridgeMinVersion: minimumProtocolVersion ?? 0,
      bridgeMaxVersion: protocolVersion ?? 0,
      selectedVersion: null,
      assumedLegacyBridge: false,
      malformedBridgeRange: malformed,
    );
  }

  factory ProtocolCompatibility.fromBridgeRejectionJson(
    Map<String, dynamic> json,
  ) {
    final rawMinimum = json['minimumProtocolVersion'];
    final rawMaximum = json['protocolVersion'];
    if (rawMinimum is! int || rawMaximum is! int) {
      return ProtocolCompatibility._(
        bridgeMinVersion: rawMinimum is int ? rawMinimum : 0,
        bridgeMaxVersion: rawMaximum is int ? rawMaximum : 0,
        selectedVersion: null,
        assumedLegacyBridge: false,
        malformedBridgeRange: true,
      );
    }
    return ProtocolCompatibility.rejectedByBridge(
      minimumProtocolVersion: rawMinimum,
      protocolVersion: rawMaximum,
    );
  }

  factory ProtocolCompatibility.fromBridgeJson(Map<String, dynamic> json) {
    final hasMinimum = json.containsKey('minimumProtocolVersion');
    final hasMaximum = json.containsKey('protocolVersion');
    if (!hasMinimum && !hasMaximum) {
      return ProtocolCompatibility.forBridge();
    }

    final rawMinimum = json['minimumProtocolVersion'];
    final rawMaximum = json['protocolVersion'];
    final malformed =
        (hasMinimum && rawMinimum is! int) ||
        (hasMaximum && rawMaximum is! int) ||
        (hasMinimum && !hasMaximum);
    if (malformed) {
      return ProtocolCompatibility._(
        bridgeMinVersion: rawMinimum is int ? rawMinimum : 0,
        bridgeMaxVersion: rawMaximum is int ? rawMaximum : 0,
        selectedVersion: null,
        assumedLegacyBridge: false,
        malformedBridgeRange: true,
      );
    }

    return ProtocolCompatibility.forBridge(
      minimumProtocolVersion: rawMinimum as int?,
      protocolVersion: rawMaximum as int?,
    );
  }

  factory ProtocolCompatibility.forBridge({
    int? minimumProtocolVersion,
    int? protocolVersion,
  }) {
    final assumedLegacy =
        minimumProtocolVersion == null && protocolVersion == null;
    final malformed =
        (minimumProtocolVersion != null && protocolVersion == null) ||
        (minimumProtocolVersion != null && minimumProtocolVersion < 1) ||
        (protocolVersion != null && protocolVersion < 1) ||
        (minimumProtocolVersion != null &&
            protocolVersion != null &&
            minimumProtocolVersion > protocolVersion);
    final bridgeMax = protocolVersion ?? legacyBridgeProtocolVersion;
    final bridgeMin =
        minimumProtocolVersion ??
        (protocolVersion ?? legacyBridgeProtocolVersion);
    final lowerBound = bridgeMin > appProtocolMinVersion
        ? bridgeMin
        : appProtocolMinVersion;
    final upperBound = bridgeMax < appProtocolMaxVersion
        ? bridgeMax
        : appProtocolMaxVersion;

    return ProtocolCompatibility._(
      bridgeMinVersion: bridgeMin,
      bridgeMaxVersion: bridgeMax,
      selectedVersion: !malformed && lowerBound <= upperBound
          ? upperBound
          : null,
      assumedLegacyBridge: assumedLegacy,
      malformedBridgeRange: malformed,
    );
  }
}
