import 'dart:io';

import 'package:hac_umre_sesli_rehber/guide_catalog.dart';

const draftCatalogPaths = {
  GuideType.umrah: 'assets/content/umre_inventory.v1.json',
  GuideType.hajj: 'assets/content/hac_inventory.v1.json',
};

Future<String> readDraftCatalogText(GuideType type) =>
    File(draftCatalogPaths[type]!).readAsString();

/// Test-only source catalogs. These files are excluded from Flutter assets.
Future<Map<GuideType, GuideCatalog>> loadDraftCatalogs() async => {
  for (final type in GuideType.values)
    type: GuideCatalog.fromJsonText(await readDraftCatalogText(type)),
};
