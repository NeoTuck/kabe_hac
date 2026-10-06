import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';
import 'package:hac_umre_sesli_rehber/package_downloader.dart';

class InterruptingFetcher extends PackageFileFetcher {
  InterruptingFetcher(this.bytes);

  final List<int> bytes;
  int calls = 0;

  @override
  Future<PackageFetchResult> fetch(Uri uri, File destination) async {
    calls++;
    await destination.parent.create(recursive: true);
    final existing = await destination.exists()
        ? await destination.length()
        : 0;
    if (calls == 1) {
      await destination.writeAsBytes(bytes.take(3).toList(), flush: true);
      throw const SocketException('test ağ kesintisi');
    }
    await destination.writeAsBytes(
      bytes.skip(existing).toList(),
      mode: FileMode.append,
      flush: true,
    );
    return PackageFetchResult(resumed: existing > 0);
  }
}

class FixedStorageProbe extends StorageCapacityProbe {
  const FixedStorageProbe(this.bytes);

  final int bytes;

  @override
  Future<int?> availableBytes(Directory directory) async => bytes;
}

OfflinePackageManifest downloadableManifest(List<int> bytes) =>
    OfflinePackageManifest.fromJson({
      'schemaVersion': 1,
      'packageId': 'umre-audio-download',
      'kind': 'audio',
      'version': '1.0.0',
      'changeClass': 'C0',
      'minContentSchema': 1,
      'maxContentSchema': 1,
      'totalBytes': bytes.length,
      'files': [
        {
          'path': 'audio/demo.m4a',
          'sha256': sha256.convert(bytes).toString(),
          'sizeBytes': bytes.length,
          'downloadUrl': 'https://packages.example.test/audio/demo.m4a',
        },
      ],
    });

void main() {
  test('ağ kesintisinden sonra kısmi dosyayı sürdürüp doğrular', () async {
    final root = await Directory.systemTemp.createTemp('package_download_');
    addTearDown(() => root.delete(recursive: true));
    final bytes = utf8.encode('doğrulanan-paket');
    final manifest = downloadableManifest(bytes);
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(manifest),
      ]),
    );
    final fetcher = InterruptingFetcher(bytes);
    final coordinator = PackageDownloadCoordinator(
      manager: manager,
      fetcher: fetcher,
      allowedHosts: const ['packages.example.test'],
      reserveBytes: 0,
      delay: (_) async {},
    );

    final report = await coordinator.download(manifest);
    expect(fetcher.calls, 2);
    expect(report.resumedFiles, {'audio/demo.m4a'});
    final state = await manager.activate(manifest, report.stagingDirectory);
    expect(state.activeVersion, '1.0.0');
  });

  test('az alan ve izin verilmeyen sunucu indirmeyi başlatmaz', () async {
    final root = await Directory.systemTemp.createTemp('package_capacity_');
    addTearDown(() => root.delete(recursive: true));
    final bytes = utf8.encode('paket-verisi');
    final manifest = downloadableManifest(bytes);
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(manifest),
      ]),
    );
    final lowSpaceFetcher = InterruptingFetcher(bytes);
    final lowSpace = PackageDownloadCoordinator(
      manager: manager,
      fetcher: lowSpaceFetcher,
      allowedHosts: const ['packages.example.test'],
      storageProbe: const FixedStorageProbe(0),
      reserveBytes: 1,
      delay: (_) async {},
    );
    await expectLater(
      lowSpace.download(manifest),
      throwsA(isA<PackageDownloadException>()),
    );
    expect(lowSpaceFetcher.calls, 0);

    final blockedFetcher = InterruptingFetcher(bytes);
    final blocked = PackageDownloadCoordinator(
      manager: manager,
      fetcher: blockedFetcher,
      allowedHosts: const ['other.example.test'],
      reserveBytes: 0,
      delay: (_) async {},
    );
    await expectLater(
      blocked.download(manifest),
      throwsA(isA<PackageDownloadException>()),
    );
    expect(blockedFetcher.calls, 0);
  });

  test(
    'kullanıcı tekrar deneyince aynı staging dosyasından sürdürür',
    () async {
      final root = await Directory.systemTemp.createTemp('package_retry_');
      addTearDown(() => root.delete(recursive: true));
      final bytes = utf8.encode('yeniden-denenen-paket');
      final manifest = downloadableManifest(bytes);
      final trust = PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(manifest),
      ]);
      final manager = OfflinePackageManager(root: root, trustPolicy: trust);
      final fetcher = InterruptingFetcher(bytes);
      final client = PackageCatalogClient(
        catalogUri: Uri.parse('https://packages.example.test/catalog.json'),
        allowedHosts: const {'packages.example.test'},
        trustPolicy: trust,
        fetcher: const _UnusedCatalogFetcher(),
      );
      final provider = ConfiguredOfflinePackageProvider(
        client: client,
        downloader: PackageDownloadCoordinator(
          manager: manager,
          fetcher: fetcher,
          allowedHosts: const ['packages.example.test'],
          maxAttempts: 1,
          reserveBytes: 0,
          delay: (_) async {},
        ),
      );

      await expectLater(
        provider.downloadAndActivate(manifest),
        throwsA(isA<PackageDownloadException>()),
      );
      final state = await provider.downloadAndActivate(manifest);
      expect(state.activeVersion, '1.0.0');
      expect(fetcher.calls, 2);
    },
  );
}

class _UnusedCatalogFetcher extends PackageCatalogTextFetcher {
  const _UnusedCatalogFetcher();

  @override
  Future<String> fetch(Uri uri) async => '{}';
}
