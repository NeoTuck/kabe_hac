import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_map_adapter.dart';

void main() {
  OfflineMapRegionRequest request({
    bool allowed = true,
    String host = 'licensed.example.test',
    double south = 21,
    double zoom = 12,
  }) => OfflineMapRegionRequest(
    regionId: 'mecca-region',
    styleUri: Uri.https(host, '/style.json'),
    attribution: 'Provider attribution',
    south: south,
    west: 39,
    north: 22,
    east: 40,
    minZoom: 8,
    maxZoom: zoom,
    providerAllowsOfflineDownload: allowed,
  );
  test('provider permission and non-public offline source are required', () {
    expect(() => request(allowed: false), throwsArgumentError);
    expect(() => request(host: 'tile.openstreetmap.org'), throwsArgumentError);
    expect(request().regionId, 'mecca-region');
  });
  test('map bounds and zoom cannot contain NaN or infinity', () {
    expect(() => request(south: double.nan), throwsArgumentError);
    expect(() => request(zoom: double.infinity), throwsArgumentError);
    expect(() => request(south: 23), throwsArgumentError);
  });
}
