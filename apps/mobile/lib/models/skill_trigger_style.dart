/// Which trigger the composer uses for skills.
///
/// Every style is converted to the agent's native form (`/` for Claude, `$`
/// for Codex) when the message is sent; the style only affects completion and
/// what is inserted into the composer.
enum SkillTriggerStyle {
  /// Both `/` and `$` open skill completion; picks use the agent's trigger.
  both('both'),

  /// Always insert skills as `/name`.
  slash('slash'),

  /// Always insert skills as `$name`.
  dollar('dollar');

  final String value;
  const SkillTriggerStyle(this.value);

  static SkillTriggerStyle? fromValue(String? value) {
    for (final style in values) {
      if (style.value == value) return style;
    }
    return null;
  }
}
