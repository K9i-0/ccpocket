import 'dart:async';
import 'dart:io';

import 'package:ccpocket/features/file_peek/playback/local_media_snapshot_io.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late String url;
  late LocalMediaSnapshot snapshot;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/api/media/test';
    snapshot = LocalMediaSnapshot(enabled: true);
  });
  tearDown(() async {
    await snapshot.dispose();
    await server.close(force: true);
  });

  test('plays a complete private copy, removed when preview closes', () async {
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    final source = await snapshot.prepare(url);
    final file = File.fromUri(Uri.parse(source));
    expect(await file.readAsBytes(), [1, 2, 3, 4]);
    // Further reads/seeks use disk, even if the Bridge is unreachable.
    await server.close(force: true);
    final handle = await file.open();
    await handle.setPosition(2);
    expect(await handle.read(2), [3, 4]);
    await handle.close();
    expect(requests, 1);
    await snapshot.dispose();
    expect(await file.exists(), isFalse);
  });

  test('remote URLs and disabled platforms keep streaming', () async {
    expect(
      await snapshot.prepare('https://example.invalid/video.mp4'),
      'https://example.invalid/video.mp4',
    );
    final disabled = LocalMediaSnapshot(enabled: false);
    expect(await disabled.prepare(url), url);
    await disabled.dispose();
  });

  test('large responses are not copied', () async {
    snapshot = LocalMediaSnapshot(enabled: true, maxBytes: 3);
    server.listen((request) async {
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    expect(await snapshot.prepare(url), url);
  });

  test('redirects retain the original capability URL', () async {
    var requests = 0;
    server.listen((request) async {
      requests++;
      request.response.statusCode = HttpStatus.found;
      request.response.headers.set(HttpHeaders.locationHeader, '/redirected');
      await request.response.close();
    });
    expect(await snapshot.prepare(url), url);
    expect(requests, 1);
  });

  test(
    'a stalled download falls back within the preparation deadline',
    () async {
      snapshot = LocalMediaSnapshot(
        enabled: true,
        timeout: const Duration(milliseconds: 50),
      );
      server.listen((request) {});
      expect(
        await snapshot.prepare(url).timeout(const Duration(seconds: 2)),
        url,
      );
    },
  );

  test('closing a preview cancels an active download', () async {
    final started = Completer<void>();
    server.listen((request) => started.complete());
    final result = snapshot.prepare(url);
    await started.future;
    await snapshot.dispose().timeout(const Duration(seconds: 2));
    expect(await result, url);
  });

  test('incomplete responses never become playback files', () async {
    server.listen((request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.write('HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\nab');
      await socket.close();
    });
    expect(await snapshot.prepare(url), url);
  });
}
