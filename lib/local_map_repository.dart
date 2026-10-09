import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'offline_package.dart';
import 'travel_catalog.dart';

class LocalMapDescriptor {
  const LocalMapDescriptor({
    required this.packageId,
    required this.region,
    required this.version,
    required this.attribution,
    required this.sourceUri,
    required this.licenseUri,
    required this.snapshotAt,
    required this.featureFile,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final String packageId;
  final TravelRegion region;
  final String version;
  final String attribution;
  final Uri sourceUri;
  final Uri licenseUri;
  final DateTime snapshotAt;
  final String featureFile;
  final double west, south, east, north;

  factory LocalMapDescriptor.parse(String packageId, String text) {
    final json = jsonDecode(text);
    if (json is! Map || json['schemaVersion'] != 1) {
      throw const FormatException('Harita şeması desteklenmiyor.');
    }
    String requiredText(String field) {
      final value = json[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Harita alanı eksik: $field');
      }
      return value;
    }

    Uri link(String field) {
      final uri = Uri.parse(requiredText(field));
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw FormatException('Harita kaynak bağlantısı geçersiz: $field');
      }
      return uri;
    }

    final region = switch (requiredText('region')) {
      'mecca' => TravelRegion.mecca,
      'medina' => TravelRegion.medina,
      _ => throw const FormatException('Harita bölgesi desteklenmiyor.'),
    };
    final featureFile = requiredText('featureFile');
    if (!RegExp(r'^[a-zA-Z0-9_-]+\.geojson\.gz$').hasMatch(featureFile)) {
      throw const FormatException('Harita dosya yolu güvenli değil.');
    }
    final bounds = json['bounds'];
    if (bounds is! Map) throw const FormatException('Harita sınırları eksik.');
    double coordinate(String field, double limit) {
      final value = bounds[field];
      if (value is! num || !value.isFinite || value.abs() > limit) {
        throw const FormatException('Harita sınırı geçersiz.');
      }
      return value.toDouble();
    }

    final west = coordinate('west', 180), east = coordinate('east', 180);
    final south = coordinate('south', 90), north = coordinate('north', 90);
    if (west >= east || south >= north) {
      throw const FormatException('Harita sınırları ters.');
    }
    final snapshotAt = DateTime.tryParse(requiredText('snapshotAt'));
    if (snapshotAt == null || !snapshotAt.isUtc) {
      throw const FormatException('Harita kaynak tarihi geçersiz.');
    }
    return LocalMapDescriptor(
      packageId: packageId,
      region: region,
      version: requiredText('dataVersion'),
      attribution: requiredText('attribution'),
      sourceUri: link('sourceUrl'),
      licenseUri: link('licenseUrl'),
      snapshotAt: snapshotAt,
      featureFile: featureFile,
      west: west,
      south: south,
      east: east,
      north: north,
    );
  }
}

/// No external sources, fonts, sprites, tiles or location permission. Native
/// MapLibre draws the locally extracted OSM roads/buildings and POI circles.
Map<String, Object?> localMapStyle(
  Map<String, Object?> features,
  List<TravelPoi> points,
) => {
  'version': 8,
  'sources': {
    'osm': {'type': 'geojson', 'data': features},
    'places': {
      'type': 'geojson',
      'data': {
        'type': 'FeatureCollection',
        'features': [
          for (final point in points.where((p) => !p.isTestData))
            {
              'type': 'Feature',
              'properties': {'name': point.nameTr, 'id': point.id},
              'geometry': {
                'type': 'Point',
                'coordinates': [point.point.longitude, point.point.latitude],
              },
            },
        ],
      },
    },
  },
  'layers': [
    {
      'id': 'background',
      'type': 'background',
      'paint': {'background-color': '#F6F4EC'},
    },
    {
      'id': 'water',
      'type': 'fill',
      'source': 'osm',
      'filter': ['==', 'kind', 'water'],
      'paint': {'fill-color': '#BEDDDF'},
    },
    {
      'id': 'buildings',
      'type': 'fill',
      'source': 'osm',
      'filter': ['==', 'kind', 'building'],
      'minzoom': 13,
      'paint': {'fill-color': '#D8D5CC', 'fill-outline-color': '#C4BFB3'},
    },
    {
      'id': 'roads',
      'type': 'line',
      'source': 'osm',
      'filter': ['==', 'kind', 'road'],
      'layout': {'line-cap': 'round', 'line-join': 'round'},
      'paint': {
        'line-color': '#AAA99E',
        'line-width': [
          'interpolate',
          ['linear'],
          ['zoom'],
          10,
          0.7,
          16,
          2.4,
        ],
      },
    },
    {
      'id': 'places',
      'type': 'circle',
      'source': 'places',
      'paint': {
        'circle-radius': 5,
        'circle-color': '#17685C',
        'circle-stroke-color': '#FFFFFF',
        'circle-stroke-width': 2,
      },
    },
  ],
};

Map<String, Object?> _parseGeometry(List<int> bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is! Map ||
      decoded['type'] != 'FeatureCollection' ||
      decoded['features'] is! List ||
      (decoded['features'] as List).length > 75000) {
    throw const FormatException(
      'Harita geometri kümesi geçersiz veya çok büyük.',
    );
  }
  return Map<String, Object?>.from(decoded);
}

class LocalMapRepository {
  const LocalMapRepository(this.packages);
  final OfflinePackageManager packages;

  Future<List<LocalMapDescriptor>> list() async {
    final found = <LocalMapDescriptor>[];
    for (final state in await packages.listActivations()) {
      try {
        final file = await packages.resolveActiveFile(
          state.packageId,
          'map/catalog.v1.json',
          kind: OfflinePackageKind.map,
        );
        if (file == null || await file.length() > 64 * 1024) continue;
        found.add(
          LocalMapDescriptor.parse(state.packageId, await file.readAsString()),
        );
      } catch (_) {
        // One damaged package cannot hide a different valid city.
      }
    }
    // Reject ambiguous duplicate cities rather than picking an arbitrary publisher.
    return found
        .where(
          (item) =>
              found.where((other) => other.region == item.region).length == 1,
        )
        .toList();
  }

  Future<Map<String, Object?>> load(LocalMapDescriptor map) async {
    final file = await packages.resolveActiveFile(
      map.packageId,
      map.featureFile,
      kind: OfflinePackageKind.map,
    );
    if (file == null || await file.length() > 6 * 1024 * 1024) {
      throw const FormatException('Harita paketi eksik veya çok büyük.');
    }
    // Bound decoded data while streaming, before allocating an unbounded JSON.
    final bytes = BytesBuilder(copy: false);
    await for (final block in gzip.decoder.bind(file.openRead())) {
      if (bytes.length + block.length > 24 * 1024 * 1024) {
        throw const FormatException('Harita açılmış boyut sınırını aşıyor.');
      }
      bytes.add(block);
    }
    return compute(_parseGeometry, bytes.takeBytes());
  }
}
