class FinderLocalProof {
  String get path => '';
  String get token => '';
  static Future<FinderLocalProof> create() =>
      Future.error(UnsupportedError('Finder is only available on macOS'));
  Future<void> dispose() async {}
}
