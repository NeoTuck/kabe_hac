import 'dart:convert';
import 'dart:io';

import 'offline_package.dart';
import 'package_downloader.dart';

class PackageCatalogException implements Exception {
  const PackageCatalogException(this.message);

  final String message;

  @override
  String toString() => 'PackageCatalogException: $message';
}

class OfflinePackageRuntimeConfig {
  const OfflinePackageRuntimeConfig({
    required this.catalogUri,
    required this.allowedHosts,
    required this.trustedManifestDigests,
  });

  final Uri catalogUri;
  final Set<String> allowedHosts;
  final Set<String> trustedManifestDigests;

  static OfflinePackageRuntimeConfig? fromCompileTime() {
    const rawCatalog = String.fromEnvironment('PACKAGE_CATALOG_URL');
    const rawHosts = String.fromEnvironment('PACKAGE_ALLOWED_HOSTS');
    const rawDigests = String.fromEnvironment('PACKAGE_MANIFEST_DIGESTS');
    if (rawCatalog.isEmpty && rawHosts.isEmpty && rawDigests.isEmpty) {
      return null;
    }
    final catalogUri = Uri.tryParse(rawCatalog);
    final hosts = rawHosts
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    final digests = rawDigests
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (catalogUri == null ||
        catalogUri.scheme != 'https' ||
        catalogUri.host.isEmpty ||
        catalogUri.userInfo.isNotEmpty ||
        !hosts.contains(catalogUri.host.toLowerCase()) ||
        digests.isEmpty ||
        digests.any((value) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(value))) {
      throw const PackageCatalogException(
        'Paket kataloğu derleme yapılandırması geçersiz.',
      );
    }
    return OfflinePackageRuntimeConfig(
      catalogUri: catalogUri,
      allowedHosts: Set.unmodifiable(hosts),
      trustedManifestDigests: Set.unmodifiable(digests),
    );
  }
}

abstract class PackageCatalogTextFetcher {
  const PackageCatalogTextFetcher();

  Future<String> fetch(Uri uri);
}

class HttpPackageCatalogTextFetcher extends PackageCatalogTextFetcher {
  HttpPackageCatalogTextFetcher({
    HttpClient? client,
    int maximumBytes = 1024 * 1024,
    Duration timeout = const Duration(seconds: 30),
  }) : _files = HttpPackageFileFetcher(
         client: client,
         maximumBytes: maximumBytes,
         timeout: timeout,
       );

  final HttpPackageFileFetcher _files;

  @override
  Future<String> fetch(Uri uri) async {
    // Share the bounded, timed and redirect-safe transport with package files.
    // A fresh temporary file means catalog requests never send a Range header.
    final temporary = await Directory.systemTemp.createTemp('kabe-catalog-');
    try {
      final file = File('${temporary.path}/catalog.json');
      await _files.fetch(uri, file);
      try {
        return utf8.decode(await file.readAsBytes());
      } on FormatException {
        throw const PackageCatalogException('Paket kataloğu UTF-8 değil.');
      }
    } on PackageCatalogException {
      rethrow;
    } catch (_) {
      throw const PackageCatalogException(
        'Paket kataloğu alınamadı. Bağlantıyı kontrol edip yeniden dene.',
      );
    } finally {
      try {
        await temporary.delete(recursive: true);
      } catch (_) {}
    }
  }

  void close() => _files.close();
}

class PackageCatalogClient {
  const PackageCatalogClient({
    required this.catalogUri,
    required this.allowedHosts,
    required this.trustPolicy,
    required this.fetcher,
  });

  final Uri catalogUri;
  final Set<String> allowedHosts;
  final PackageManifestTrustPolicy trustPolicy;
  final PackageCatalogTextFetcher fetcher;

  Future<List<OfflinePackageManifest>> load() async {
    if (catalogUri.scheme != 'https' ||
        catalogUri.host.isEmpty ||
        catalogUri.userInfo.isNotEmpty ||
        !allowedHosts.contains(catalogUri.host.toLowerCase())) {
      throw const PackageCatalogException('İzin verilmeyen katalog sunucusu.');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(await fetcher.fetch(catalogUri));
    } catch (error) {
      if (error is PackageCatalogException) rethrow;
      throw const PackageCatalogException('Paket kataloğu geçerli JSON değil.');
    }
    if (decoded is! Map || decoded['schemaVersion'] != 1) {
      throw const PackageCatalogException('Desteklenmeyen paket kataloğu.');
    }
    final rawPackages = decoded['packages'];
    if (rawPackages is! List) {
      throw const PackageCatalogException('Katalog paket listesi eksik.');
    }
    final manifests = <OfflinePackageManifest>[];
    final identities = <String>{};
    for (final raw in rawPackages) {
      if (raw is! Map) {
        throw const PackageCatalogException('Katalog paketi nesne olmalı.');
      }
      final manifest = OfflinePackageManifest.fromJson(
        Map<String, Object?>.from(raw),
      );
      await trustPolicy.ensureTrusted(manifest);
      for (final file in manifest.files) {
        final uri = file.downloadUri;
        if (uri == null || !allowedHosts.contains(uri.host.toLowerCase())) {
          throw PackageCatalogException(
            'Paket dosyası izin verilmeyen sunucuda: ${file.relativePath}',
          );
        }
      }
      if (!identities.add('${manifest.packageId}@${manifest.version}')) {
        throw const PackageCatalogException('Katalogda paket sürümü tekrarlı.');
      }
      manifests.add(manifest);
    }
    manifests.sort((a, b) {
      final id = a.packageId.compareTo(b.packageId);
      return id == 0 ? a.version.compareTo(b.version) : id;
    });
    return List.unmodifiable(manifests);
  }
}

abstract class OfflinePackageProvider {
  const OfflinePackageProvider();

  Future<List<OfflinePackageManifest>> loadCatalog();
  Future<PackageActivationState> downloadAndActivate(
    OfflinePackageManifest manifest,
  );
}

class ConfiguredOfflinePackageProvider extends OfflinePackageProvider {
  const ConfiguredOfflinePackageProvider({
    required this.client,
    required this.downloader,
  });

  final PackageCatalogClient client;
  final PackageDownloadCoordinator downloader;

  @override
  Future<List<OfflinePackageManifest>> loadCatalog() => client.load();

  @override
  Future<PackageActivationState> downloadAndActivate(
    OfflinePackageManifest manifest,
  ) async {
    final staging =
        await downloader.manager.findResumableStagingDirectory(manifest) ??
        await downloader.manager.createStagingDirectory(manifest);
    final report = await downloader.download(
      manifest,
      stagingDirectory: staging,
    );
    return downloader.manager.activate(manifest, report.stagingDirectory);
  }
}
