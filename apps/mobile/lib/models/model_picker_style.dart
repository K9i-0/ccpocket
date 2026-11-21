/// How the model selector opens when tapping a model name in a settings panel.
enum ModelPickerStyle {
  /// Opens a modal bottom sheet listing the available models.
  bottomSheet('bottom_sheet'),

  /// Opens an inline popup menu anchored to the tapped model button.
  popupMenu('popup_menu');

  final String value;
  const ModelPickerStyle(this.value);

  static ModelPickerStyle? fromValue(String? value) {
    for (final style in values) {
      if (style.value == value) return style;
    }
    return null;
  }
}
