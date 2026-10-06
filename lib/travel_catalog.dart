import 'dart:convert';
import 'dart:math' as math;

enum TravelRegion { mecca, medina, hajjSites }

enum PoiCategory {
  religiousSite,
  accommodation,
  meetingPoint,
  food,
  pharmacy,
  hospital,
  toilet,
  transport,
  police,
  officialMission,
}

extension PoiCategoryLabel on PoiCategory {
  String get label => switch (this) {
    PoiCategory.religiousSite => 'Dinî mekân / ziyaret',
    PoiCategory.accommodation => 'Konaklama',
    PoiCategory.meetingPoint => 'Buluşma noktası',
    PoiCategory.food => 'Yeme–içme',
    PoiCategory.pharmacy => 'Eczane',
    PoiCategory.hospital => 'Hastane / sağlık',
    PoiCategory.toilet => 'Tuvalet',
    PoiCategory.transport => 'Ulaşım',
    PoiCategory.police => 'Polis',
    PoiCategory.officialMission => 'Resmî temsilcilik',
  };
}

enum RouteOwnerType { official, company, group, user }

enum RouteVisibility { private, group, shared, public }

enum RouteModerationStatus { draft, pendingReview, approved, removed }

class TravelCatalogFormatException implements Exception {
  const TravelCatalogFormatException(this.message);

  final String message;

  @override
  String toString() => 'TravelCatalogFormatException: $message';
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw TravelCatalogFormatException('Zorunlu alan eksik: $key');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw TravelCatalogFormatException('Geçersiz alan: $key');
  }
  return value.trim().isEmpty ? null : value.trim();
}

T _enumValue<T extends Enum>(List<T> values, String raw, String field) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw TravelCatalogFormatException('Geçersiz $field: $raw');
}

Uri _httpsUri(Map<String, Object?> json, String key) {
  final raw = _requiredString(json, key);
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw TravelCatalogFormatException('Geçersiz bağlantı: $key');
  }
  return uri;
}

DateTime _dateTime(Map<String, Object?> json, String key) {
  final raw = _requiredString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc) {
    throw TravelCatalogFormatException('$key UTC ISO-8601 olmalı.');
  }
  return value;
}

double _coordinate(Map<String, Object?> json, String key, double limit) {
  final value = json[key];
  if (value is! num || !value.isFinite || value < -limit || value > limit) {
    throw TravelCatalogFormatException('Geçersiz koordinat: $key');
  }
  return value.toDouble();
}

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, Object?> json) => GeoPoint(
    _coordinate(json, 'latitude', 90),
    _coordinate(json, 'longitude', 180),
  );
}

class TravelPoi {
  const TravelPoi({
    required this.id,
    required this.region,
    required this.nameTr,
    required this.localName,
    required this.point,
    required this.category,
    required this.sourceTitle,
    required this.sourceUri,
    required this.verifiedAt,
    required this.isTestData,
    this.phone,
    this.hours,
  });

  final String id;
  final TravelRegion region;
  final String nameTr;
  final String? localName;
  final GeoPoint point;
  final PoiCategory category;
  final String sourceTitle;
  final Uri sourceUri;
  final DateTime verifiedAt;
  final bool isTestData;
  final String? phone;
  final String? hours;

  factory TravelPoi.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    if (!RegExp(r'^[A-Z0-9][A-Z0-9._-]{2,63}$').hasMatch(id)) {
      throw TravelCatalogFormatException('Geçersiz POI kimliği: $id');
    }
    final isTestData = json['isTestData'];
    if (isTestData is! bool) {
      throw const TravelCatalogFormatException('isTestData belirtilmeli.');
    }
    return TravelPoi(
      id: id,
      region: _enumValue(
        TravelRegion.values,
        _requiredString(json, 'region'),
        'bölge',
      ),
      nameTr: _requiredString(json, 'nameTr'),
      localName: _optionalString(json, 'localName'),
      point: GeoPoint.fromJson(json),
      category: _enumValue(
        PoiCategory.values,
        _requiredString(json, 'category'),
        'POI kategorisi',
      ),
      sourceTitle: _requiredString(json, 'sourceTitle'),
      sourceUri: _httpsUri(json, 'sourceUrl'),
      verifiedAt: _dateTime(json, 'verifiedAt'),
      isTestData: isTestData,
      phone: _optionalString(json, 'phone'),
      hours: _optionalString(json, 'hours'),
    );
  }
}

