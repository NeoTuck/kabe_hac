import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/safety_catalog.dart';

Map<String, Object?> baseCatalog() => {
  'schemaVersion': 1,
  'dataVersion': 'test-1',
  'contacts': [],
  'languageCards': [],
  'fieldInformation': [],
};

void main() {
  test('onaylı dil kartı insan incelemesi ve kaynak ister', () {
    final source = baseCatalog();
    source['languageCards'] = [
      {
        'id': 'LANG-TEST-1',
        'category': 'help',
        'turkish': 'Teknik test ifadesi',
        'arabic': 'نص اختبار تقني',
        'status': 'approved',
      },
    ];
    expect(
      () => SafetyCatalog.fromJsonText(jsonEncode(source)),
      throwsA(isA<SafetyCatalogFormatException>()),
    );

    final approved = baseCatalog();
    approved['languageCards'] = [
      {
        'id': 'LANG-TEST-1',
        'category': 'help',
        'turkish': 'Teknik test ifadesi',
        'arabic': 'نص اختبار تقني',
        'transliteration': 'Teknik test',
        'status': 'approved',
        'sourceTitle': 'Otomatik test fixture',
        'sourceUrl': 'https://example.com/test-fixture',
        'reviewedBy': 'Test inceleyeni',
        'reviewedAt': '2026-10-06T00:00:00Z',
      },
    ];
    expect(
      SafetyCatalog.fromJsonText(jsonEncode(approved))
          .languageCards
          .single
          .isApproved,
      isTrue,
    );
  });

  test('süresi geçen saha bilgisi canlı görünmez', () {
    final source = baseCatalog();
    source['fieldInformation'] = [
      {
        'id': 'FIELD-TEST-1',
        'title': 'Teknik saha kaydı',
        'value': 'Test değeri',
        'state': 'live',
        'sourceKind': 'official',
        'sourceTitle': 'Otomatik test fixture',
        'sourceUrl': 'https://example.com/test-fixture',
        'observedAt': '2026-10-06T08:00:00Z',
        'validUntil': '2026-10-06T09:00:00Z',
      },
    ];
    final information = SafetyCatalog.fromJsonText(jsonEncode(source))
        .fieldInformation
        .single;
    expect(
      information.displayStateAt(DateTime.parse('2026-10-06T10:00:00Z')),
      'Süresi dolmuş bilgi',
    );
  });

  test('kullanıcı bildirimi canlı resmî durum olarak işaretlenemez', () {
    final source = baseCatalog();
    source['fieldInformation'] = [
      {
        'id': 'FIELD-TEST-2',
        'title': 'Teknik kullanıcı bildirimi',
        'value': 'Test değeri',
        'state': 'live',
        'sourceKind': 'userReport',
        'sourceTitle': 'Otomatik test fixture',
        'sourceUrl': 'https://example.com/test-fixture',
        'observedAt': '2026-10-06T08:00:00Z',
        'validUntil': '2026-10-06T09:00:00Z',
      },
    ];
    expect(
      () => SafetyCatalog.fromJsonText(jsonEncode(source)),
      throwsA(isA<SafetyCatalogFormatException>()),
    );
  });
}
