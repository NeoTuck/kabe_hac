import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'offline_package.dart';

class PackageDownloadException implements Exception {
  const PackageDownloadException(this.message);

  final String message;

  @override
  String toString() => 'PackageDownloadException: $message';
}

class PackageFetchResult {
  const PackageFetchResult({required this.resumed});

  final bool resumed;
}

abstract class PackageFileFetcher {
  const PackageFileFetcher();

  Future<PackageFetchResult> fetch(Uri uri, File destination);
}

class HttpPackageFileFetcher extends PackageFileFetcher {
  HttpPackageFileFetcher({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<PackageFetchResult> fetch(Uri uri, File destination) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const PackageDownloadException('Güvensiz indirme bağlantısı.');
    }
    await destination.parent.create(recursive: true);
    final existingBytes = await destination.exists()
        ? await destination.length()
        : 0;
    final request = await _client.getUrl(uri);
    request.followRedirects = false;
    if (existingBytes > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
    }
    final response = await request.close();
    if (response.isRedirect) {
      await response.drain<void>();
      throw const PackageDownloadException(
        'İndirme yönlendirmesi güvenlik nedeniyle reddedildi.',
      );
    }
    final resumed =
        existingBytes > 0 && response.statusCode == HttpStatus.partialContent;
    if (response.statusCode != HttpStatus.ok && !resumed) {
      await response.drain<void>();
      throw PackageDownloadException(
        'Sunucu indirmeyi reddetti: HTTP ${response.statusCode}',
      );
    }
    final sink = destination.openWrite(
      mode: resumed ? FileMode.append : FileMode.write,
    );
    try {
      await response.forEach(sink.add);
      await sink.flush();
    } finally {
      await sink.close();
    }
    return PackageFetchResult(resumed: resumed);
  }

  void close() => _client.close(force: true);
}

abstract class StorageCapacityProbe {
  const StorageCapacityProbe();

  Future<int?> availableBytes(Directory directory);
}

class UnknownStorageCapacity extends StorageCapacityProbe {
  const UnknownStorageCapacity();

  @override
  Future<int?> availableBytes(Directory directory) async => null;
}

class PackageDownloadReport {
  const PackageDownloadReport({
    required this.stagingDirectory,
    required this.resumedFiles,
  });

  final Directory stagingDirectory;
  final Set<String> resumedFiles;
}

class PackageDownloadCoordinator {
  PackageDownloadCoordinator({
    required this.manager,
    required this.fetcher,
    required Iterable<String> allowedHosts,
    this.storageProbe = const UnknownStorageCapacity(),
    this.maxAttempts = 3,
    this.reserveBytes = 20 * 1024 * 1024,
    Future<void> Function(Duration)? delay,
  }) : allowedHosts = Set.unmodifiable(
         allowedHosts.map((host) => host.toLowerCase()),
       ),
       _delay = delay ?? Future<void>.delayed;

  final OfflinePackageManager manager;
  final PackageFileFetcher fetcher;
  final Set<String> allowedHosts;
  final StorageCapacityProbe storageProbe;
  final int maxAttempts;
  final int reserveBytes;
  final Future<void> Function(Duration) _delay;

  Future<PackageDownloadReport> download(
    OfflinePackageManifest manifest, {
    Directory? stagingDirectory,
  }) async {
    if (maxAttempts < 1 || reserveBytes < 0) {
      throw ArgumentError('Geçersiz indirme yapılandırması.');
    }
    await manager.trustPolicy.ensureTrusted(manifest);
    final staging =
        stagingDirectory ?? await manager.createStagingDirectory(manifest);
    final remainingBytes = await _remainingBytes(manifest, staging);
    final available = await storageProbe.availableBytes(staging);
    if (available != null && available < remainingBytes + reserveBytes) {
      throw const PackageDownloadException(
        'Paket için yeterli boş depolama alanı yok.',
      );
    }
    final resumedFiles = <String>{};
    for (final entry in manifest.files) {
      final uri = entry.downloadUri;
      if (uri == null) {
        throw PackageDownloadException(
          'Dosya indirme bağlantısı eksik: ${entry.relativePath}',
        );
      }
      if (!allowedHosts.contains(uri.host.toLowerCase())) {
        throw PackageDownloadException(
          'İzin verilmeyen paket sunucusu: ${uri.host}',
        );
      }
      final destination = File(
        path.joinAll([staging.path, ...entry.relativePath.split('/')]),
      );
      if (await destination.exists() &&
          await destination.length() == entry.sizeBytes) {
        continue;
      }
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final result = await fetcher.fetch(uri, destination);
          if (result.resumed) resumedFiles.add(entry.relativePath);
          lastError = null;
          break;
        } catch (error) {
          lastError = error;
          if (attempt < maxAttempts) {
            await _delay(Duration(milliseconds: 250 * attempt));
          }
        }
      }
      if (lastError != null) {
        throw PackageDownloadException(
          'Dosya indirilemedi: ${entry.relativePath}. $lastError',
        );
      }
    }
    await manager.verifyStagedPackage(manifest, staging);
    return PackageDownloadReport(
      stagingDirectory: staging,
      resumedFiles: Set.unmodifiable(resumedFiles),
    );
  }

  Future<int> _remainingBytes(
    OfflinePackageManifest manifest,
    Directory staging,
  ) async {
    var remaining = 0;
    for (final entry in manifest.files) {
      final file = File(
        path.joinAll([staging.path, ...entry.relativePath.split('/')]),
      );
      final existing = await file.exists() ? await file.length() : 0;
      remaining += entry.sizeBytes - existing.clamp(0, entry.sizeBytes);
    }
    return remaining;
  }
}