class RouteStop {
  const RouteStop({
    required this.order,
    required this.title,
    required this.poiId,
    required this.point,
  });

  final int order;
  final String title;
  final String? poiId;
  final GeoPoint? point;

  factory RouteStop.fromJson(Map<String, Object?> json) {
    final order = json['order'];
    if (order is! int || order < 1) {
      throw const TravelCatalogFormatException('Durak sırası geçersiz.');
    }
    final poiId = _optionalString(json, 'poiId');
    final hasCoordinates =
        json['latitude'] != null || json['longitude'] != null;
    if ((poiId == null) == !hasCoordinates) {
      throw const TravelCatalogFormatException(
        'Durak tek bir POI veya koordinat taşımalı.',
      );
    }
    return RouteStop(
      order: order,
      title: _requiredString(json, 'title'),
      poiId: poiId,
      point: hasCoordinates ? GeoPoint.fromJson(json) : null,
    );
  }
}

class TravelRoute {
  const TravelRoute({
    required this.id,
    required this.region,
    required this.title,
    required this.version,
    required this.ownerType,
    required this.visibility,
    required this.moderationStatus,
    required this.stops,
    required this.geometry,
    required this.sourceTitle,
    required this.sourceUri,
    required this.verifiedAt,
    required this.isTestData,
  });

  final String id;
  final TravelRegion region;
  final String title;
  final String version;
  final RouteOwnerType ownerType;
  final RouteVisibility visibility;
  final RouteModerationStatus moderationStatus;
  final List<RouteStop> stops;
  final List<GeoPoint> geometry;
  final String sourceTitle;
  final Uri sourceUri;
  final DateTime verifiedAt;
  final bool isTestData;

  bool get hasRouteGeometry => geometry.length >= 2;

  factory TravelRoute.fromJson(Map<String, Object?> json) {
    final rawStops = json['stops'];
    if (rawStops is! List || rawStops.length < 2 || rawStops.length > 200) {
      throw const TravelCatalogFormatException('Rota 2–200 durak içermeli.');
    }
    final stops = <RouteStop>[];
    for (final value in rawStops) {
      if (value is! Map) {
        throw const TravelCatalogFormatException('Durak nesne olmalı.');
      }
      stops.add(RouteStop.fromJson(Map<String, Object?>.from(value)));
    }
    for (var index = 0; index < stops.length; index++) {
      if (stops[index].order != index + 1) {
        throw const TravelCatalogFormatException(
          'Durak sırası kesintisiz olmalı.',
        );
      }
    }
    final rawGeometry = json['geometry'] ?? const [];
    if (rawGeometry is! List || rawGeometry.length > 5000) {
      throw const TravelCatalogFormatException('Rota geometrisi çok büyük.');
    }
    final geometry = <GeoPoint>[];
    for (final value in rawGeometry) {
      if (value is! Map) {
        throw const TravelCatalogFormatException('Geometri noktası geçersiz.');
      }
      geometry.add(GeoPoint.fromJson(Map<String, Object?>.from(value)));
    }
    if (geometry.length == 1) {
      throw const TravelCatalogFormatException(
        'Rota geometrisi en az iki nokta olmalı.',
      );
    }
    final isTestData = json['isTestData'];
    if (isTestData is! bool) {
      throw const TravelCatalogFormatException('isTestData belirtilmeli.');
    }
    return TravelRoute(
      id: _requiredString(json, 'id'),
      region: _enumValue(
        TravelRegion.values,
        _requiredString(json, 'region'),
        'rota bölgesi',
      ),
      title: _requiredString(json, 'title'),
      version: _requiredString(json, 'version'),
      ownerType: _enumValue(
        RouteOwnerType.values,
        _requiredString(json, 'ownerType'),
        'rota sahibi',
      ),
      visibility: _enumValue(
        RouteVisibility.values,
        _requiredString(json, 'visibility'),
        'görünürlük',
      ),
      moderationStatus: _enumValue(
        RouteModerationStatus.values,
        _requiredString(json, 'moderationStatus'),
        'yayın durumu',
      ),
      stops: List.unmodifiable(stops),
      geometry: List.unmodifiable(geometry),
      sourceTitle: _requiredString(json, 'sourceTitle'),
      sourceUri: _httpsUri(json, 'sourceUrl'),
      verifiedAt: _dateTime(json, 'verifiedAt'),
      isTestData: isTestData,
    );
  }
}

