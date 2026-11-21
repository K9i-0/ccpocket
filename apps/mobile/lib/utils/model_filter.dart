/// Filters [models] down to the user-enabled model IDs.
///
/// - When [enabledIds] is empty, all [models] are returned (no filter).
/// - When [currentId] is provided and exists in [models], it is always kept so
///   the active session's model stays visible and selectable.
/// - If filtering would leave no models (for example, saved IDs are no longer
///   in the Bridge's catalog), falls back to all [models].
List<T> filterEnabledModels<T>({
  required List<T> models,
  required Set<String> enabledIds,
  required String Function(T) idOf,
  String? currentId,
}) {
  if (enabledIds.isEmpty || models.isEmpty) return models;
  final filtered = [
    for (final model in models)
      if (enabledIds.contains(idOf(model)) ||
          (currentId != null && idOf(model) == currentId))
        model,
  ];
  return filtered.isNotEmpty ? filtered : models;
}
