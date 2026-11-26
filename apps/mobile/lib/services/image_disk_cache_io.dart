import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Disk-backed image byte cache stored under the platform temporary directory
/// (or an explicit [directoryPath] override for tests).
///
/// Filenames are SHA-256 digests of the cache key so arbitrary URLs and keys
/// map safely to flat filesystem paths.
class ImageDiskCache {
  static const _cacheFolderName = 'ccpocket_image_cache';
  static Directory? _cachedDefaultDirectory;
  static int _tempFileCounter = 0;

  final String? directoryPath;

  const ImageDiskCache({this.directoryPath});

  Future<Directory?> _resolveDirectory() async {
    final override = directoryPath;
    if (override != null) {
      return Directory(override);
    }
    if (_cachedDefaultDirectory != null) {
      return _cachedDefaultDirectory;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final dir = Directory(p.join(tempDir.path, _cacheFolderName));
      _cachedDefaultDirectory = dir;
      return dir;
    } catch (_) {
      // e.g. MissingPluginException in unit/widget tests without path_provider.
      return null;
    }
  }

  static String filenameForKey(String cacheKey) {
    return sha256.convert(utf8.encode(cacheKey)).toString();
  }

  Future<File?> _fileForKey(String cacheKey) async {
    final dir = await _resolveDirectory();
    if (dir == null) return null;
    return File(p.join(dir.path, filenameForKey(cacheKey)));
  }

  Future<Uint8List?> read(
    String cacheKey, {
    required Duration maxAge,
    DateTime? now,
  }) async {
    try {
      final file = await _fileForKey(cacheKey);
      if (file == null || !await file.exists()) return null;

      final stat = await file.stat();
      final currentTime = now ?? DateTime.now();
      if (maxAge <= Duration.zero ||
          currentTime.difference(stat.modified) > maxAge) {
        await _safeDelete(file);
        return null;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        await _safeDelete(file);
        return null;
      }
      return bytes;
    } catch (_) {
      await delete(cacheKey);
      return null;
    }
  }

  Future<void> write(String cacheKey, Uint8List bytes) async {
    if (bytes.isEmpty) return;
    File? tempFile;
    try {
      final dir = await _resolveDirectory();
      if (dir == null) return;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final targetPath = p.join(dir.path, filenameForKey(cacheKey));
      final suffix = '${pid}_${_tempFileCounter++}';
      tempFile = File('$targetPath.tmp.$suffix');
      await tempFile.writeAsBytes(bytes);
      await tempFile.rename(targetPath);
    } catch (_) {
      if (tempFile != null) {
        await _safeDelete(tempFile);
      }
    }
  }

  Future<void> delete(String cacheKey) async {
    try {
      final file = await _fileForKey(cacheKey);
      if (file != null) {
        await _safeDelete(file);
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors.
    }
  }
}
