import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';

class FixedCatalogFetcher extends PackageCatalogTextFetcher {
  const FixedCatalogFetcher(this.text);

  final String text;

  @override
  Future<String> fetch(Uri uri) async => text;
}

Map<String, Object?> catalogManifest(
  List<int> bytes, {
  String host = 'packages.example.test',
}) => {
  'schemaVersion': 1,
  'packageId': 'umre-audio-tr',
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
      'downloadUrl': 'https://$host/audio/demo.m4a',
    },
  ],
};

void main() {
  test('yalnız izinli ve sabit özeti güvenilen katalog yüklenir', () async {
    final raw = catalogManifest(utf8.encode('paket'));
    final manifest = OfflinePackageManifest.fromJson(raw);
    final catalog = jsonEncode({
      'schemaVersion': 1,
      'packages': [raw],
    });
    final client = PackageCatalogClient(
      catalogUri: Uri.parse('https://packages.example.test/catalog.json'),
      allowedHosts: const {'packages.example.test'},
      trustPolicy: PinnedManifestDigestPolicy([
        PinnedManifestDigestPolicy.digestFor(manifest),
      ]),
      fetcher: FixedCatalogFetcher(catalog),
    );

    final loaded = await client.load();
    expect(loaded.single.packageId, 'umre-audio-tr');
    expect(loaded.single.files.single.downloadUri?.scheme, 'https');
  });

  test(
    'güvenilmeyen manifest ve izin verilmeyen dosya sunucusu reddedilir',
    () async {
      final raw = catalogManifest(utf8.encode('paket'));
      final catalog = jsonEncode({
        'schemaVersion': 1,
        'packages': [raw],
      });
      final untrusted = PackageCatalogClient(
        catalogUri: Uri.parse('https://packages.example.test/catalog.json'),
        allowedHosts: const {'packages.example.test'},
        trustPolicy: PinnedManifestDigestPolicy(const []),
        fetcher: FixedCatalogFetcher(catalog),
      );
      await expectLater(
        untrusted.load(),
        throwsA(isA<PackageFormatException>()),
      );

      final otherHostRaw = catalogManifest(
        utf8.encode('paket'),
        host: 'other.example.test',
      );
      final otherHostManifest = OfflinePackageManifest.fromJson(otherHostRaw);
      final blockedFile = PackageCatalogClient(
        catalogUri: Uri.parse('https://packages.example.test/catalog.json'),
        allowedHosts: const {'packages.example.test'},
        trustPolicy: PinnedManifestDigestPolicy([
          PinnedManifestDigestPolicy.digestFor(otherHostManifest),
        ]),
        fetcher: FixedCatalogFetcher(
          jsonEncode({
            'schemaVersion': 1,
            'packages': [otherHostRaw],
          }),
        ),
      );
      await expectLater(
        blockedFile.load(),
        throwsA(isA<PackageCatalogException>()),
      );
    },
  );

  test('izin verilmeyen veya HTTP katalog adresi okunmaz', () async {
    for (final uri in [
      Uri.parse('https://other.example.test/catalog.json'),
      Uri.parse('http://packages.example.test/catalog.json'),
    ]) {
      final client = PackageCatalogClient(
        catalogUri: uri,
        allowedHosts: const {'packages.example.test'},
        trustPolicy: PinnedManifestDigestPolicy(const []),
        fetcher: const FixedCatalogFetcher('{}'),
      );
      await expectLater(client.load(), throwsA(isA<PackageCatalogException>()));
    }
  });
}
