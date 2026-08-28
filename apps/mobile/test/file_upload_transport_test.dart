import 'dart:async';
import 'dart:typed_data';

import 'package:ccpocket/features/file_upload/file_upload_transport.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _UploadClient extends http.BaseClient {
  final bool corruptDigest;
  bool? followRedirects;
  Uint8List? received;

  _UploadClient({this.corruptDigest = false});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    followRedirects = request.followRedirects;
    received = await request.finalize().toBytes();
    final digest = sha256.convert(received!).toString();
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      201,
      headers: {
        'x-received-bytes': '${received!.length}',
        'x-file-sha256': corruptDigest
            ? '0000000000000000000000000000000000000000000000000000000000000000'
            : digest,
      },
    );
  }
}

void main() {
  test(
    'streams bytes, reports progress, hashes, and disables redirects',
    () async {
      final client = _UploadClient();
      final transport = FileUploadTransport(clientFactory: () => client);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final progress = <int>[];

      final result = await transport.upload(
        url: Uri.parse(
          'http://bridge.local/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        file: XFile.fromData(bytes, name: 'sample.bin'),
        expectedSizeBytes: bytes.length,
        onProgress: (sent, _) => progress.add(sent),
      );

      expect(client.followRedirects, isFalse);
      expect(client.received, bytes);
      expect(progress.last, bytes.length);
      expect(result.sha256, sha256.convert(bytes).toString());
    },
  );

  test('rejects a Bridge digest mismatch', () async {
    final transport = FileUploadTransport(
      clientFactory: () => _UploadClient(corruptDigest: true),
    );
    final bytes = Uint8List.fromList([1]);

    await expectLater(
      transport.upload(
        url: Uri.parse(
          'http://bridge.local/api/uploads/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        file: XFile.fromData(bytes, name: 'sample.bin'),
        expectedSizeBytes: 1,
        onProgress: (_, _) {},
      ),
      throwsA(
        isA<FileUploadException>().having(
          (error) => error.code,
          'code',
          'integrity_failed',
        ),
      ),
    );
  });
}
