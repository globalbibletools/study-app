// Tests ManifestSource against a running local MiniStack S3 bucket.
//
// Prerequisites:
//   1. Start the bucket:  docker compose up -d ministack
//   2. Wait for it to be healthy (it seeds assets on first ready).
//   3. Run with the host pointing at localhost, not the Android emulator
//      default, since this test runs on the host machine:
//
//   flutter test test/services/resources/manifest_source_test.dart \
//     --dart-define=ASSETS_BASE_URL=http://localhost:4566/assets
//
// This is a live integration test, not a unit test: it makes a real HTTP
// request to the bucket. It is skipped by default so `flutter test` (without
// the bucket running) stays green; pass `--tags live` to run it.
@Tags(['live'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gbt/services/download/download.dart';
import 'package:gbt/services/files/file_service.dart';
import 'package:gbt/services/resources/manifest_source.dart';
import 'package:gbt/services/resources/remote_asset_service.dart';

void main() {
  setUp(() async {
    final getIt = GetIt.instance;
    await getIt.reset();
    // DownloadService's field initializer accesses getIt<FileService>(), so
    // FileService must be registered first. getJsonl() never touches it, so
    // the real FileService is fine (its path_provider call only happens on
    // getLocalPath, which we never invoke here).
    getIt.registerLazySingleton<FileService>(() => FileService());
    getIt.registerLazySingleton<RemoteAssetService>(
      () => RemoteAssetService(),
    );
    getIt.registerLazySingleton<DownloadService>(() => DownloadService());
  });

  test('fetches and parses the bibles v1 manifest', () async {
    final source = ManifestSource();

    final entries = await source.fetchManifest(
      resourceType: 'bibles',
      typeVersion: 1,
    );

    expect(entries, hasLength(4));

    final byId = {for (final e in entries) e.id: e};

    expect(byId.keys, containsAll(['arb_vdv', 'fra_lsg', 'por_blj', 'spa_blm']));

    final spa = byId['spa_blm']!;
    expect(spa.resourceName, 'Santa Biblia Literal Mexicana');
    expect(spa.creatorName, 'Ministerio Bíblico Literal');
    expect(spa.size, 1933007);
    expect(
      spa.sha256,
      '42ee6d66b519b2b3acfff552ce40a0ba1a51738d6cb4c99366bdcaca511524dc',
    );
    expect(spa.updatedAt, '2025-01-15T00:00:00Z');
  });

  test('fetches and parses the glosses v1 manifest', () async {
    final source = ManifestSource();

    final entries = await source.fetchManifest(
      resourceType: 'glosses',
      typeVersion: 1,
    );

    expect(entries, hasLength(4));

    final byId = {for (final e in entries) e.id: e};

    expect(byId.keys, containsAll(['are', 'fra', 'por', 'spa']));

    final spa = byId['spa']!;
    expect(spa.resourceName, 'Spanish Glosses');
    expect(spa.size, 3248324);
  });

  test('404 manifest throws HttpException', () async {
    final source = ManifestSource();

    expect(
      () => source.fetchManifest(resourceType: 'nope', typeVersion: 1),
      throwsA(isA<HttpException>()),
    );
  });
}
