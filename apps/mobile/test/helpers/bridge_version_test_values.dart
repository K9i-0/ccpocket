import 'package:ccpocket/constants/app_constants.dart';

String get recommendedBridgeVersion => AppConstants.expectedBridgeVersion;

String get olderThanRecommendedBridgeVersion {
  final parts = recommendedBridgeVersion.split('.').map(int.parse).toList();
  final major = parts[0];
  final minor = parts[1];
  final patch = parts[2];

  if (patch > 0) {
    return '$major.$minor.${patch - 1}';
  }
  if (minor > 0) {
    return '$major.${minor - 1}.999';
  }
  if (major > 0) {
    return '${major - 1}.999.999';
  }

  throw StateError(
    'Cannot create an older version for $recommendedBridgeVersion',
  );
}

String get newerThanRecommendedBridgeVersion {
  final parts = recommendedBridgeVersion.split('.').map(int.parse).toList();
  return '${parts[0]}.${parts[1]}.${parts[2] + 1}';
}
