import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_providers.dart';
import 'package:ccpocket/features/gallery/gallery_screen.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';

// Minimal mock that exposes gallery stream
class _MockBridgeService extends BridgeService {
  final _galleryStreamController =
      StreamController<List<GalleryImage>>.broadcast();
  List<GalleryImage> _mockImages = [];
  bool galleryRequested = false;

  @override
  Stream<List<GalleryImage>> get galleryStream =>
      _galleryStreamController.stream;

  @override
  List<GalleryImage> get galleryImages => _mockImages;

  @override
  String? get httpBaseUrl => 'http://localhost:8765';

  @override
  void requestGallery({String? project, String? sessionId}) {
    galleryRequested = true;
    // Immediately emit the mock images
    _galleryStreamController.add(_mockImages);
  }

  void setImages(List<GalleryImage> images) {
    _mockImages = images;
    _galleryStreamController.add(images);
  }
}

Widget _wrapWithTheme(Widget child, _MockBridgeService mock) {
  return ProviderScope(
    overrides: [bridgeServiceProvider.overrideWithValue(mock)],
    child: MaterialApp(theme: AppTheme.darkTheme, home: child),
  );
}

void main() {
  group('GalleryScreen', () {
    testWidgets('shows empty state when no images', (tester) async {
      final mock = _MockBridgeService();
      await tester.pumpWidget(_wrapWithTheme(const GalleryScreen(), mock));
      await tester.pump();

      expect(find.text('No previews yet'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(mock.galleryRequested, isTrue);
    });

    testWidgets('shows images in grid when images exist', (tester) async {
      final mock = _MockBridgeService();
      mock.setImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-a',
          projectName: 'project-a',
          addedAt: '2025-01-15T10:30:00Z',
          sizeBytes: 123456,
        ),
        const GalleryImage(
          id: 'img-2',
          url: '/api/gallery/img-2',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-b',
          projectName: 'project-b',
          addedAt: '2025-01-15T09:00:00Z',
          sizeBytes: 654321,
        ),
      ]);

      await tester.pumpWidget(_wrapWithTheme(const GalleryScreen(), mock));
      await tester.pump();

      // Should show project names
      expect(find.text('project-a'), findsWidgets);
      expect(find.text('project-b'), findsWidgets);

      // Should NOT show empty state
      expect(find.text('No images yet'), findsNothing);

      // Should show filter chips when multiple projects
      expect(find.text('All (2)'), findsOneWidget);
    });

    testWidgets('filter chips filter images by project', (tester) async {
      final mock = _MockBridgeService();
      mock.setImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-a',
          projectName: 'project-a',
          addedAt: '2025-01-15T10:30:00Z',
          sizeBytes: 123456,
        ),
        const GalleryImage(
          id: 'img-2',
          url: '/api/gallery/img-2',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-b',
          projectName: 'project-b',
          addedAt: '2025-01-15T09:00:00Z',
          sizeBytes: 654321,
        ),
      ]);

      await tester.pumpWidget(_wrapWithTheme(const GalleryScreen(), mock));
      await tester.pump();

      // Tap project-a chip
      final chipFinder = find.widgetWithText(ChoiceChip, 'project-a');
      expect(chipFinder, findsOneWidget);
      await tester.tap(chipFinder);
      await tester.pump();

      // Grid should now show only project-a images
      // project-a appears in chip + grid tile
      // project-b should only appear in filter chip
      final gridTiles = tester.widgetList(find.byType(GridView));
      expect(gridTiles, isNotEmpty);
    });

    testWidgets('no filter chips when single project', (tester) async {
      final mock = _MockBridgeService();
      mock.setImages([
        const GalleryImage(
          id: 'img-1',
          url: '/api/gallery/img-1',
          mimeType: 'image/png',
          projectPath: '/Users/demo/project-a',
          projectName: 'project-a',
          addedAt: '2025-01-15T10:30:00Z',
          sizeBytes: 123456,
        ),
      ]);

      await tester.pumpWidget(_wrapWithTheme(const GalleryScreen(), mock));
      await tester.pump();

      // Only 1 project: no filter chips
      expect(find.byType(ChoiceChip), findsNothing);
      // But should show image
      expect(find.text('project-a'), findsWidgets);
    });
  });

  group('GalleryImage model', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'uuid-123',
        'url': '/api/gallery/uuid-123',
        'mimeType': 'image/png',
        'projectPath': '/Users/demo/myapp',
        'projectName': 'myapp',
        'sessionId': 'sess-abc',
        'addedAt': '2025-01-15T10:30:00Z',
        'sizeBytes': 98765,
      };
      final img = GalleryImage.fromJson(json);
      expect(img.id, 'uuid-123');
      expect(img.url, '/api/gallery/uuid-123');
      expect(img.mimeType, 'image/png');
      expect(img.projectName, 'myapp');
      expect(img.sessionId, 'sess-abc');
      expect(img.sizeBytes, 98765);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'uuid-456',
        'url': '/api/gallery/uuid-456',
        'mimeType': 'image/jpeg',
        'projectPath': '/path',
        'projectName': 'proj',
        'addedAt': '2025-01-15T10:00:00Z',
      };
      final img = GalleryImage.fromJson(json);
      expect(img.sessionId, isNull);
      expect(img.sizeBytes, 0);
    });
  });

  group('Gallery ServerMessage', () {
    test('gallery_list parses correctly', () {
      final json = {
        'type': 'gallery_list',
        'images': [
          {
            'id': 'img-1',
            'url': '/api/gallery/img-1',
            'mimeType': 'image/png',
            'projectPath': '/path',
            'projectName': 'proj',
            'addedAt': '2025-01-15T10:00:00Z',
            'sizeBytes': 100,
          },
        ],
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<GalleryListMessage>());
      final gm = msg as GalleryListMessage;
      expect(gm.images.length, 1);
      expect(gm.images[0].id, 'img-1');
    });

    test('gallery_new_image parses correctly', () {
      final json = {
        'type': 'gallery_new_image',
        'image': {
          'id': 'img-2',
          'url': '/api/gallery/img-2',
          'mimeType': 'image/jpeg',
          'projectPath': '/path',
          'projectName': 'proj',
          'addedAt': '2025-01-15T11:00:00Z',
          'sizeBytes': 200,
        },
      };
      final msg = ServerMessage.fromJson(json);
      expect(msg, isA<GalleryNewImageMessage>());
      final gm = msg as GalleryNewImageMessage;
      expect(gm.image.id, 'img-2');
    });
  });

  group('ClientMessage', () {
    test('listGallery generates correct JSON', () {
      final msg = ClientMessage.listGallery();
      expect(msg.toJson(), contains('"type":"list_gallery"'));
    });

    test('listGallery with project generates correct JSON', () {
      final msg = ClientMessage.listGallery(project: '/path/to/proj');
      final json = msg.toJson();
      expect(json, contains('"type":"list_gallery"'));
      expect(json, contains('"project":"/path/to/proj"'));
    });
  });
}
