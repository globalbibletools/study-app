import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'resource.dart';

class ResourceDatabase {
  final Future<Database> _database;

  ResourceDatabase()
      : _database = _open();

  static Future<Database> _open() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = join(docDir.path, "resources.db");
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
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
            creator_name text
          );
        ''');
      },
    );
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
      [ServerState.Removed.name, resourceType.name],
    );

    for (var resource in resources) {
      final d = resource.installableDetails;
      batch.rawInsert(
        '''
          insert into resource (id, resource_type, server_state, server_updated_at, sha_256, size, url, resource_name, creator_name)
          values (?, ?, ?, ?, ?, ?, ?, ?, ?)
          on conflict(id) do update set
            server_state = excluded.server_state,
            server_updated_at = excluded.server_updated_at,
            sha_256 = excluded.sha_256,
            size = excluded.size,
            url = excluded.url,
            resource_name = excluded.resource_name,
            creator_name = excluded.creator_name;
        ''',
        [
          resource.id,
          resourceType.name,
          d?.serverState?.name,
          d?.serverUpdatedAt,
          d?.sha256,
          d?.size,
          d?.url,
          resource.resourceName,
          resource.creatorName,
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<ResourceView>> getResourceViews(
    ResourceType resourceType,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'resource',
      where: 'resource_type = ? AND server_state = ?',
      whereArgs: [resourceType.name, ServerState.Available.name],
      columns: ['id', 'resource_name', 'creator_name', 'size', 'install_state', 'server_updated_at', 'local_updated_at'],
    );

    return rows.map((row) {
      final size = row['size'] as int?;
      final serverUpdatedAt = row['server_updated_at'] as String?;
      final installStateStr = row['install_state'] as String?;
      final localUpdatedAt = row['local_updated_at'] as String?;

      // Build the nested view only when all installable fields are present.
      final hasInstallable =
          size != null && serverUpdatedAt != null && installStateStr != null;
      final installableDetails = hasInstallable
          ? InstallableDetailsView(
              size: size,
              installState: InstallState.values.firstWhere(
                (s) => s.name == installStateStr,
                orElse: () => InstallState.NotInstalled,
              ),
              serverUpdatedAt: serverUpdatedAt,
              localUpdatedAt: localUpdatedAt,
            )
          : null;

      return ResourceView(
        id: row['id'] as String,
        type: ResourceType.values.firstWhere(
          (s) => s.name == row['resource_type'],
          orElse: () {
              debugPrint("Missing resource type for ${row['resource_type']}");
              return ResourceType.Gloss;
          }
        ),
        resourceName: row['resource_name'] as String,
        creatorName: row['creator_name'] as String?,
        installableDetails: installableDetails,
      );
    }).toList();
  }

  Future<Map<ResourceType, int>> countOutdatedResourcesByType() async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
        select resource_type, count(*) as cnt from resource
        where server_state = 'Available'
          and install_state = 'Installed'
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
      columns: ['local_updated_at'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['local_updated_at'] as String?;
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
          local_updated_at = case when ? = 'Installed' then server_updated_at else null end
        where id = ?;
      ''',
      [state, state, id],
    );
  }
}

