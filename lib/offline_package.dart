import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

enum OfflinePackageKind { audio, map, travel, language }

enum ContentChangeClass { c0, c1, c2 }

class PackageFormatException implements Exception {
  const PackageFormatException(this.message);

  final String message;

  @override
  String toString() => 'PackageFormatException: $message';
}

abstract class PackageManifestTrustPolicy {
  const PackageManifestTrustPolicy();

  Future<void> ensureTrusted(OfflinePackageManifest manifest);
}

abstract class PackageChangeMigrationGate {
  const PackageChangeMigrationGate();

  Future<void> prepare({
    required PackageActivationState current,
    required OfflinePackageManifest next,
  });
}

class RejectUnconfiguredPackageMigrations extends PackageChangeMigrationGate {
  const RejectUnconfiguredPackageMigrations();

  @override
  Future<void> prepare({
    required PackageActivationState current,
    required OfflinePackageManifest next,
  }) async {
    if (next.changeClass != ContentChangeClass.c0) {
      throw const PackageFormatException(
        'C1/C2 paket güncellemesi için kayıt migrasyonu yapılandırılmadı.',
      );
    }
  }
}

class RejectUntrustedManifests extends PackageManifestTrustPolicy {
  const RejectUntrustedManifests();

  @override
  Future<void> ensureTrusted(OfflinePackageManifest manifest) async {
    throw const PackageFormatException(
      'Paket manifesti için güven kaydı yapılandırılmadı.',
    );
  }
}

class PinnedManifestDigestPolicy extends PackageManifestTrustPolicy {
  PinnedManifestDigestPolicy(Iterable<String> trustedDigests)
    : _trustedDigests = Set.unmodifiable(
        trustedDigests.map((digest) => digest.toLowerCase()),
      );

  final Set<String> _trustedDigests;

  static String digestFor(OfflinePackageManifest manifest) =>
      sha256.convert(utf8.encode(jsonEncode(manifest.toJson()))).toString();

  @override
  Future<void> ensureTrusted(OfflinePackageManifest manifest) async {
    if (!_trustedDigests.contains(digestFor(manifest))) {
      throw const PackageFormatException('Paket manifesti güvenilir değil.');
    }
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw PackageFormatException('Zorunlu alan eksik: $key');
  }
  return value.trim();
}

int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int || value < 1) {
    throw PackageFormatException('$key pozitif tam sayı olmalı.');
  }
  return value;
}

T _enumValue<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw PackageFormatException('Geçersiz $field: $name');
}

class OfflinePackageFile {
  const OfflinePackageFile({
    required this.relativePath,
    required this.sha256Hex,
    required this.sizeBytes,
    this.downloadUri,
  });

  final String relativePath;
  final String sha256Hex;
  final int sizeBytes;
  final Uri? downloadUri;

  factory OfflinePackageFile.fromJson(Map<String, Object?> json) {
    final rawPath = _requiredString(json, 'path');
    final normalized = path.posix.normalize(rawPath.replaceAll('\\', '/'));
    if (normalized == '.' ||
        normalized.startsWith('../') ||
        normalized.startsWith('/') ||
        rawPath.contains('\\') ||
        normalized != rawPath) {
      throw PackageFormatException('Güvensiz paket dosya yolu: $rawPath');
    }
    final hash = _requiredString(json, 'sha256').toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw PackageFormatException('Geçersiz SHA-256: $rawPath');
    }
    final size = json['sizeBytes'];
    if (size is! int || size < 0) {
      throw PackageFormatException('Geçersiz dosya boyutu: $rawPath');
    }
    final rawUrl = json['downloadUrl'];
    Uri? downloadUri;
    if (rawUrl != null) {
      if (rawUrl is! String) {
        throw PackageFormatException('Geçersiz indirme bağlantısı: $rawPath');
      }
      downloadUri = Uri.tryParse(rawUrl);
      if (downloadUri == null ||
          downloadUri.scheme != 'https' ||
          downloadUri.host.isEmpty ||
          downloadUri.userInfo.isNotEmpty) {
        throw PackageFormatException('Geçersiz indirme bağlantısı: $rawPath');
      }
    }
    return OfflinePackageFile(
      relativePath: normalized,
      sha256Hex: hash,
      sizeBytes: size,
      downloadUri: downloadUri,
    );
  }

  Map<String, Object?> toJson() => {
    'path': relativePath,
    'sha256': sha256Hex,
    'sizeBytes': sizeBytes,
    if (downloadUri != null) 'downloadUrl': downloadUri.toString(),
  };
}

class OfflinePackageManifest {
  const OfflinePackageManifest({
    required this.packageId,
    required this.kind,
    required this.version,
    required this.changeClass,
    required this.minContentSchema,
    required this.maxContentSchema,
    required this.totalBytes,
    required this.files,
  });

