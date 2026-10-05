import 'package:flutter/services.dart';

import 'guide_catalog.dart';

class LocalContentRepository {
  const LocalContentRepository();

  Future<Map<GuideType, GuideCatalog>> load() async {
    final catalogs = <GuideType, GuideCatalog>{};
    for (final entry in const {
      GuideType.umrah: 'assets/content/umre_inventory.v1.json',
      GuideType.hajj: 'assets/content/hac_inventory.v1.json',
    }.entries) {
      final text = await rootBundle.loadString(entry.value);
      final catalog = GuideCatalog.fromJsonText(text);
      if (catalog.type != entry.key) {
        throw FormatException('${entry.value} türü yanlış.');
      }
      catalogs[entry.key] = catalog;
    }
    return Map.unmodifiable(catalogs);
  }
}
