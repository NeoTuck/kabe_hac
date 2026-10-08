import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

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

  Future<PackageFetchResult> fetch(
    Uri uri,
    File destination, {
    int? expectedBytes,
  });
}

class HttpPackageFileFetcher extends PackageFileFetcher {
  HttpPackageFileFetcher({
    HttpClient? client,
    this.timeout = const Duration(seconds: 30),
    this.maximumBytes = 512 * 1024 * 1024,
  }) : _client = client ?? HttpClient();
  final HttpClient _client;
  final Duration timeout;
  final int maximumBytes;

  @override
  Future<PackageFetchResult> fetch(
    Uri uri,
    File destination, {
    int? expectedBytes,
  }) async {
    if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      throw const PackageDownloadException('Güvensiz indirme bağlantısı.');
    }
    final limit = expectedBytes ?? maximumBytes;
    if (limit < 0 || timeout <= Duration.zero) {
      throw ArgumentError('Geçersiz indirme sınırı.');
    }
    await destination.parent.create(recursive: true);
    var existingBytes = await destination.exists()
        ? await destination.length()
        : 0;
    if (existingBytes > limit) {
      await destination.delete();
      existingBytes = 0;
    }
    final pending = _client.getUrl(uri);
    late final HttpClientRequest request;
    try {
      request = await pending.timeout(timeout);
    } catch (_) {
      // A late request must not keep a connection alive after timeout.
      unawaited(
        pending
            .then((lateRequest) => lateRequest.abort())
            .catchError((Object _) {}),
      );
      rethrow;
    }
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    if (existingBytes > 0) {
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
    }
    try {
      final response = await request.close().timeout(timeout);
      final resumed =
          existingBytes > 0 && response.statusCode == HttpStatus.partialContent;
      Future<void> reject(String message) async {
        await response.listen(null).cancel();
        throw PackageDownloadException(message);
      }

      if (response.isRedirect) {
        await reject('İndirme yönlendirmesi güvenlik nedeniyle reddedildi.');
      }
      if (response.statusCode != HttpStatus.ok && !resumed) {
        await reject('Sunucu indirmeyi reddetti: HTTP ${response.statusCode}');
      }
      int? rangeLength;
      if (resumed) {
        final range = RegExp(r'^bytes ([0-9]+)-([0-9]+)/([0-9]+)$').firstMatch(
          response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
        );
        if (range == null ||
            int.parse(range[1]!) != existingBytes ||
            int.parse(range[2]!) < existingBytes ||
            int.parse(range[3]!) <= int.parse(range[2]!) ||
            (expectedBytes != null && int.parse(range[3]!) != expectedBytes)) {
          await reject('İndirme devam aralığı doğrulanamadı.');
        }
        if (range != null) {
          rangeLength = int.parse(range[2]!) - int.parse(range[1]!) + 1;
        }
      }
      final offset = resumed ? existingBytes : 0;
      if (response.contentLength >= 0 &&
          response.contentLength + offset > limit) {
        await reject('Dosya beklenen boyuttan büyük.');
      }
      if (rangeLength != null &&
          response.contentLength >= 0 &&
          response.contentLength != rangeLength) {
        await reject('İndirme devam boyutu doğrulanamadı.');
      }
      var received = offset;
      Stream<List<int>> bounded() async* {
        await for (final chunk in response.timeout(timeout)) {
          received += chunk.length;
          if (received > limit) {
            throw const PackageDownloadException(
              'Dosya beklenen boyuttan büyük.',
            );
          }
          yield chunk;
        }
        if (expectedBytes != null && received != expectedBytes) {
          throw const PackageDownloadException('Dosya indirmesi eksik.');
        }
        if (rangeLength != null && received - offset != rangeLength) {
          throw const PackageDownloadException(
            'İndirme devam boyutu uyuşmuyor.',
          );
        }
      }

      final sink = destination.openWrite(
        mode: resumed ? FileMode.append : FileMode.write,
      );
      try {
        await sink.addStream(bounded());
        await sink.flush();
      } finally {
        await sink.close();
      }
      return PackageFetchResult(resumed: resumed);
    } catch (_) {
      request.abort();
      rethrow;
    }
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
    await manager.requireOwnedStaging(staging);
    await for (final entity in staging.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw const PackageDownloadException(
          'İndirme klasörü sembolik bağ içeremez.',
        );
      }
    }
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
          await destination.length() >= entry.sizeBytes) {
        if (await destination.length() == entry.sizeBytes &&
            (await sha256.bind(destination.openRead()).first).toString() ==
                entry.sha256Hex) {
          continue;
        }
        await destination.delete();
      }
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final result = await fetcher.fetch(
            uri,
            destination,
            expectedBytes: entry.sizeBytes,
          );
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
