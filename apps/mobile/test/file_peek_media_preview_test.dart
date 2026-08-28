import 'package:ccpocket/features/file_peek/widgets/file_peek_media_preview.dart';
import 'package:ccpocket/features/file_peek/widgets/file_peek_media_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

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

  group('filePeekVideoAspectRatio', () {
    test('uses the declared display aspect ratio', () {
      expect(
        filePeekVideoAspectRatio(const VideoParams(aspect: 4 / 3)),
        closeTo(4 / 3, 0.001),
      );
    });

    test('falls back to display dimensions and then 16:9', () {
      expect(
        filePeekVideoAspectRatio(const VideoParams(dw: 1080, dh: 1920)),
        closeTo(9 / 16, 0.001),
      );
      expect(
        filePeekVideoAspectRatio(const VideoParams()),
        closeTo(16 / 9, 0.001),
      );
    });
  });

  group('filePeekVideoViewportHeight', () {
    test('keeps controls usable on narrow phones', () {
      expect(
        filePeekVideoViewportHeight(
          width: 320,
          aspectRatio: 16 / 9,
          maxHeight: 600,
        ),
        filePeekVideoMinimumViewportHeight,
      );
      expect(
        filePeekVideoViewportHeight(
          width: 393,
          aspectRatio: 16 / 9,
          maxHeight: 600,
        ),
        filePeekVideoMinimumViewportHeight,
      );
    });

    test('uses natural media height and respects the available height', () {
      expect(
        filePeekVideoViewportHeight(
          width: 320,
          aspectRatio: 9 / 16,
          maxHeight: 500,
        ),
        500,
      );
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
