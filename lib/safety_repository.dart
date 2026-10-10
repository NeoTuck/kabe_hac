import 'package:flutter/services.dart';

import 'safety_catalog.dart';

class LocalSafetyRepository {
  const LocalSafetyRepository();

  static const empty = SafetyCatalog(
    dataVersion: 'not-configured',
    contacts: [],
    languageCards: [],
    fieldInformation: [],
  );

  Future<SafetyCatalog> load({AssetBundle? bundle}) async {
    try {
      return SafetyCatalog.fromJsonText(
        await (bundle ?? rootBundle).loadString(
          'assets/content/safety_catalog.v1.json',
        ),
      );
    } catch (_) {
      // A damaged directory cannot prevent the offline guide from opening.
      return empty;
    }
  }
}
