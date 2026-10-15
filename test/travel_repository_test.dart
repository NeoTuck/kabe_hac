import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/travel_repository.dart';

void main() {
  late Directory root;
  late OfflinePackageManager manager;
  final trusted = <String>[];
  setUp(() async {
    root = await Directory.systemTemp.createTemp('travel_repository_');
    trusted.clear();
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> install({
    String id = 'travel-test',
    String version = '1.0.0',
    String kind = 'travel',
    bool invalid = false,
  }) async {
    final bytes = utf8.encode(
      jsonEncode({
        'schemaVersion': 1,
        'dataVersion': version,
        'points': [
          {
            'id': 'TEST-POI',
            'region': 'mecca',
            'nameTr': 'Teknik test yeri',
            'latitude': 0,
            'longitude': 0,
            'category': 'meetingPoint',
            'sourceTitle': 'Teknik fixture; saha verisi değildir',
            'sourceUrl': 'https://example.test/fixture',
            'verifiedAt': '2026-10-08T00:00:00Z',
            'isTestData': true,
          },
        ],
        'routes': invalid ? 'invalid' : [],
      }),
    );
    final manifest = OfflinePackageManifest.fromJson({
      'schemaVersion': 1,
      'packageId': id,
      'kind': kind,
      'version': version,
      'changeClass': 'C0',
      'minContentSchema': 1,
      'maxContentSchema': 1,
      'totalBytes': bytes.length,
      'files': [
        {
          'path': LocalTravelRepository.catalogPath,
          'sizeBytes': bytes.length,
          'sha256': sha256.convert(bytes).toString(),
        },
      ],
    });
    trusted.add(PinnedManifestDigestPolicy.digestFor(manifest));
    manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy(trusted),
    );
    final staging = await manager.createStagingDirectory(manifest);
    final file = File('${staging.path}/${LocalTravelRepository.catalogPath}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    await manager.activate(manifest, staging);
  }

  test(
    'trusted catalog survives reopening, update, rollback and deletion',
    () async {
      await install();
      final repository = LocalTravelRepository(packages: manager);
      expect((await repository.load()).points.single.isTestData, isTrue);
      await install(version: '1.1.0');
      expect(
        (await LocalTravelRepository(packages: manager).load()).dataVersion,
        '1.1.0',
      );
      await manager.rollback('travel-test');
      expect((await repository.load()).dataVersion, '1.0.0');
      await manager.deletePackage('travel-test');
      expect((await repository.load()).points, isEmpty);
    },
  );

  test('corruption and revoked trust never expose catalog data', () async {
    await install();
    expect(
      (await LocalTravelRepository(
        packages: OfflinePackageManager(root: root),
      ).load()).points,
      isEmpty,
    );
    final state = (await manager.readActivation('travel-test'))!;
    await File(
      '${manager.activeDirectory(state).path}/${LocalTravelRepository.catalogPath}',
    ).writeAsString('{}');
    expect(
      (await LocalTravelRepository(packages: manager).load()).points,
      isEmpty,
    );
  });

  test('wrong kind and malformed catalogs fail closed', () async {
    await install(kind: 'audio');
    expect(
      (await LocalTravelRepository(packages: manager).load()).points,
      isEmpty,
    );
    await install(id: 'invalid-travel', invalid: true);
    expect(
      (await LocalTravelRepository(packages: manager).load()).points,
      isEmpty,
    );
  });

  test('multiple publishers cannot silently override each other', () async {
    await install();
    await install(id: 'second-travel', version: '2.0.0');
    expect(
      (await LocalTravelRepository(packages: manager).load()).points,
      isEmpty,
    );
  });

  test('symlinked catalog is rejected even with the same bytes', () async {
    await install();
    final state = (await manager.readActivation('travel-test'))!;
    final file = File(
      '${manager.activeDirectory(state).path}/${LocalTravelRepository.catalogPath}',
    );
    final outside = File('${root.path}/outside.json');
    await outside.writeAsBytes(await file.readAsBytes());
    await file.delete();
    await Link(file.path).create(outside.path);
    expect(
      (await LocalTravelRepository(packages: manager).load()).points,
      isEmpty,
    );
  });
}
