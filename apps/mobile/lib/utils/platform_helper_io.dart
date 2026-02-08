import 'dart:io';

/// Returns the home directory path from environment variable.
String getHomeDirectory() => Platform.environment['HOME'] ?? '';
