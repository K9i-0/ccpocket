import 'package:sqflite/sqflite.dart';

typedef DatabaseOpenFunction =
    Future<Database> Function({
      required int version,
      required OnDatabaseCreateFn onCreate,
      required OnDatabaseVersionChangeFn onUpgrade,
    });

class PlatformDatabaseOpenConfig {
  const PlatformDatabaseOpenConfig({required this.path, required this.open});

  final String path;
  final DatabaseOpenFunction open;
}

Future<PlatformDatabaseOpenConfig?> getPlatformDatabaseOpenConfig(
  String dbName,
) async {
  return null;
}
