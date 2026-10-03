import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'resource.dart';
import 'resource_language.dart';

class ResourceDatabase {
  static const _createLanguagesTable = '''
    create table languages (
      code text primary key,
      name text not null,
      text_direction text not null
    );
  ''';

  final Future<Database> _database;

  ResourceDatabase()
      : _database = _open();

  static Future<Database> _open() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = join(docDir.path, "resources.db");
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute(_createLanguagesTable);
        await db.execute('''
          create table resource (
            id text primary key,
            resource_type text not null,
            server_state text,
            install_state text,
            server_updated_at text,
            local_updated_at text,
            sha_256 text,
            size integer,
            url text,
            resource_name text not null,
            creator_name text,
            depth integer not null,
            lang_code text
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_createLanguagesTable);
          await db.execute(
            "alter table resource add column lang_code text;",
          );
        }
      },
    );
  }

  Future<void> updateLanguagesFromManifest(
    List<ResourceLanguage> languages,
  ) async {
    final db = await _database;
    final batch = db.batch();

    if (languages.isEmpty) {
      batch.delete('languages');
    } else {
      final placeholders = List.filled(languages.length, '?').join(', ');
      batch.rawDelete(
        'delete from languages where code not in ($placeholders);',
        languages.map((l) => l.code).toList(),
      );
    }

    for (final language in languages) {
      batch.rawInsert(
        '''
          insert into languages (code, name, text_direction)
          values (?, ?, ?)
          on conflict(code) do update set
            name = excluded.name,
            text_direction = excluded.text_direction;
        ''',
        [language.code, language.name, language.textDirection.name],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<void> updateResourcesFromManifest(ResourceType resourceType, List<Resource> resources) async {
    final db = await _database;
    final batch = db.batch();

    batch.rawUpdate(
      '''
        update resource set
          server_state = ?
        where resource_type = ?;
      ''',
      [ServerState.removed.name, resourceType.name],
    );

    for (var resource in resources) {
      final d = resource.installableDetails;
      batch.rawInsert(
        '''
          insert into resource (id, resource_type, server_state, install_state, server_updated_at, sha_256, size, url, resource_name, creator_name, depth, lang_code)
          values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          on conflict(id) do update set
            server_state = excluded.server_state,
            server_updated_at = excluded.server_updated_at,
            sha_256 = excluded.sha_256,
            size = excluded.size,
            url = excluded.url,
            resource_name = excluded.resource_name,
            creator_name = excluded.creator_name,
            depth = excluded.depth,
            lang_code = excluded.lang_code;
        ''',
        [
          resource.id,
          resourceType.name,
          d?.serverState.name,
          d?.installState.name,
          d?.serverUpdatedAt,
          d?.sha256,
          d?.size,
          d?.url,
          resource.resourceName,
          resource.creatorName,
          '/'.allMatches(resource.id).length,
          resource.langCode,
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<Resource>> getAllForType(
    ResourceType resourceType,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'resource',
      where: 'resource_type = ?',
      whereArgs: [resourceType.name],
    );

    return rows.map(_rowToResource).toList();
  }

  Future<List<Resource>> queryByPath(
    ResourceType resourceType,
    List<PathMatcher> path,
  ) async {
    final db = await _database;

    if (path.isEmpty) {
      throw Exception("Cannot query resources with an empty path");
    }

    final rows = await db.query(
      'resource',
      where: "resource_type = ? AND id GLOB ? AND depth = ?",
      whereArgs: [
        resourceType.name,
        path.join('/'),
        path.length - 1,
      ],
    );

    return rows.map(_rowToResource).toList();
  }

  Resource _rowToResource(Map<String, Object?> row) {
    final size = row['size'] as int?;
    final sha256 = row['sha_256'] as String?;
    final url = row['url'] as String?;
    final serverUpdatedAt = row['server_updated_at'] as String?;
    final localUpdatedAt = row['local_updated_at'] as String?;
    final installStateStr = row['install_state'] as String?;
    final serverStateStr = row['server_state'] as String?;

    // Build the nested view only when all installable fields are present.
    final hasInstallable =
        size != null &&
        sha256 != null &&
        url != null &&
        serverUpdatedAt != null &&
        installStateStr != null &&
        serverStateStr != null;

    final installableDetails = hasInstallable
        ? InstallableDetails(
            size: size,
            sha256: sha256,
            url: url,
            installState: InstallState.values.firstWhere(
              (s) => s.name == installStateStr,
              orElse: () => InstallState.notInstalled,
            ),
            serverState: ServerState.values.firstWhere(
              (s) => s.name == serverStateStr,
              orElse: () => ServerState.removed,
            ),
            serverUpdatedAt: serverUpdatedAt,
            localUpdatedAt: localUpdatedAt,
          )
        : null;

    return Resource(
      id: row['id'] as String,
      type: ResourceType.values.firstWhere(
        (s) => s.name == row['resource_type'],
      ),
      resourceName: row['resource_name'] as String,
      creatorName: row['creator_name'] as String?,
      installableDetails: installableDetails,
      langCode: row['lang_code'] as String?,
    );
  }

  Future<ResourceLanguage?> getLanguageForResource(
    ResourceType resourceType,
    String id,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
        select languages.code, languages.name, languages.text_direction
        from resource
        join languages on languages.code = resource.lang_code
        where resource.resource_type = ? and resource.id = ?
        limit 1;
      ''',
      [resourceType.name, id],
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    return ResourceLanguage(
      code: row['code'] as String,
      name: row['name'] as String,
      textDirection: ResourceLanguageTextDirection.values.firstWhere(
        (d) => d.name == row['text_direction'],
        orElse: () => ResourceLanguageTextDirection.ltr,
      ),
    );
  }

  Future<Map<ResourceType, int>> countOutdatedResourcesByType() async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
        select resource_type, count(*) as cnt from resource
        where server_state = 'available'
          and install_state = 'installed'
          and local_updated_at is not null
          and local_updated_at != server_updated_at
        group by resource_type;
      ''',
    );
    final result = <ResourceType, int>{};
    for (final row in rows) {
      final type = ResourceType.values.firstWhere(
        (t) => t.name == row['resource_type'],
      );
      result[type] = (row['cnt'] as int?) ?? 0;
    }
    return result;
  }

  Future<String?> getResourceVersion(
    ResourceType resourceType,
    String id,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'resource',
      where: 'resource_type = ? AND id = ?',
      whereArgs: [resourceType.name, id],
      columns: ['server_updated_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['server_updated_at'] as String?;
  }

  Future<bool> isInstalled(
    ResourceType resourceType,
    String id,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'resource',
      where: 'resource_type = ? AND id = ?',
      whereArgs: [resourceType.name, id],
      columns: ['install_state'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.first['install_state'] == InstallState.installed.name;
  }

  Future<void> setInstallState(
    String id,
    InstallState installState,
  ) async {
    final db = await _database;
    final state = installState.name;
    await db.rawUpdate(
      '''
        update resource set
          install_state = ?,
          local_updated_at = case when ? = 'installed' then server_updated_at else null end
        where id = ?;
      ''',
      [state, state, id],
    );
  }
}

class PathMatcher {
  final String sqlSegment;

  const PathMatcher.any() : sqlSegment = '[^/]*';

  PathMatcher.exact(String value)
    : sqlSegment = value
      .replaceAll(r'*', r'[8]')
      .replaceAll(r'?', r'[?]')
      .replaceAll(r'[', r'[[]')
      .replaceAll(r']', r'[]]');

  @override
  String toString() {
      return sqlSegment;
  }
}

