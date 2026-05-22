enum ImagePasteShortcut { ctrlV, commandV }

ImagePasteShortcut imagePasteShortcutFromRaw(String? raw) {
  return switch (raw) {
    'commandV' => ImagePasteShortcut.commandV,
    _ => ImagePasteShortcut.ctrlV,
  };
}
