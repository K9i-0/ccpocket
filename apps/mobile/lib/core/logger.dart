import 'package:talker/talker.dart';

/// Global [Talker] instance shared across the entire app.
///
/// Usage:
/// ```dart
/// import 'package:ccpocket/core/logger.dart';
/// logger.info('message');
/// logger.error('failed', exception, stackTrace);
/// ```
final logger = Talker();
