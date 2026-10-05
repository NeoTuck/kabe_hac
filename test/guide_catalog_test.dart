import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iki katalog tüm sabit alt kimlikleri sırayla içerir', () async {
    final catalogs = await const LocalContentRepository().load();
    for (final entry in GuideCatalog.expectedGroups.entries) {
      final catalog = catalogs[entry.key]!;
      final ids = [
        for (final group in entry.value.entries)
          for (var i = 1; i <= group.value; i++) '${group.key}.$i',
      ];
      expect(catalog.steps.map((s) => s.id), ids);
      expect(ids.toSet(), hasLength(ids.length));
      expect(
        catalog.steps.every((s) => s.status == ReviewStatus.draft),
        isTrue,
      );
      expect(catalog.steps.length, entry.key == GuideType.umrah ? 18 : 35);
    }
  });

  test('sürüm, zorunlu alan, kimlik ve bağlantı hataları reddedilir', () async {
    final text = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
    Map<String, dynamic> source() => jsonDecode(text) as Map<String, dynamic>;

    final badVersion = source()..['schemaVersion'] = 99;
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(badVersion)),
      throwsFormatException,
    );
    final duplicate = source();
    (duplicate['steps'] as List)[1]['id'] = 'U01.1';
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(duplicate)),
      throwsFormatException,
    );
    final missingTitle = source();
    (missingTitle['steps'] as List)[0].remove('title');
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(missingTitle)),
      throwsFormatException,
    );
    final brokenAudio = source();
    (brokenAudio['steps'] as List)[0]['audioId'] = 'audio-absent';
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(brokenAudio)),
      throwsFormatException,
    );
    final brokenPrayer = source();
    (brokenPrayer['steps'] as List)[0]['prayerIds'] = ['prayer-absent'];
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(brokenPrayer)),
      throwsFormatException,
    );
    final collidingAudio = source();
    collidingAudio['audioRecords'] = [
      {'id': 'U01.1', 'status': 'draft'},
    ];
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(collidingAudio)),
      throwsFormatException,
    );
  });

  test('isteğe bağlı alanlar boş kalabilir, onay kanıtsız verilemez', () async {
    final text = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
    final source = jsonDecode(text) as Map<String, dynamic>;
    final catalog = GuideCatalog.fromJsonText(jsonEncode(source));
    expect(catalog.steps.first.audioId, isNull);
    expect(catalog.steps.first.summary, isNull);
    expect(catalog.steps.first.prayerIds, isEmpty);
    (source['steps'] as List)[0]['status'] = 'approved';
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(source)),
      throwsFormatException,
    );
  });

  test('hac profil matrisi eksikse katalog reddedilir', () async {
    final text = await rootBundle.loadString(
      'assets/content/hac_inventory.v1.json',
    );
    final source = jsonDecode(text) as Map<String, dynamic>;
    (source['steps'] as List)[0]['profileApplicability'].remove('kiran');
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(source)),
      throwsFormatException,
    );
  });

  test('metin ile ses sürümü uyuşmazlığı reddedilir', () async {
    final text = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
    final source = jsonDecode(text) as Map<String, dynamic>;
    (source['audioRecords'] as List).first['textVersion'] = 'yanlis-surum';
    expect(
      () => GuideCatalog.fromJsonText(jsonEncode(source)),
      throwsFormatException,
    );
  });

  test(
    'incelemeye gönderilen metin kaynak ve geçerli bağlantı ister',
    () async {
      final text = await rootBundle.loadString(
        'assets/content/umre_inventory.v1.json',
      );
      Map<String, dynamic> source() => jsonDecode(text) as Map<String, dynamic>;

      final missingSource = source();
      (missingSource['steps'] as List)[3]['status'] = 'pendingReview';
      expect(
        () => GuideCatalog.fromJsonText(jsonEncode(missingSource)),
        throwsFormatException,
      );

      final invalidUrl = source();
      final step = (invalidUrl['steps'] as List)[3];
      step.addAll({
        'status': 'pendingReview',
        'sourceTitle': 'Kaynak başlığı',
        'sourceUrl': 'gecersiz bağlantı',
        'sourceLocation': 'Bölüm 1',
        'sourceUsageRights': 'Kullanım koşulları incelenecek',
      });
      expect(
        () => GuideCatalog.fromJsonText(jsonEncode(invalidUrl)),
        throwsFormatException,
      );
    },
  );

  test('U02.2 hazırlama kaydı eksik metin ve sesle güvenle yüklenir', () async {
    final catalog = (await const LocalContentRepository()
        .load())[GuideType.umrah]!;
    final step = catalog.stepById('U02.2')!;
    expect(step.status, ReviewStatus.draft);
    expect(step.textVersion, 'U02.2-text-v1');
    expect(step.summary, isNull);
    expect(step.prayerIds, ['P-U02.2-01']);
    expect(step.linkedAudioIds, ['A-U02.2-TR-01']);
    expect(catalog.audioRecords['A-U02.2-TR-01']?.asset, isNull);
    expect(catalog.prayerRecords['P-U02.2-01']?.arabic, isNull);
  });
}
