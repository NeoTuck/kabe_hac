import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';

Map<String, Object?> manifestJson({
  required String version,
  required List<int> bytes,
  String filePath = 'audio/demo.m4a',
  String changeClass = 'C0',
}) => {
  'schemaVersion': 1,
  'packageId': 'umre-audio-tr',
  'kind': 'audio',
  'version': version,
  'changeClass': changeClass,
  'minContentSchema': 1,
  'maxContentSchema': 1,
  'totalBytes': bytes.length,
  'files': [
    {
      'path': filePath,
      'sha256': sha256.convert(bytes).toString(),
      'sizeBytes': bytes.length,
    },
  ],
};

class AllowTestMigration extends PackageChangeMigrationGate {
  const AllowTestMigration();

  @override
  Future<void> prepare({
    required PackageActivationState current,
    required OfflinePackageManifest next,
  }) async {}
}

Future<Directory> stage(
  OfflinePackageManager manager,
  OfflinePackageManifest manifest,
  List<int> bytes,
) async {
  final directory = await manager.createStagingDirectory(manifest);
  final file = File('${directory.path}/audio/demo.m4a');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return directory;
}

void main() {
  test('manifest yol, toplam boyut ve özet alanlarını doğrular', () {
    final bytes = utf8.encode('ilk-paket');
    final valid = OfflinePackageManifest.fromJson(
      manifestJson(version: '1.0.0', bytes: bytes),
    );
    expect(valid.totalBytes, bytes.length);
    expect(valid.changeClass, ContentChangeClass.c0);

    final traversal = manifestJson(
      version: '1.0.0',
      bytes: bytes,
      filePath: '../demo.m4a',
    );
    expect(
      () => OfflinePackageManifest.fromJson(traversal),
      throwsA(isA<PackageFormatException>()),
    );

    final wrongTotal = manifestJson(version: '1.0.0', bytes: bytes)
      ..['totalBytes'] = 999;
    expect(
      () => OfflinePackageManifest.fromJson(wrongTotal),
      throwsA(isA<PackageFormatException>()),
    );
  });

  test('bozuk paket etkinleşmez; doğrulanan sürüm geri alınabilir', () async {
    final root = await Directory.systemTemp.createTemp('offline_packages_');
    addTearDown(() => root.delete(recursive: true));
    final firstBytes = utf8.encode('ilk-paket');
    final firstManifest = OfflinePackageManifest.fromJson(
      manifestJson(version: '1.0.0', bytes: firstBytes),
    );
    final secondBytes = utf8.encode('ikinci-paket');
    final secondManifest = OfflinePackageManifest.fromJson(
      manifestJson(version: '1.1.0', bytes: secondBytes),
    );
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(firstManifest),
        PinnedManifestDigestPolicy.digestFor(secondManifest),
      ]),
    );
    final corruptStage = await stage(
      manager,
      firstManifest,
      utf8.encode('bozuk'),
    );
    await expectLater(
      manager.activate(firstManifest, corruptStage),
      throwsA(isA<PackageFormatException>()),
    );
    expect(await manager.readActivation(firstManifest.packageId), isNull);
    await corruptStage.delete(recursive: true);

    final firstStage = await stage(manager, firstManifest, firstBytes);
    final firstState = await manager.activate(firstManifest, firstStage);
    expect(firstState.activeVersion, '1.0.0');
    expect(await manager.activeDirectory(firstState).exists(), isTrue);

    final secondStage = await stage(manager, secondManifest, secondBytes);
    final secondState = await manager.activate(secondManifest, secondStage);
    expect(secondState.activeVersion, '1.1.0');
    expect(secondState.previousVersion, '1.0.0');

    final rollback = await manager.rollback(firstManifest.packageId);
    expect(rollback.activeVersion, '1.0.0');
    expect(rollback.previousVersion, '1.1.0');
  });

  test('manifestte olmayan veya eksik dosya paketi reddeder', () async {
    final root = await Directory.systemTemp.createTemp('offline_extra_');
    addTearDown(() => root.delete(recursive: true));
    final bytes = utf8.encode('paket');
    final manifest = OfflinePackageManifest.fromJson(
      manifestJson(version: '2.0.0', bytes: bytes),
    );
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(manifest),
      ]),
    );
    final directory = await stage(manager, manifest, bytes);
    await File('${directory.path}/fazla.txt').writeAsString('fazla');
    await expectLater(
      manager.verifyStagedPackage(manifest, directory),
      throwsA(isA<PackageFormatException>()),
    );
  });

  test('güven kaydı olmayan manifest etkinleştirilmez', () async {
    final root = await Directory.systemTemp.createTemp('offline_untrusted_');
    addTearDown(() => root.delete(recursive: true));
    final manager = OfflinePackageManager(root: root);
    final bytes = utf8.encode('paket');
    final manifest = OfflinePackageManifest.fromJson(
      manifestJson(version: '3.0.0', bytes: bytes),
    );
    final directory = await stage(manager, manifest, bytes);
    await expectLater(
      manager.activate(manifest, directory),
      throwsA(isA<PackageFormatException>()),
    );
  });

  test(
    'C1/C2 güncellemesi açık migrasyon kapısı olmadan etkinleşmez',
    () async {
      final root = await Directory.systemTemp.createTemp('offline_migration_');
      addTearDown(() => root.delete(recursive: true));
      final firstBytes = utf8.encode('ilk');
      final first = OfflinePackageManifest.fromJson(
        manifestJson(version: '1.0.0', bytes: firstBytes),
      );
      final secondBytes = utf8.encode('ikinci');
      final second = OfflinePackageManifest.fromJson(
        manifestJson(version: '2.0.0', bytes: secondBytes, changeClass: 'C1'),
      );
      final trusted = [
        PinnedManifestDigestPolicy.digestFor(first),
        PinnedManifestDigestPolicy.digestFor(second),
      ];
      final manager = OfflinePackageManager(
        root: root,
        trustPolicy: PinnedManifestDigestPolicy(trusted),
      );
      await manager.activate(first, await stage(manager, first, firstBytes));
      await expectLater(
        manager.activate(second, await stage(manager, second, secondBytes)),
        throwsA(isA<PackageFormatException>()),
      );
      expect(
        (await manager.readActivation(first.packageId))?.activeVersion,
        '1.0.0',
      );

      final configured = OfflinePackageManager(
        root: root,
        trustPolicy: PinnedManifestDigestPolicy(trusted),
        migrationGate: const AllowTestMigration(),
      );
      final state = await configured.activate(
        second,
        await stage(configured, second, secondBytes),
      );
      expect(state.activeVersion, '2.0.0');
    },
  );
  test(
    'etkinleştirme kaydı kimlik ve sürüm yolu eşleşmesini zorunlu tutar',
    () async {
      final root = await Directory.systemTemp.createTemp('offline_pointer_');
      addTearDown(() => root.delete(recursive: true));
      final manager = OfflinePackageManager(root: root);
      final pointer = File('${root.path}/state/umre-audio-tr.json');
      await pointer.parent.create(recursive: true);
      for (final override in [
        {'packageId': 'another-package'},
        {'activeVersion': '../../outside'},
        {'previousVersion': '../../outside'},
      ]) {
        await pointer.writeAsString(
          jsonEncode({
            'schemaVersion': 1,
            'packageId': 'umre-audio-tr',
            'activeVersion': '1.0.0',
            'previousVersion': null,
            'activatedAt': '2026-10-08T00:00:00Z',
            ...override,
          }),
        );
        await expectLater(
          manager.readActivation('umre-audio-tr'),
          throwsA(isA<PackageFormatException>()),
        );
      }
      await expectLater(
        manager.readActivation('../outside'),
        throwsA(isA<PackageFormatException>()),
      );
    },
  );

  test('yalnız yedek kaydı kalan paket listede korunur', () async {
    final root = await Directory.systemTemp.createTemp('offline_backup_');
    addTearDown(() => root.delete(recursive: true));
    final manager = OfflinePackageManager(root: root);
    final backup = File('${root.path}/state/umre-audio-tr.json.backup');
    await backup.parent.create(recursive: true);
    await backup.writeAsString(
      jsonEncode(
        PackageActivationState(
          packageId: 'umre-audio-tr',
          activeVersion: '1.0.0',
          previousVersion: null,
          activatedAt: DateTime.utc(2026, 10, 8),
        ).toJson(),
      ),
    );
    expect((await manager.listActivations()).single.activeVersion, '1.0.0');
  });

  test('eski sürüm dosya ve manifesti birlikte değiştirilse de güven kontrolü reddeder', () async {
    final root = await Directory.systemTemp.createTemp('offline_rollback_');
    addTearDown(() => root.delete(recursive: true));
    final bytes = utf8.encode('original');
    final first = OfflinePackageManifest.fromJson(
      manifestJson(version: '1.0.0', bytes: bytes),
    );
    final second = OfflinePackageManifest.fromJson(
      manifestJson(version: '1.1.0', bytes: bytes),
    );
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(first),
        PinnedManifestDigestPolicy.digestFor(second),
      ]),
    );
    await manager.activate(first, await stage(manager, first, bytes));
    await manager.activate(second, await stage(manager, second, bytes));
    final tampered = utf8.encode('tampered');
    final old = '${root.path}/packages/umre-audio-tr/1.0.0';
    await File('$old/audio/demo.m4a').writeAsBytes(tampered);
    await File('$old/package-manifest.json').writeAsString(
      jsonEncode(manifestJson(version: '1.0.0', bytes: tampered)),
    );
    await expectLater(
      manager.rollback(first.packageId),
      throwsA(isA<PackageFormatException>()),
    );
    expect(
      (await manager.readActivation(first.packageId))!.activeVersion,
      '1.1.0',
    );
  });

  test('sembolik staging klasörü etkinleştirilmez', () async {
    final root = await Directory.systemTemp.createTemp('offline_link_');
    addTearDown(() => root.delete(recursive: true));
    final external = await Directory.systemTemp.createTemp('external_stage_');
    addTearDown(() => external.delete(recursive: true));
    final manager = OfflinePackageManager(root: root);
    await Directory('${root.path}/.staging').create();
    final link = Link('${root.path}/.staging/linked');
    await link.create(external.path);
    await expectLater(
      manager.requireOwnedStaging(Directory(link.path)),
      throwsA(isA<PackageFormatException>()),
    );
  });
}
