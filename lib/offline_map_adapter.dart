import 'package:maplibre_gl/maplibre_gl.dart';

class OfflineMapRegionRequest {
  const OfflineMapRegionRequest._({
    required this.regionId,
    required this.styleUri,
    required this.attribution,
    required this.southwest,
    required this.northeast,
    required this.minZoom,
    required this.maxZoom,
  });

  final String regionId;
  final Uri styleUri;
  final String attribution;
  final LatLng southwest;
  final LatLng northeast;
  final double minZoom;
  final double maxZoom;

  factory OfflineMapRegionRequest({
    required String regionId,
    required Uri styleUri,
    required String attribution,
    required double south,
    required double west,
    required double north,
    required double east,
    required double minZoom,
    required double maxZoom,
    required bool providerAllowsOfflineDownload,
  }) {
    final safeId = regionId.trim();
    final safeAttribution = attribution.trim();
    if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$').hasMatch(safeId)) {
      throw ArgumentError.value(regionId, 'regionId');
    }
    if (!providerAllowsOfflineDownload) {
      throw ArgumentError('Sağlayıcı offline indirmeye açıkça izin vermeli.');
    }
    if (styleUri.scheme != 'https' ||
        styleUri.host.isEmpty ||
        styleUri.userInfo.isNotEmpty) {
      throw ArgumentError.value(styleUri, 'styleUri');
    }
    if (styleUri.host == 'tile.openstreetmap.org' ||
        styleUri.host == 'vector.openstreetmap.org') {
      throw ArgumentError(
        'Kamusal OSM tile sunucuları offline paket kaynağı olamaz.',
      );
    }
    if (safeAttribution.isEmpty) {
      throw ArgumentError.value(attribution, 'attribution');
    }
    if (![
          south,
          west,
          north,
          east,
          minZoom,
          maxZoom,
        ].every((value) => value.isFinite) ||
        south < -90 ||
        north > 90 ||
        west < -180 ||
        east > 180 ||
        south >= north ||
        west >= east) {
      throw ArgumentError('Geçersiz harita sınırları.');
    }
    if (minZoom < 0 || maxZoom > 24 || minZoom > maxZoom) {
      throw ArgumentError('Geçersiz yakınlaştırma aralığı.');
    }
    return OfflineMapRegionRequest._(
      regionId: safeId,
      styleUri: styleUri,
      attribution: safeAttribution,
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
      minZoom: minZoom,
      maxZoom: maxZoom,
    );
  }
}

abstract class OfflineMapAdapter {
  const OfflineMapAdapter();

  Future<List<OfflineRegion>> listRegions();
  Future<OfflineRegion> download(
    OfflineMapRegionRequest request, {
    void Function(DownloadRegionStatus event)? onEvent,
  });
  Future<OfflineRegionStatus> status(int regionId);
  Future<void> pause(int regionId);
  Future<void> resume(int regionId);
  Future<void> delete(int regionId);
}

class MapLibreOfflineMapAdapter extends OfflineMapAdapter {
  const MapLibreOfflineMapAdapter();

  @override
  Future<List<OfflineRegion>> listRegions() => getListOfRegions();

  @override
  Future<OfflineRegion> download(
    OfflineMapRegionRequest request, {
    void Function(DownloadRegionStatus event)? onEvent,
  }) => downloadOfflineRegion(
    OfflineRegionDefinition(
      bounds: LatLngBounds(
        southwest: request.southwest,
        northeast: request.northeast,
      ),
      mapStyleUrl: request.styleUri.toString(),
      minZoom: request.minZoom,
      maxZoom: request.maxZoom,
      includeIdeographs: true,
    ),
    metadata: {
      'regionId': request.regionId,
      'attribution': request.attribution,
    },
    onEvent: onEvent,
  );

  @override
  Future<OfflineRegionStatus> status(int regionId) =>
      getOfflineRegionStatus(regionId);

  @override
  Future<void> pause(int regionId) => pauseOfflineRegionDownload(regionId);

  @override
  Future<void> resume(int regionId) => resumeOfflineRegionDownload(regionId);

  @override
  Future<void> delete(int regionId) async {
    await deleteOfflineRegion(regionId);
    await clearAmbientCache();
  }
}
