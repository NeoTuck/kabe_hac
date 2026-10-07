import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_screen.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';

import 'test_fakes.dart';

class ChangingContentRepository extends LocalContentRepository {
  ChangingContentRepository(this.current);
  Map<GuideType, GuideCatalog> current;
  int loads = 0;
  @override
  Future<Map<GuideType, GuideCatalog>> load() async {
    loads++;
    return current;
  }
}

class EmptyPackageManager extends OfflinePackageManager {
  EmptyPackageManager() : super(root: Directory('unused-test-directory'));
  @override
  Future<List<PackageActivationState>> listActivations() async => [];
}

void main() {
  testWidgets('paket ekranından dönüş rehberi yeniden başlatmadan yeniler', (
    tester,
  ) async {
    final catalogs = await const LocalContentRepository().load();
    final repository = ChangingContentRepository(catalogs);
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        contentRepository: repository,
        narration: narration,
        settings: ReaderSettings(store, narration),
        packages: EmptyPackageManager(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      repository.loads,
      0,
    ); // Do not hash installed audio on every navigation.
    await tester.scrollUntilVisible(
      find.text('Çevrimdışı paketleri yönet'),
      250,
    );
    await tester.tap(find.text('Çevrimdışı paketleri yönet'));
    await tester.pumpAndSettle();
    final source = jsonDecode(
      await rootBundle.loadString('assets/content/umre_inventory.v1.json'),
    ) as Map<String, dynamic>;
    source['steps'][0]['title'] = 'Test paket başlığı';
    repository.current = {
      ...catalogs,
      GuideType.umrah: GuideCatalog.fromJsonText(jsonEncode(source)),
    };
    Navigator.of(tester.element(find.byType(OfflinePackagesScreen))).pop();
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
    await tester.scrollUntilVisible(find.text('Umre'), -250);
    await tester.tap(find.text('Umre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğrenme'));
    await tester.pumpAndSettle();
    expect(find.text('Test paket başlığı'), findsOneWidget);
    expect(find.text('Adımlar · 0/18 işaretli'), findsOneWidget);
  });
}
