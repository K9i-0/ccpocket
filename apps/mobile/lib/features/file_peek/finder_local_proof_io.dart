import 'dart:io';
import 'dart:math';

class FinderLocalProof {
  final Directory _directory;
  final String path;
  final String token;

  FinderLocalProof._(this._directory, this.path, this.token);

  static Future<FinderLocalProof> create() async {
    final directory = await Directory.systemTemp.createTemp('ccpocket-finder-');
    try {
      final random = Random.secure();
      final token = List.generate(
        32,
        (_) => random.nextInt(256),
      ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
      final file = File('${directory.path}/proof');
      await file.writeAsString(token, flush: true);
      return FinderLocalProof._(directory, file.path, token);
    } catch (_) {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}