  static const schemaVersion = 1;

  final String packageId;
  final OfflinePackageKind kind;
  final String version;
  final ContentChangeClass changeClass;
  final int minContentSchema;
  final int maxContentSchema;
  final int totalBytes;
  final List<OfflinePackageFile> files;

  factory OfflinePackageManifest.fromJsonText(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const PackageFormatException('Manifest geçerli JSON değil.');
    }
    if (decoded is! Map) {
      throw const PackageFormatException('Manifest nesne olmalı.');
    }
    return OfflinePackageManifest.fromJson(Map<String, Object?>.from(decoded));
  }

  factory OfflinePackageManifest.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const PackageFormatException('Desteklenmeyen manifest şeması.');
    }
    final packageId = _requiredString(json, 'packageId');
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(packageId)) {
      throw PackageFormatException('Geçersiz paket kimliği: $packageId');
    }
    final version = _requiredString(json, 'version');
    if (!RegExp(r'^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][a-zA-Z0-9.-]+)?$')
        .hasMatch(version)) {
      throw PackageFormatException('Geçersiz paket sürümü: $version');
    }
    final minSchema = _requiredPositiveInt(json, 'minContentSchema');
    final maxSchema = _requiredPositiveInt(json, 'maxContentSchema');
    if (minSchema > maxSchema) {
      throw const PackageFormatException('Şema uyumluluk aralığı ters.');
    }
    final rawFiles = json['files'];
    if (rawFiles is! List || rawFiles.isEmpty) {
      throw const PackageFormatException('Manifest en az bir dosya içermeli.');
    }
    final files = <OfflinePackageFile>[];
    for (final value in rawFiles) {
      if (value is! Map) {
        throw const PackageFormatException('Paket dosyası nesne olmalı.');
      }
      files.add(OfflinePackageFile.fromJson(Map<String, Object?>.from(value)));
    }
    if (files.map((file) => file.relativePath).toSet().length != files.length) {
      throw const PackageFormatException('Manifest dosya yolları tekrarlı.');
    }
    final totalBytes = json['totalBytes'];
    if (totalBytes is! int || totalBytes < 0) {
      throw const PackageFormatException('Geçersiz toplam paket boyutu.');
    }
    final calculatedTotal = files.fold<int>(
      0,
      (sum, file) => sum + file.sizeBytes,
    );
    if (calculatedTotal != totalBytes) {
      throw const PackageFormatException('Toplam paket boyutu uyuşmuyor.');
    }
    return OfflinePackageManifest(
      packageId: packageId,
      kind: _enumValue(
        OfflinePackageKind.values,
        _requiredString(json, 'kind'),
        'paket türü',
      ),
      version: version,
      changeClass: _enumValue(
        ContentChangeClass.values,
        _requiredString(json, 'changeClass').toLowerCase(),
        'değişiklik sınıfı',
      ),
      minContentSchema: minSchema,
      maxContentSchema: maxSchema,
      totalBytes: totalBytes,
      files: List.unmodifiable(files),
    );
  }

  bool supportsContentSchema(int version) =>
      version >= minContentSchema && version <= maxContentSchema;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'packageId': packageId,
    'kind': kind.name,
    'version': version,
    'changeClass': changeClass.name.toUpperCase(),
    'minContentSchema': minContentSchema,
    'maxContentSchema': maxContentSchema,
    'totalBytes': totalBytes,
    'files': files.map((file) => file.toJson()).toList(),
  };
}

class PackageActivationState {
  const PackageActivationState({
    required this.packageId,
    required this.activeVersion,
    required this.previousVersion,
    required this.activatedAt,
  });

  final String packageId;
  final String activeVersion;
  final String? previousVersion;
  final DateTime activatedAt;

  factory PackageActivationState.fromJson(Map<String, Object?> json) {
    final previous = json['previousVersion'];
    final activatedAt = DateTime.tryParse(_requiredString(json, 'activatedAt'));
    if (activatedAt == null || (previous != null && previous is! String)) {
      throw const PackageFormatException('Paket etkinleştirme kaydı bozuk.');
    }
    return PackageActivationState(
      packageId: _requiredString(json, 'packageId'),
      activeVersion: _requiredString(json, 'activeVersion'),
      previousVersion: previous as String?,
      activatedAt: activatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'packageId': packageId,
    'activeVersion': activeVersion,
    'previousVersion': previousVersion,
    'activatedAt': activatedAt.toUtc().toIso8601String(),
  };
}

abstract class OfflinePackageStore {
  const OfflinePackageStore();

