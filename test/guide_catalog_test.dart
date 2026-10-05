import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('umre envanteri 18 benzersiz, sıralı başlık içerir', () async {
    final catalog = await GuideCatalog.loadAsset();
    expect(catalog.steps, hasLength(18));
    expect(catalog.steps.first.order, 1);
    expect(catalog.steps.last.order, 18);
    expect(catalog.steps.every((step) => !step.isPublished), isTrue);
  });

  test('yinelenen kimlik ve eksik yayın onayı reddedilir', () async {
    final text = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
    final duplicate = jsonDecode(text) as Map<String, dynamic>;
    final duplicateSteps = duplicate['steps'] as List<dynamic>;
    (duplicateSteps[1] as Map<String, dynamic>)['id'] =
        (duplicateSteps[0] as Map<String, dynamic>)['id'];
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(duplicate)),
      throwsFormatException,
    );

    final unapproved = jsonDecode(text) as Map<String, dynamic>;
    final steps = unapproved['steps'] as List<dynamic>;
    (steps[0] as Map<String, dynamic>)['status'] = 'published';
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(unapproved)),
      throwsFormatException,
    );
  });
}
