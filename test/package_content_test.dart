import 'draft_catalog_fixture.dart';

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Map<String, dynamic> source;
  final trusted = <String>[];
  late OfflinePackageManager manager;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('package_content_');
    source = jsonDecode(
      await readDraftCatalogText(GuideType.umrah),
    ) as Map<String, dynamic>;
    trusted.clear();
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> install({
    String version = '1.0.0',
    String packageId = 'umre-content-tr',
    String? audioPath,
    String kind = 'audio',
    bool useDraft = false,
    bool partial = false,
  }) async {
    source['contentVersion'] = version;
    if (!useDraft) {
      // Explicit test fixture: production has no bundled religious catalog.
      source['audioRecords'] = [];
      source['prayerRecords'] = [];
      for (final step in source['steps'] as List) {
        step['status'] = 'approved';
        step['reviewedBy'] = 'TEST FIXTURE';
        step['reviewedAt'] = '2026-10-14';
        step.remove('audioId');
        step['audioIds'] = [];
        step['prayerIds'] = [];
      }
      if (partial) {
        source['steps'] = (source['steps'] as List).take(3).toList();
      }
    }
    if (audioPath != null) {
      // Fake rights and review fields exist only inside this test package.
      source['audioRecords'] = [
        {
          'id': 'test-audio',
          'status': 'approved',
          'kind': 'turkishNarration',
          'textId': 'U01.1',
          'textVersion': '1.0.0',
          'asset': audioPath,
          'recordingOwner': 'TEST FIXTURE',
          'rights': 'TEST FIXTURE',
          'reviewedBy': 'TEST FIXTURE',
          'reviewedAt': '2026-10-14',
        },
      ];
      source['steps'][0]['textVersion'] = '1.0.0';
      source['steps'][0]['audioId'] = 'test-audio';
    }
    final files = <String, List<int>>{
      'content/umre_inventory.v1.json': utf8.encode(jsonEncode(source)),
      'audio/test.m4a': utf8.encode('technical fixture $version'),
    };
    final manifest = OfflinePackageManifest.fromJson({
      'schemaVersion': 1,
      'packageId': packageId,
      'kind': kind,
      'version': version,
      'changeClass': 'C0',
      'minContentSchema': 1,
      'maxContentSchema': 1,
      'totalBytes': files.values.fold<int>(
        0,
        (sum, bytes) => sum + bytes.length,
      ),
      'files': [
        for (final entry in files.entries)
          {
            'path': entry.key,
            'sizeBytes': entry.value.length,
            'sha256': sha256.convert(entry.value).toString(),
          },
      ],
    });
    trusted.add(PinnedManifestDigestPolicy.digestFor(manifest));
    manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy(trusted),
    );
    final directory = await manager.createStagingDirectory(manifest);
    for (final entry in files.entries) {
      final file = File('${directory.path}/${entry.key}');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value);
    }
    await manager.activate(manifest, directory);
  }

  test('eski taslak paket yeniden kullanılamaz', () async {
    await install(useDraft: true);
    final catalog = (await LocalContentRepository(packages: manager)
        .load())[GuideType.umrah]!;
    expect(catalog.steps, isEmpty);
    expect(catalog.audioRecords, isEmpty);
  });

  test(
    'yalnız onaylı ilk içerik dilimi açılır ve tam hazır sayılmaz',
    () async {
      await install(partial: true);
      final catalog = (await LocalContentRepository(packages: manager)
          .load())[GuideType.umrah]!;
      expect(catalog.steps.map((step) => step.id), ['U01.1', 'U01.2', 'U02.1']);
      expect(catalog.isComplete, isFalse);
      expect(catalog.isPreview, isTrue);
      expect(catalog.audioRecords, isEmpty);
    },
  );

  test(
    'aktif katalog ve ses yeniden açmada, geri dönüşte ve silmede çözülür',
    () async {
      await install(audioPath: 'audio/test.m4a');
      final first = await LocalContentRepository(packages: manager).load();
      expect(first[GuideType.umrah]!.contentVersion, '1.0.0');
      final reference =
          first[GuideType.umrah]!.audioRecords['test-audio']!.asset!;
      expect(reference, 'package:umre-content-tr/audio/test.m4a');
      expect(
        await (await resolvePackageAudio(reference, manager))!.readAsString(),
        'technical fixture 1.0.0',
      );
      await install(version: '1.1.0', audioPath: 'audio/test.m4a');
      expect(
        (await LocalContentRepository(
          packages: manager,
        ).load())[GuideType.umrah]!.contentVersion,
        '1.1.0',
      );
      await manager.rollback('umre-content-tr');
      expect(
        (await LocalContentRepository(
          packages: manager,
        ).load())[GuideType.umrah]!.contentVersion,
        '1.0.0',
      );
      await manager.deletePackage('umre-content-tr');
      expect(
        (await LocalContentRepository(
          packages: manager,
        ).load())[GuideType.umrah]!.audioRecords.containsKey('test-audio'),
        isFalse,
      );
      await expectLater(
        resolvePackageAudio(reference, manager),
        throwsA(isA<PackageFormatException>()),
      );
    },
  );

  test('etkinleştirme sonrası bozulan katalog gömülü rehbere döner', () async {
    await install();
    final state = (await manager.readActivation('umre-content-tr'))!;
    await File(
      '${manager.activeDirectory(state).path}/content/umre_inventory.v1.json',
    ).writeAsString('{}');
    expect(
      (await LocalContentRepository(
        packages: manager,
      ).load())[GuideType.umrah]!.contentVersion,
      isNot('1.0.0'),
    );
  });

  test('bozuk ses çalınmaz ve paket kataloğu uygulanmaz', () async {
    await install(audioPath: 'audio/test.m4a');
    final state = (await manager.readActivation('umre-content-tr'))!;
    await File('${manager.activeDirectory(state).path}/audio/test.m4a')
        .writeAsString('tampered');
    await expectLater(
      resolvePackageAudio('package:umre-content-tr/audio/test.m4a', manager),
      throwsA(isA<PackageFormatException>()),
    );
    expect(
      (await LocalContentRepository(
        packages: manager,
      ).load())[GuideType.umrah]!.audioRecords.containsKey('test-audio'),
      isFalse,
    );
  });

  test(
    'paket katalogları ağ ve traversal ses başvurularını reddeder',
    () async {
      await install(audioPath: 'https://example.test/test.m4a');
      expect(
        (await LocalContentRepository(
          packages: manager,
        ).load())[GuideType.umrah]!.audioRecords.containsKey('test-audio'),
        isFalse,
      );
      await expectLater(
        resolvePackageAudio(
          'package:umre-content-tr/audio/../../outside',
          manager,
        ),
        throwsA(isA<PackageFormatException>()),
      );
      await expectLater(
        resolvePackageAudio('package:umre-content-tr/audio/test.m4a', null),
        throwsA(isA<PackageFormatException>()),
      );
    },
  );

  test('güven geri çekilirse kurulu dosya kullanılamaz', () async {
    await install();
    final untrusted = OfflinePackageManager(root: root);
    await expectLater(
      resolvePackageAudio('package:umre-content-tr/audio/test.m4a', untrusted),
      throwsA(isA<PackageFormatException>()),
    );
  });

  test(
    'yanlış türde veya çakışan katalog gömülü rehberi değiştirmez',
    () async {
      await install(kind: 'travel');
      expect(
        (await LocalContentRepository(
          packages: manager,
        ).load())[GuideType.umrah]!.contentVersion,
        isNot('1.0.0'),
      );
      // A distinct version avoids replacing the already installed travel manifest.
      await install(version: '1.0.1');
      await install(packageId: 'umre-second-tr', version: '1.1.0');
      final catalogs = await LocalContentRepository(packages: manager).load();
      expect(
        catalogs[GuideType.umrah]!.contentVersion,
        isNot(anyOf('1.0.1', '1.1.0')),
      );
      expect(catalogs[GuideType.hajj]!.steps, isEmpty);
    },
  );
  test('manifest dışı dosya ve ses sembolik bağı kullanılamaz', () async {
    await install(audioPath: 'audio/test.m4a');
    expect(
      await manager.resolveActiveFile('umre-content-tr', 'audio/unlisted.m4a'),
      isNull,
    );
    final state = (await manager.readActivation('umre-content-tr'))!;
    final audio = File('${manager.activeDirectory(state).path}/audio/test.m4a');
    final outside = File('${root.path}/outside.m4a');
    await outside.writeAsString('technical fixture 1.0.0');
    await audio.delete();
    await Link(audio.path).create(outside.path);
    await expectLater(
      resolvePackageAudio('package:umre-content-tr/audio/test.m4a', manager),
      throwsA(isA<PackageFormatException>()),
    );
  });
}
