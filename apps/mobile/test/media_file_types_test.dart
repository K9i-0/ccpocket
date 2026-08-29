import 'package:ccpocket/utils/media_file_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mediaFileTypeForPath', () {
    test('recognizes supported audio formats case-insensitively', () {
      for (final entry in const {
        'wav': 'audio/wav',
        'mp3': 'audio/mpeg',
        'm4a': 'audio/mp4',
        'aac': 'audio/aac',
        'flac': 'audio/flac',
        'ogg': 'audio/ogg',
        'opus': 'audio/ogg',
        'aif': 'audio/aiff',
        'aiff': 'audio/aiff',
        'aifc': 'audio/aiff',
      }.entries) {
        final media = mediaFileTypeForPath(
          'audio/sample.${entry.key.toUpperCase()}',
        );
        expect(media?.kind, MediaFileKind.audio, reason: entry.key);
        expect(media?.mimeType, entry.value, reason: entry.key);
      }
    });

    test('recognizes supported video formats case-insensitively', () {
      for (final entry in const {
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        'webm': 'video/webm',
        'mkv': 'video/x-matroska',
        'avi': 'video/x-msvideo',
        'mpg': 'video/mpeg',
        'mpeg': 'video/mpeg',
      }.entries) {
        final media = mediaFileTypeForPath(
          'video/sample.${entry.key.toUpperCase()}',
        );
        expect(media?.kind, MediaFileKind.video, reason: entry.key);
        expect(media?.mimeType, entry.value, reason: entry.key);
      }
    });

    test('handles Windows paths and rejects unsupported files', () {
      expect(
        mediaFileTypeForPath(r'C:\outputs\voice.mp3')?.mimeType,
        'audio/mpeg',
      );
      expect(mediaFileTypeForPath('README.md'), isNull);
      expect(mediaFileTypeForPath('extensionless'), isNull);
      expect(mediaFileTypeForPath('.mp3'), isNull);
    });

    test('extracts the normalized extension for display', () {
      expect(mediaFileExtensionForPath('audio/Track.MP3'), 'mp3');
      expect(mediaFileExtensionForPath(r'C:\audio\voice.M4A'), 'm4a');
      expect(mediaFileExtensionForPath('README'), isNull);
    });
  });
}