  Future<List<PackageActivationState>> listActivations();
  Future<void> deletePackage(String packageId);
  Future<PackageActivationState> rollback(String packageId);
}

class OfflinePackageManager extends OfflinePackageStore {
  OfflinePackageManager({
    required this.root,
    this.supportedContentSchema = 1,
    PackageManifestTrustPolicy? trustPolicy,
    PackageChangeMigrationGate? migrationGate,
  }) : trustPolicy = trustPolicy ?? const RejectUntrustedManifests(),
       migrationGate =
           migrationGate ?? const RejectUnconfiguredPackageMigrations();

  static const _manifestFileName = 'package-manifest.json';

  final Directory root;
  final int supportedContentSchema;
  final PackageManifestTrustPolicy trustPolicy;
  final PackageChangeMigrationGate migrationGate;

  Directory get _stagingRoot => Directory(path.join(root.path, '.staging'));
  Directory get _packagesRoot => Directory(path.join(root.path, 'packages'));
  Directory get _stateRoot => Directory(path.join(root.path, 'state'));

  Future<Directory> createStagingDirectory(
    OfflinePackageManifest manifest,
  ) async {
    await _stagingRoot.create(recursive: true);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final digest = PinnedManifestDigestPolicy.digestFor(manifest)
        .substring(0, 12);
    return Directory(
      path.join(
        _stagingRoot.path,
        '${manifest.packageId}-${manifest.version}-$digest-$stamp',
      ),
    )..createSync(recursive: true);
  }

  Future<Directory?> findResumableStagingDirectory(
    OfflinePackageManifest manifest,
  ) async {
    if (!await _stagingRoot.exists()) return null;
    final digest = PinnedManifestDigestPolicy.digestFor(manifest)
        .substring(0, 12);
    final prefix = '${manifest.packageId}-${manifest.version}-$digest-';
    final candidates = <Directory>[];
    await for (final entity in _stagingRoot.list(followLinks: false)) {
      if (entity is Directory &&
          path.basename(entity.path).startsWith(prefix)) {
        candidates.add(entity);
      }
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.path.compareTo(a.path));
    return candidates.first;
  }

