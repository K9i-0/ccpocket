class LocalMediaSnapshot {
  LocalMediaSnapshot();

  Future<String> prepare(String url) async => url;
  Future<void> dispose() async {}
}
