import 'dart:convert';

import 'guide_catalog.dart';
import 'offline_package.dart';

class LocalContentRepository {
  const LocalContentRepository({this.packages});

  final OfflinePackageManager? packages;

  static const catalogPaths = {
    GuideType.umrah: 'assets/content/umre_inventory.v1.json',
    GuideType.hajj: 'assets/content/hac_inventory.v1.json',
  };

  Future<Map<GuideType, GuideCatalog>> load({
    Map<GuideType, GuideCatalog>? bundledCatalogs,
  }) async {
    final catalogs = <GuideType, GuideCatalog>{
      for (final type in GuideType.values)
        type: bundledCatalogs?[type] ?? GuideCatalog.unavailable(type),
    };
    final manager = packages;
    if (manager == null) return Map.unmodifiable(catalogs);
    // A rejected or ambiguous override leaves the honest unavailable state.
    final overrides = <GuideType, List<GuideCatalog>>{};
    try {
      for (final state in await manager.listActivations()) {
        for (final entry in catalogPaths.entries) {
          try {
            final file = await manager.resolveActiveFile(
              state.packageId,
              entry.value.substring('assets/'.length),
              kind: OfflinePackageKind.audio,
            );
            if (file == null) continue;
            if (await file.length() > 8 * 1024 * 1024) continue;
            final text = await file.readAsString();
            final catalog = GuideCatalog.fromJsonText(text, allowPartial: true);
            final base = catalogs[entry.key]!;
            if (catalog.type != entry.key ||
                (base.steps.isNotEmpty &&
                    (catalog.steps
                            .map((step) => step.id)
                            .toSet()
                            .difference(
                              base.steps.map((step) => step.id).toSet(),
                            )
                            .isNotEmpty ||
                        base.steps
                            .map((step) => step.id)
                            .toSet()
                            .difference(
                              catalog.steps.map((step) => step.id).toSet(),
                            )
                            .isNotEmpty)) ||
                catalog.steps.any((step) => !step.isApproved) ||
                catalog.prayerRecords.values.any(
                  (prayer) => !prayer.isApproved,
                ) ||
                catalog.audioRecords.values.any(
                  (audio) =>
                      audio.status != ReviewStatus.approved || audio.reviewOnly,
                )) {
              throw const FormatException(
                'Paket yalnız onaylı rehber içerebilir.',
              );
            }
            // Package catalogs use package-local paths, never device or network URLs.
            // Bind them to this package only after parsing/approval validation.
            final json = jsonDecode(text) as Map<String, dynamic>;
            for (final audio in json['audioRecords'] as List) {
              final asset = audio['asset'];
              if (asset == null) continue;
              if (asset is! String ||
                  !asset.startsWith('audio/') ||
                  await manager.resolveActiveFile(
                        state.packageId,
                        asset,
                        kind: OfflinePackageKind.audio,
                      ) ==
                      null) {
                throw const FormatException(
                  'Paket sesi bulunamadı veya güvensiz.',
                );
              }
              audio['asset'] = 'package:${state.packageId}/$asset';
            }
            overrides
                .putIfAbsent(entry.key, () => [])
                .add(
                  GuideCatalog.fromJsonText(
                    jsonEncode(json),
                    allowPartial: true,
                  ),
                );
          } catch (_) {
            // Fail closed; do not discard bundled content or SQLite progress.
          }
        }
      }
    } catch (_) {
      return Map.unmodifiable(catalogs);
    }
    for (final entry in overrides.entries) {
      if (entry.value.length == 1) catalogs[entry.key] = entry.value.single;
    }
    return Map.unmodifiable(catalogs);
  }
}
