enum AppIconVariant {
  defaultIcon,
  lightOutline,
  proCopperEmerald;

  String get id => switch (this) {
    AppIconVariant.defaultIcon => 'default',
    AppIconVariant.lightOutline => 'light_outline',
    AppIconVariant.proCopperEmerald => 'pro_copper_emerald',
  };

  String? get platformIconId => switch (this) {
    AppIconVariant.defaultIcon => null,
    AppIconVariant.lightOutline => 'light_outline',
    AppIconVariant.proCopperEmerald => 'pro_copper_emerald',
  };

  String get previewAssetPath => switch (this) {
    AppIconVariant.defaultIcon => 'assets/icon.png',
    AppIconVariant.lightOutline => 'assets/icon_light_outline.png',
    AppIconVariant.proCopperEmerald => 'assets/icon_pro_copper_emerald.png',
  };
}

AppIconVariant appIconVariantFromId(String? id) {
  return AppIconVariant.values.firstWhere(
    (variant) => variant.id == id,
    orElse: () => AppIconVariant.defaultIcon,
  );
}
