import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ccpocket/services/cached_network_image_provider.dart';
import 'package:ccpocket/widgets/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

final _validPng = Uint8List.fromList([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, //
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, //
  0x42, 0x60, 0x82,
]);

void main() {
  late Directory cacheDir;

  setUp(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    cacheDir = await Directory.systemTemp.createTemp('ccpocket_img_widget_');
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  });

  testWidgets('shows loadingBuilder while pending then renders image', (
    tester,
  ) async {
    final gate = Completer<void>();
    final client = MockClient((request) async {
      await gate.future;
      return http.Response.bytes(_validPng, 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CachedNetworkImage(
            url: 'https://example.com/loading.png',
            width: 120,
            height: 80,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheKey: 'widget-loading',
            cacheMaxAge: const Duration(days: 3),
            httpClient: client,
            cacheDirectoryPath: cacheDir.path,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Text('loading-placeholder');
            },
            errorBuilder: (_, _, _) => const Text('error-placeholder'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('loading-placeholder'), findsOneWidget);
    expect(find.text('error-placeholder'), findsNothing);

    final imageWidget = tester.widget<Image>(find.byType(Image));
    expect(imageWidget.fit, BoxFit.cover);
    expect(imageWidget.width, 120);
    expect(imageWidget.height, 80);
    expect(imageWidget.gaplessPlayback, isTrue);
    final provider = imageWidget.image as CachedNetworkImageProvider;
    expect(provider.cacheKey, 'widget-loading');
    expect(provider.cacheMaxAge, const Duration(days: 3));

    gate.complete();
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      if (find.byType(RawImage).evaluate().isNotEmpty) break;
    }

    expect(find.text('loading-placeholder'), findsNothing);
    expect(find.text('error-placeholder'), findsNothing);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('renders errorBuilder when network fetch fails', (tester) async {
    final client = MockClient((request) async => http.Response('missing', 404));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CachedNetworkImage(
            url: 'https://example.com/missing.png',
            httpClient: client,
            cacheDirectoryPath: cacheDir.path,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Text('loading-placeholder');
            },
            errorBuilder: (_, _, _) => const Text('error-placeholder'),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(find.text('error-placeholder'), findsOneWidget);
    expect(find.text('loading-placeholder'), findsNothing);
  });
}
