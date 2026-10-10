import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_downloader.dart';

/// Fixture transport only: the production fetcher still requires HTTPS.
class LocalFixtureFetcher extends PackageFileFetcher {
  const LocalFixtureFetcher();

  @override
  Future<PackageFetchResult> fetch(
    Uri uri,
    File destination, {
    int? expectedBytes,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri.replace(scheme: 'http'));
      final response = await request.close();
      if (response.statusCode != 200) throw StateError('Fixture HTTP failed');
      final bytes = await response.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      if (bytes.length != expectedBytes) throw StateError('Fixture size');
      await destination.parent.create(recursive: true);
      await destination.writeAsBytes(bytes);
      return const PackageFetchResult(resumed: false);
    } finally {
      client.close(force: true);
    }
  }
}

void main() {
  test('local fixture server: download, update, rollback, delete and reject corruption', () async {
    final root = await Directory.systemTemp.createTemp('local-package-server-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final payloads = <String, List<int>>{
      '/v1/data.txt': utf8.encode('first approved fixture'),
      '/v2/data.txt': utf8.encode('second approved fixture'),
      '/bad/data.txt': utf8.encode('tampered fixture'),
    };
    server.listen((request) async {
      final bytes = payloads[request.uri.path];
      if (bytes == null) {
        request.response.statusCode = 404;
      } else {
        request.response.add(bytes);
      }
      await request.response.close();
    });
    addTearDown(() async {
      await server.close(force: true);
      await root.delete(recursive: true);
    });

    OfflinePackageManifest manifest(
      String version,
      String route,
      List<int> expected,
    ) {
      return OfflinePackageManifest.fromJson({
        'schemaVersion': 1,
        'packageId': 'local-fixture',
        'kind': 'language',
        'version': version,
        'changeClass': 'C0',
        'minContentSchema': 1,
        'maxContentSchema': 1,
        'totalBytes': expected.length,
        'files': [
          {
            'path': 'data.txt',
            'sha256': sha256.convert(expected).toString(),
            'sizeBytes': expected.length,
            'downloadUrl': 'https://127.0.0.1:${server.port}/$route/data.txt',
          },
        ],
      });
    }

    final first = manifest('1.0.0', 'v1', payloads['/v1/data.txt']!);
    final second = manifest('1.1.0', 'v2', payloads['/v2/data.txt']!);
    final bad = manifest('1.2.0', 'bad', utf8.encode('tampered fixturE'));
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(first),
        PinnedManifestDigestPolicy.digestFor(second),
        PinnedManifestDigestPolicy.digestFor(bad),
      ]),
    );
    final downloader = PackageDownloadCoordinator(
      manager: manager,
      fetcher: const LocalFixtureFetcher(),
      allowedHosts: const ['127.0.0.1'],
      reserveBytes: 0,
      maxAttempts: 1,
    );
    final firstDownload = await downloader.download(first);
    await manager.activate(first, firstDownload.stagingDirectory);
    expect(
      (await manager.readActivation('local-fixture'))!.activeVersion,
      '1.0.0',
    );

    final secondDownload = await downloader.download(second);
    await manager.activate(second, secondDownload.stagingDirectory);
    expect(
      (await manager.readActivation('local-fixture'))!.activeVersion,
      '1.1.0',
    );
    await expectLater(
      downloader.download(bad),
      throwsA(isA<PackageFormatException>()),
    );
    expect(
      (await manager.readActivation('local-fixture'))!.activeVersion,
      '1.1.0',
    );

    final restored = await manager.rollback('local-fixture');
    expect(restored.activeVersion, '1.0.0');
    expect(
      utf8.decode(
        (await manager.resolveActiveFile(
          'local-fixture',
          'data.txt',
        ))!.readAsBytesSync(),
      ),
      'first approved fixture',
    );
    await manager.deletePackage('local-fixture');
    expect(await manager.readActivation('local-fixture'), isNull);
  });
}
