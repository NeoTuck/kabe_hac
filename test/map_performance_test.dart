import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/local_map_repository.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';

void main() {
  test('real map decode and style serialization measurement on host VM', () async {
    const snapshot = 'offline_packages/osm-2026-10-08';
    final root = await Directory.systemTemp.createTemp('map-measure-');
    addTearDown(() => root.delete(recursive: true));
    Map<String, Object?> read(String file) => Map<String, Object?>.from(
      jsonDecode(File(file).readAsStringSync()) as Map,
    );
    final config = OfflinePackageRuntimeConfig.fromJson(
      read('assets/content/package_defaults.v1.json'),
    );
    final manager = OfflinePackageManager(
      root: root,
      trustPolicy: PinnedManifestDigestPolicy(config.trustedManifestDigests),
    );
    for (final raw
        in (read('$snapshot/catalog.v1.json')['packages'] as List).where(
          (p) => p['kind'] == 'map',
        )) {
      final manifest = OfflinePackageManifest.fromJson(
        Map<String, Object?>.from(raw as Map),
      );
      final staging = await manager.createStagingDirectory(manifest);
      for (final entry in manifest.files) {
        final target = File('${staging.path}/${entry.relativePath}');
        await target.parent.create(recursive: true);
        await File('$snapshot/${manifest.packageId}/${entry.relativePath}')
            .copy(target.path);
      }
      await manager.activate(manifest, staging);
    }
    final repository = LocalMapRepository(manager);
    for (final map in await repository.list()) {
      final rss = ProcessInfo.currentRss;
      final clock = Stopwatch()..start();
      final style = await repository.loadStyle(map, const []);
      final pipelineMs = clock.elapsedMicroseconds / 1000;
      clock.stop();
      expect(style, contains('"places"'));
      expect(utf8.encode(style).length, greaterThan(6000000));
      // RSS is the whole host test process, not native device memory or a peak.
      stdout.writeln(
        jsonEncode({
          'measurement': 'host_vm_map',
          'package': map.packageId,
          'pipeline_ms': pipelineMs,
          'style_bytes': utf8.encode(style).length,
          'rss_before': rss,
          'rss_after': ProcessInfo.currentRss,
          'native_first_render_measured': false,
        }),
      );
    }
  });
}
