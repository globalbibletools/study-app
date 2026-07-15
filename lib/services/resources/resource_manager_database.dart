import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:gbt/services/resources/resource.dart';

class ResourceManagerDatabase {
  static const _databaseName = 'resource_manager.db';
  static const _databaseVersion = 2;

  Database? _database;
  Future<Database>? _initFuture;

  /// Opens (or creates) the database. Safe to call multiple times;
  /// subsequent calls return the same in-flight future.
  Future<Database> init() async {
    if (_database != null) return _database!;
    if (_initFuture != null) return _initFuture!;

    _initFuture = _initDatabase();
    try {
      _database = await _initFuture;
      return _database!;
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE resource (
            type              TEXT    NOT NULL,
            id                TEXT    NOT NULL,
            server_updated_at TEXT,
            sha256            TEXT,
            size              INTEGER,
            url               TEXT,
            resource_name     TEXT,
            creator_name      TEXT,
            local_updated_at  TEXT,
            PRIMARY KEY (type, id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE resource ADD COLUMN url TEXT');
        }
      },
    );
  }

  Future<void> upsert(Resource resource) async {
    final db = await init();
    await db.insert(
      'resource',
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Resource>> getByType(String type) async {
    final db = await init();
    final rows = await db.query(
      'resource',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'resource_name ASC',
    );
    return rows.map(Resource.fromMap).toList();
  }

  /// Returns the [Resource] for `(type, id)`, or `null` if no row exists.
  Future<Resource?> getById(String type, String id) async {
    final db = await init();
    final rows = await db.query(
      'resource',
      where: 'type = ? AND id = ?',
      whereArgs: [type, id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Resource.fromMap(rows.first);
  }

  void dispose() {
    _database?.close();
  }
}
