import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  if (!Platform.isLinux && !Platform.isWindows) return null;

  sqfliteFfiInit();
  final supportDir = await getApplicationSupportDirectory();
  final dbDir = Directory(path.join(supportDir.path, 'databases'));
  await dbDir.create(recursive: true);
  final dbPath = path.join(dbDir.path, dbName);

  return PlatformDatabaseOpenConfig(
    path: dbPath,
    open:
        ({
          required int version,
          required OnDatabaseCreateFn onCreate,
          required OnDatabaseVersionChangeFn onUpgrade,
        }) {
          return databaseFactoryFfi.openDatabase(
            dbPath,
            options: OpenDatabaseOptions(
              version: version,
              onCreate: onCreate,
              onUpgrade: onUpgrade,
            ),
          );
        },
  );
}
