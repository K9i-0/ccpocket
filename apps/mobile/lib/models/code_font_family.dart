enum CodeFontFamily {
  jetBrainsMono('jetBrainsMono', 'JetBrains Mono', 'JetBrainsMono'),
  ioskeley('ioskeley', 'Ioskeley', 'IoskeleyMono'),
  dejaVuSansMono('dejaVuSansMono', 'DejaVu Sans Mono', 'DejaVuSansMono');

  const CodeFontFamily(this.id, this.label, this.fontFamily);

  final String id;
  final String label;
  final String fontFamily;
}

CodeFontFamily codeFontFamilyFromRaw(String? raw) {
  for (final family in CodeFontFamily.values) {
    if (family.id == raw) return family;
  }
  return CodeFontFamily.jetBrainsMono;
}
