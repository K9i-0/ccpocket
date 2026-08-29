import 'package:flutter/material.dart';

import '../utils/media_file_types.dart';

enum FileVisualKind {
  directory,
  video,
  audio,
  image,
  source,
  shell,
  data,
  pdf,
  archive,
  document,
  unknown,
}

const _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'svg',
  'bmp',
  'heic',
};
const _sourceExtensions = {
  'dart',
  'ts',
  'tsx',
  'js',
  'jsx',
  'py',
  'rb',
  'go',
  'rs',
  'java',
  'kt',
  'kts',
  'swift',
  'c',
  'cc',
  'cpp',
  'h',
  'hpp',
  'cs',
  'php',
  'scala',
  'vue',
  'svelte',
  'sql',
  'css',
  'scss',
  'less',
  'html',
  'htm',
};
const _shellExtensions = {'sh', 'bash', 'zsh', 'fish', 'ps1', 'bat', 'cmd'};
const _dataExtensions = {
  'json',
  'jsonl',
  'yaml',
  'yml',
  'toml',
  'xml',
  'csv',
  'tsv',
  'ini',
  'conf',
  'config',
  'properties',
};
const _archiveExtensions = {
  'zip',
  'tar',
  'gz',
  'tgz',
  'bz2',
  'xz',
  '7z',
  'rar',
};
const _documentExtensions = {
  'md',
  'mdx',
  'txt',
  'log',
  'rtf',
  'doc',
  'docx',
  'ppt',
  'pptx',
  'xls',
  'xlsx',
};
const _shellFileNames = {'dockerfile', 'makefile', 'justfile', 'gemfile'};
const _configurationFileNames = {
  '.env',
  '.gitignore',
  '.gitattributes',
  '.dockerignore',
  '.editorconfig',
};

FileVisualKind fileVisualKindForPath(String path, {bool isDirectory = false}) {
  if (isDirectory || path.endsWith('/')) return FileVisualKind.directory;

  final fileName = path.split('/').last.toLowerCase();
  if (_shellFileNames.contains(fileName)) return FileVisualKind.shell;
  if (_configurationFileNames.contains(fileName)) return FileVisualKind.data;

  final dotIndex = fileName.lastIndexOf('.');
  final extension = dotIndex < 0 ? '' : fileName.substring(dotIndex + 1);
  final mediaType = mediaFileTypeForPath(fileName);
  if (mediaType != null) {
    return switch (mediaType.kind) {
      MediaFileKind.video => FileVisualKind.video,
      MediaFileKind.audio => FileVisualKind.audio,
    };
  }
  if (_imageExtensions.contains(extension)) return FileVisualKind.image;
  if (_sourceExtensions.contains(extension)) return FileVisualKind.source;
  if (_shellExtensions.contains(extension)) return FileVisualKind.shell;
  if (_dataExtensions.contains(extension)) return FileVisualKind.data;
  if (extension == 'pdf') return FileVisualKind.pdf;
  if (_archiveExtensions.contains(extension)) return FileVisualKind.archive;
  if (_documentExtensions.contains(extension)) return FileVisualKind.document;
  return FileVisualKind.unknown;
}

IconData fileVisualIcon(FileVisualKind kind) => switch (kind) {
  FileVisualKind.directory => Icons.folder_outlined,
  FileVisualKind.video => Icons.video_file_outlined,
  FileVisualKind.audio => Icons.audio_file_outlined,
  FileVisualKind.image => Icons.image_outlined,
  FileVisualKind.source => Icons.code,
  FileVisualKind.shell => Icons.terminal_outlined,
  FileVisualKind.data => Icons.data_object_outlined,
  FileVisualKind.pdf => Icons.picture_as_pdf_outlined,
  FileVisualKind.archive => Icons.folder_zip_outlined,
  FileVisualKind.document => Icons.article_outlined,
  FileVisualKind.unknown => Icons.insert_drive_file_outlined,
};

class FileTypeIcon extends StatelessWidget {
  final String path;
  final bool isDirectory;
  final bool isIgnored;
  final double size;

  const FileTypeIcon({
    super.key,
    required this.path,
    this.isDirectory = false,
    this.isIgnored = false,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final kind = fileVisualKindForPath(path, isDirectory: isDirectory);
    final color = _fileVisualColor(Theme.of(context).colorScheme, kind);
    return ExcludeSemantics(
      child: Icon(
        fileVisualIcon(kind),
        size: size,
        color: isIgnored ? color.withValues(alpha: 0.48) : color,
      ),
    );
  }
}

Color _fileVisualColor(ColorScheme colors, FileVisualKind kind) =>
    switch (kind) {
      FileVisualKind.video => colors.primary,
      FileVisualKind.audio || FileVisualKind.image => colors.secondary,
      FileVisualKind.directory || FileVisualKind.archive => colors.tertiary,
      FileVisualKind.pdf => colors.error,
      FileVisualKind.source ||
      FileVisualKind.shell ||
      FileVisualKind.data ||
      FileVisualKind.document ||
      FileVisualKind.unknown => colors.onSurfaceVariant,
    };
