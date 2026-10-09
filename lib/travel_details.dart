import 'package:flutter/material.dart';

import 'source_details.dart';
import 'travel_catalog.dart';

String coordinatesLabel(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';

class TravelPoiScreen extends StatelessWidget {
  const TravelPoiScreen({super.key, required this.point});
  final TravelPoi point;
  @override
  Widget build(BuildContext context) => point.isTestData
      ? Scaffold(
          appBar: AppBar(title: const Text('Yer bilgisi')),
          body: const SafeArea(
            child: Center(child: Text('Bu yer bilgisi kullanıma açık değil.')),
          ),
        )
      : Scaffold(
          appBar: AppBar(title: Text(point.nameTr)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  point.category.label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (point.isSourceSnapshot)
                  const Card.filled(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'OpenStreetMap kaynak kaydıdır. Yerinde açık olduğunu veya güvenli ulaşımı doğrulamaz. © OpenStreetMap contributors · ODbL 1.0',
                      ),
                    ),
                  ),
                if (point.localName != null) SelectableText(point.localName!),
                const SizedBox(height: 12),
                const Text('Koordinatlar'),
                SelectableText(coordinatesLabel(point.point)),
                if (point.phone != null) ...[
                  const SizedBox(height: 16),
                  const Text('Kayıtlı telefon'),
                  SelectableText(point.phone!),
                ],
                if (point.hours != null) ...[
                  const SizedBox(height: 16),
                  const Text('Kayıtlı çalışma saatleri'),
                  Text(point.hours!),
                  const Text(
                    'Saatler kaynak kaydına aittir; güncel açık/kapalı durumunu doğrulayın.',
                  ),
                ],
                const SizedBox(height: 20),
                SourceDetails(
                  title: point.sourceTitle,
                  uri: point.sourceUri,
                  verifiedAt: point.verifiedAt,
                ),
              ],
            ),
          ),
        );
}

class TravelRouteScreen extends StatelessWidget {
  const TravelRouteScreen({
    super.key,
    required this.route,
    required this.catalog,
  });
  final TravelRoute route;
  final TravelCatalog catalog;
  @override
  Widget build(BuildContext context) {
    if (route.isTestData) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rota bilgisi')),
        body: const SafeArea(
          child: Center(child: Text('Bu rota kullanıma açık değil.')),
        ),
      );
    }
    final points = {
      for (final point in catalog.points)
        if (!point.isTestData) point.id: point,
    };
    return Scaffold(
      appBar: AppBar(title: Text(route.title)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: route.stops.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Card.filled(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${route.stops.length} durak · Sürüm ${route.version}',
                      ),
                      if (route.moderationStatus !=
                          RouteModerationStatus.approved)
                        const Text('Bu rota yayın onayından geçmemiştir.'),
                      const Text(
                        'Duraklar cihazdaki kayıttan gösterilir. Bu ekran canlı yön bulma veya yürüme rotası sağlamaz.',
                      ),
                    ],
                  ),
                ),
              );
            }
            if (index == route.stops.length + 1) {
              return SourceDetails(
                title: route.sourceTitle,
                uri: route.sourceUri,
                verifiedAt: route.verifiedAt,
              );
            }
            final stop = route.stops[index - 1];
            final point = points[stop.poiId];
            final coordinates = point?.point ?? stop.point;
            return Card.outlined(
              child: ListTile(
                leading: CircleAvatar(child: Text('${stop.order}')),
                title: Text(stop.title),
                subtitle: coordinates == null
                    ? null
                    : Text(coordinatesLabel(coordinates)),
                trailing: point == null
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: point == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => TravelPoiScreen(point: point),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
