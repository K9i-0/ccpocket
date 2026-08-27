import 'package:ccpocket/features/file_peek/widgets/file_peek_media_preview.dart';
import 'package:ccpocket/features/file_peek/widgets/file_peek_media_controls.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveFilePeekMediaUrl', () {
    test('resolves Bridge-relative capability URLs', () {
      expect(
        resolveFilePeekMediaUrl('http://localhost:8765', '/api/media/abc123'),
        'http://localhost:8765/api/media/abc123',
      );
    });

    test('preserves absolute HTTP media URLs', () {
      expect(
        resolveFilePeekMediaUrl(null, 'https://example.com/video.mp4'),
        'https://example.com/video.mp4',
      );
    });

    test('rejects unsupported and unresolved URLs', () {
      expect(resolveFilePeekMediaUrl(null, '/api/media/abc123'), isNull);
      expect(
        resolveFilePeekMediaUrl('http://localhost:8765', 'file:///tmp/a.mp4'),
        isNull,
      );
    });
  });

  group('isFatalFilePeekMediaError', () {
    test('ignores the headless audio-device warning', () {
      expect(
        isFatalFilePeekMediaError(
          'Could not open/initialize audio device -> no sound.',
        ),
        isFalse,
      );
    });

    test('keeps ordinary playback errors fatal', () {
      expect(isFatalFilePeekMediaError('HTTP 404'), isTrue);
    });
  });

  group('file peek media controls', () {
    test('clamps relative seeks to the media bounds', () {
      expect(
        filePeekSeekTarget(
          position: const Duration(seconds: 4),
          duration: const Duration(seconds: 60),
          offset: const Duration(seconds: -10),
        ),
        Duration.zero,
      );
      expect(
        filePeekSeekTarget(
          position: const Duration(seconds: 55),
          duration: const Duration(seconds: 60),
          offset: const Duration(seconds: 10),
        ),
        const Duration(seconds: 60),
      );
    });

    test('formats short and long playback durations', () {
      expect(formatFilePeekMediaDuration(const Duration(seconds: 65)), '1:05');
      expect(
        formatFilePeekMediaDuration(const Duration(hours: 2, seconds: 5)),
        '2:00:05',
      );
    });

    test('offers the supported playback rates', () {
      expect(filePeekPlaybackRates, [0.5, 1.0, 1.5, 2.0]);
    });
  });
}