class TravelCatalog {
  const TravelCatalog({
    required this.dataVersion,
    required this.points,
    required this.routes,
  });

  final String dataVersion;
  final List<TravelPoi> points;
  final List<TravelRoute> routes;

  factory TravelCatalog.fromJsonText(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const TravelCatalogFormatException('Gezi kataloğu JSON değil.');
    }
    if (decoded is! Map) {
      throw const TravelCatalogFormatException('Gezi kataloğu nesne olmalı.');
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['schemaVersion'] != 1) {
      throw const TravelCatalogFormatException('Desteklenmeyen gezi şeması.');
    }
    List<T> records<T>(String key, T Function(Map<String, Object?>) parse) {
      final raw = json[key];
      if (raw is! List) {
        throw TravelCatalogFormatException('$key liste olmalı.');
      }
      return [
        for (final value in raw)
          if (value is Map)
            parse(Map<String, Object?>.from(value))
          else
            throw TravelCatalogFormatException('$key kaydı nesne olmalı.'),
      ];
    }

    final points = records('points', TravelPoi.fromJson);
    final routes = records('routes', TravelRoute.fromJson);
    final poiIds = points.map((point) => point.id).toSet();
    if (poiIds.length != points.length) {
      throw const TravelCatalogFormatException('Tekrarlanan POI kimliği.');
    }
    if (routes.map((route) => route.id).toSet().length != routes.length) {
      throw const TravelCatalogFormatException('Tekrarlanan rota kimliği.');
    }
    for (final route in routes) {
      for (final stop in route.stops) {
        if (stop.poiId != null && !poiIds.contains(stop.poiId)) {
          throw TravelCatalogFormatException(
            'Rota bilinmeyen POI içeriyor: ${stop.poiId}',
          );
        }
      }
    }
    return TravelCatalog(
      dataVersion: _requiredString(json, 'dataVersion'),
      points: List.unmodifiable(points),
      routes: List.unmodifiable(routes),
    );
  }

  List<TravelPoi> searchPoints({String query = '', PoiCategory? category}) {
    final normalized = query.trim().toLowerCase();
    return List.unmodifiable(
      points.where(
        (point) =>
            (category == null || point.category == category) &&
            (normalized.isEmpty ||
                point.nameTr.toLowerCase().contains(normalized) ||
                (point.localName?.toLowerCase().contains(normalized) ?? false)),
      ),
    );
  }
}

double straightLineDistanceMeters(GeoPoint from, GeoPoint to) {
  const earthRadiusMeters = 6371000.0;
  final latitude1 = from.latitude * math.pi / 180;
  final latitude2 = to.latitude * math.pi / 180;
  final latitudeDelta = (to.latitude - from.latitude) * math.pi / 180;
  final longitudeDelta = (to.longitude - from.longitude) * math.pi / 180;
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(latitude1) *
          math.cos(latitude2) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