  Future<void> verifyStagedPackage(
    OfflinePackageManifest manifest,
    Directory directory, {
    bool allowStoredManifest = false,
  }) async {
    if (!manifest.supportsContentSchema(supportedContentSchema)) {
      throw const PackageFormatException(
        'Paket bu içerik şemasıyla uyumlu değil.',
      );
    }
    if (!await directory.exists()) {
      throw const PackageFormatException('Paket klasörü bulunamadı.');
    }
    final actualPaths = <String>{};
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is Link) {
        throw const PackageFormatException('Paket sembolik bağ içeremez.');
      }
      if (entity is File) {
        final relative = path
            .relative(entity.path, from: directory.path)
            .split(path.separator)
            .join('/');
        if (allowStoredManifest && relative == _manifestFileName) continue;
        actualPaths.add(relative);
      }
    }
    final expectedPaths = manifest.files
        .map((file) => file.relativePath)
        .toSet();
    if (actualPaths.length != expectedPaths.length ||
        !actualPaths.containsAll(expectedPaths)) {
      throw const PackageFormatException(
        'Paket eksik veya manifestte olmayan dosya içeriyor.',
      );
    }
    for (final entry in manifest.files) {
      final file = File(
        path.joinAll([directory.path, ...entry.relativePath.split('/')]),
      );
      final size = await file.length();
      if (size != entry.sizeBytes) {
        throw PackageFormatException(
          'Dosya boyutu uyuşmuyor: ${entry.relativePath}',
        );
      }
      final digest = await sha256.bind(file.openRead()).first;
      if (digest.toString() != entry.sha256Hex) {
        throw PackageFormatException(
          'Dosya özeti uyuşmuyor: ${entry.relativePath}',
        );
      }
    }
  }

  Future<PackageActivationState> activate(
    OfflinePackageManifest manifest,
    Directory stagingDirectory,
  ) async {
    _requireOwnedStaging(stagingDirectory);
    await trustPolicy.ensureTrusted(manifest);
    await verifyStagedPackage(manifest, stagingDirectory);
    final current = await readActivation(manifest.packageId);
    if (current != null && current.activeVersion != manifest.version) {
      await migrationGate.prepare(current: current, next: manifest);
    }
    await _packagesRoot.create(recursive: true);
    final packageRoot = Directory(
      path.join(_packagesRoot.path, manifest.packageId),
    );
    await packageRoot.create(recursive: true);
    final target = Directory(path.join(packageRoot.path, manifest.version));
    await File(path.join(stagingDirectory.path, _manifestFileName))
        .writeAsString(jsonEncode(manifest.toJson()), flush: true);
    if (await target.exists()) {
      final installedManifest = await _readManifest(target);
      if (jsonEncode(installedManifest.toJson()) !=
          jsonEncode(manifest.toJson())) {
        throw const PackageFormatException(
          'Aynı sürüm farklı manifestle zaten kurulu.',
        );
      }
      await verifyStagedPackage(
        installedManifest,
        target,
        allowStoredManifest: true,
      );
      await stagingDirectory.delete(recursive: true);
    } else {
      await stagingDirectory.rename(target.path);
    }
    final state = PackageActivationState(
      packageId: manifest.packageId,
      activeVersion: manifest.version,
      previousVersion: current?.activeVersion == manifest.version
          ? current?.previousVersion
          : current?.activeVersion,
      activatedAt: DateTime.now().toUtc(),
    );
    await _writeActivation(state);
    return state;
  }

  Future<PackageActivationState?> readActivation(String packageId) async {
    final pointer = _stateFile(packageId);
    final backup = File('${pointer.path}.backup');
    File? source;
    if (await pointer.exists()) {
      source = pointer;
    } else if (await backup.exists()) {
      source = backup;
    }
    if (source == null) return null;
    Object? decoded;
    try {
      decoded = jsonDecode(await source.readAsString());
    } catch (_) {
      throw const PackageFormatException('Paket etkinleştirme kaydı bozuk.');
    }
    if (decoded is! Map || decoded['schemaVersion'] != 1) {
      throw const PackageFormatException('Paket etkinleştirme kaydı bozuk.');
    }
    return PackageActivationState.fromJson(Map<String, Object?>.from(decoded));
  }

  @override
  Future<List<PackageActivationState>> listActivations() async {
    if (!await _stateRoot.exists()) return const [];
    final states = <PackageActivationState>[];
    await for (final entity in _stateRoot.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final packageId = path.basenameWithoutExtension(entity.path);
      final state = await readActivation(packageId);
      if (state != null) states.add(state);
    }
    states.sort((a, b) => a.packageId.compareTo(b.packageId));
    return List.unmodifiable(states);
  }

  @override
  Future<void> deletePackage(String packageId) async {
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(packageId)) {
      throw PackageFormatException('Geçersiz paket kimliği: $packageId');
    }
    final directory = Directory(path.join(_packagesRoot.path, packageId));
    if (await directory.exists()) await directory.delete(recursive: true);
    final pointer = _stateFile(packageId);
    for (final file in [
      pointer,
      File('${pointer.path}.backup'),
      File('${pointer.path}.temporary'),
    ]) {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<PackageActivationState> rollback(String packageId) async {
    final current = await readActivation(packageId);
    if (current == null || current.previousVersion == null) {
      throw const PackageFormatException('Geri dönülecek paket sürümü yok.');
    }
    final previousDirectory = Directory(
      path.join(_packagesRoot.path, packageId, current.previousVersion),
    );
    final manifest = await _readManifest(previousDirectory);
    await verifyStagedPackage(
      manifest,
      previousDirectory,
      allowStoredManifest: true,
    );
    final state = PackageActivationState(
      packageId: packageId,
      activeVersion: current.previousVersion!,
      previousVersion: current.activeVersion,
      activatedAt: DateTime.now().toUtc(),
    );
    await _writeActivation(state);
    return state;
  }

  Directory activeDirectory(PackageActivationState state) => Directory(
    path.join(_packagesRoot.path, state.packageId, state.activeVersion),
  );

  void _requireOwnedStaging(Directory staging) {
    final rootPath = path.normalize(path.absolute(_stagingRoot.path));
    final stagingPath = path.normalize(path.absolute(staging.path));
    if (!path.isWithin(rootPath, stagingPath)) {
      throw const PackageFormatException(
        'Etkinleştirme klasörü paket yöneticisine ait değil.',
      );
    }
  }

  Future<OfflinePackageManifest> _readManifest(Directory directory) async {
    final file = File(path.join(directory.path, _manifestFileName));
    if (!await file.exists()) {
      throw const PackageFormatException('Kurulu paket manifesti bulunamadı.');
    }
    return OfflinePackageManifest.fromJsonText(await file.readAsString());
  }

  File _stateFile(String packageId) =>
      File(path.join(_stateRoot.path, '$packageId.json'));

  Future<void> _writeActivation(PackageActivationState state) async {
    await _stateRoot.create(recursive: true);
    final pointer = _stateFile(state.packageId);
    final temporary = File('${pointer.path}.temporary');
    final backup = File('${pointer.path}.backup');
    await temporary.writeAsString(jsonEncode(state.toJson()), flush: true);
    if (await backup.exists()) await backup.delete();
    if (await pointer.exists()) await pointer.rename(backup.path);
    try {
      await temporary.rename(pointer.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await pointer.exists() && await backup.exists()) {
        await backup.rename(pointer.path);
      }
      rethrow;
    }
  }
}
