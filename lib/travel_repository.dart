import 'offline_package.dart';
import 'travel_catalog.dart';

/// Reads a complete catalog only from an active, trusted travel package.
/// Ambiguous catalogs fail closed rather than choosing an arbitrary publisher.
class LocalTravelRepository {
  const LocalTravelRepository({required this.packages});

  final OfflinePackageManager packages;
  static const catalogPath = 'content/travel_catalog.v1.json';
  static const empty = TravelCatalog(
    dataVersion: 'not-configured',
    points: [],
    routes: [],
  );

  Future<TravelCatalog> load() async {
    final catalogs = <TravelCatalog>[];
    try {
      for (final state in await packages.listActivations()) {
        try {
          final file = await packages.resolveActiveFile(
            state.packageId,
            catalogPath,
            kind: OfflinePackageKind.travel,
          );
          if (file == null) continue;
          // Bound parsing memory independently of the download size limit.
          if (await file.length() > 8 * 1024 * 1024) continue;
          catalogs.add(TravelCatalog.fromJsonText(await file.readAsString()));
        } catch (_) {
          // Invalid files never replace the empty, honest offline state.
        }
      }
    } catch (_) {
      return empty;
    }
    return catalogs.length == 1 ? catalogs.single : empty;
  }
}
