import 'package:ccpocket/widgets/file_type_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fileVisualKindForPath', () {
    test('distinguishes common media file types case-insensitively', () {
      expect(
        fileVisualKindForPath('renders/preview.MP4'),
        FileVisualKind.video,
      );
      expect(
        fileVisualKindForPath('audio/voice_ref.wav'),
        FileVisualKind.audio,
      );
      expect(fileVisualKindForPath('assets/cover.webp'), FileVisualKind.image);
    });

    test('classifies developer files and special file names', () {
      expect(fileVisualKindForPath('lib/main.dart'), FileVisualKind.source);
      expect(fileVisualKindForPath('scripts/build.sh'), FileVisualKind.shell);
      expect(fileVisualKindForPath('Dockerfile'), FileVisualKind.shell);
      expect(fileVisualKindForPath('.gitignore'), FileVisualKind.data);
      expect(fileVisualKindForPath('pubspec.yaml'), FileVisualKind.data);
    });

    test('prefers directory metadata over the path extension', () {
      expect(
        fileVisualKindForPath('archive.zip', isDirectory: true),
        FileVisualKind.directory,
      );
      expect(fileVisualKindForPath('nested/path/'), FileVisualKind.directory);
    });
  });

  testWidgets('renders distinct video and audio icons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            FileTypeIcon(path: 'clip.mp4'),
            FileTypeIcon(path: 'voice.wav'),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.video_file_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audio_file_outlined), findsOneWidget);
  });
}
