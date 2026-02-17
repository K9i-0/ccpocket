import 'dart:io';

/// Utility to discover and load recording files from the file system.
class RecordingLoader {
  RecordingLoader({String? recordingDir})
    : _recordingDir =
          recordingDir ??
          '${Platform.environment['HOME'] ?? '/tmp'}/.ccpocket/debug/recordings';

  final String _recordingDir;

  /// List available recording files, sorted by modification time (newest first).
  Future<List<RecordingFileInfo>> listRecordings() async {
    final dir = Directory(_recordingDir);
    if (!await dir.exists()) return [];

    final files = <RecordingFileInfo>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        final stat = await entity.stat();
        // Extract filename without extension
        final fullName = entity.uri.pathSegments.last;
        final name = fullName.endsWith('.jsonl')
            ? fullName.substring(0, fullName.length - 6)
            : fullName;
        files.add(
          RecordingFileInfo(
            path: entity.path,
            name: name,
            modified: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }
    }

    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  /// Load a recording file as a list of lines.
  Future<List<String>> loadLines(String path) async {
    final file = File(path);
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return content.split('\n');
  }
}

/// Information about a recording file.
class RecordingFileInfo {
  const RecordingFileInfo({
    required this.path,
    required this.name,
    required this.modified,
    required this.sizeBytes,
  });

  final String path;
  final String name;
  final DateTime modified;
  final int sizeBytes;

  /// Human-readable file size.
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
