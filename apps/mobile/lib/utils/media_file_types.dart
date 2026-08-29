enum MediaFileKind { audio, video }

typedef MediaFileType = ({MediaFileKind kind, String mimeType});

const mediaFileTypesByExtension = <String, MediaFileType>{
  'wav': (kind: MediaFileKind.audio, mimeType: 'audio/wav'),
  'mp3': (kind: MediaFileKind.audio, mimeType: 'audio/mpeg'),
  'm4a': (kind: MediaFileKind.audio, mimeType: 'audio/mp4'),
  'aac': (kind: MediaFileKind.audio, mimeType: 'audio/aac'),
  'flac': (kind: MediaFileKind.audio, mimeType: 'audio/flac'),
  'ogg': (kind: MediaFileKind.audio, mimeType: 'audio/ogg'),
  'opus': (kind: MediaFileKind.audio, mimeType: 'audio/ogg'),
  'aif': (kind: MediaFileKind.audio, mimeType: 'audio/aiff'),
  'aiff': (kind: MediaFileKind.audio, mimeType: 'audio/aiff'),
  'aifc': (kind: MediaFileKind.audio, mimeType: 'audio/aiff'),
  'mp4': (kind: MediaFileKind.video, mimeType: 'video/mp4'),
  'mov': (kind: MediaFileKind.video, mimeType: 'video/quicktime'),
  'm4v': (kind: MediaFileKind.video, mimeType: 'video/x-m4v'),
  'webm': (kind: MediaFileKind.video, mimeType: 'video/webm'),
  'mkv': (kind: MediaFileKind.video, mimeType: 'video/x-matroska'),
  'avi': (kind: MediaFileKind.video, mimeType: 'video/x-msvideo'),
  'mpg': (kind: MediaFileKind.video, mimeType: 'video/mpeg'),
  'mpeg': (kind: MediaFileKind.video, mimeType: 'video/mpeg'),
};

MediaFileType? mediaFileTypeForPath(String path) {
  final extension = mediaFileExtensionForPath(path);
  return extension == null ? null : mediaFileTypesByExtension[extension];
}

String? mediaFileExtensionForPath(String path) {
  final fileName = path.replaceAll('\\', '/').split('/').last.toLowerCase();
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) return null;
  return fileName.substring(dotIndex + 1);
}
