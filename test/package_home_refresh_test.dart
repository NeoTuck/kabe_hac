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
import 'package:hac_umre_sesli_rehber/travel_catalog.dart';
import 'package:hac_umre_sesli_rehber/travel_repository.dart';
import 'package:hac_umre_sesli_rehber/travel_screen.dart';

import 'travel_screen_test.dart' show fixture;

import 'test_fakes.dart';

class ChangingContentRepository extends LocalContentRepository {
  ChangingContentRepository(this.current);
  Map<GuideType, GuideCatalog> current;
  int loads = 0;
  @override
  Future<Map<GuideType, GuideCatalog>> load({
    Map<GuideType, GuideCatalog>? bundledCatalogs,
  }) async {
    loads++;
    return current;
  }
}

class EmptyPackageManager extends OfflinePackageManager {
  EmptyPackageManager() : super(root: Directory('unused-test-directory'));
  @override
  Future<List<PackageActivationState>> listActivations() async => [];
}

class ChangingTravelRepository extends LocalTravelRepository {
  ChangingTravelRepository() : super(packages: EmptyPackageManager());
  TravelCatalog current = LocalTravelRepository.empty;
  int loads = 0;
  @override
  Future<TravelCatalog> load() async {
    loads++;
    return current;
  }
}

void main() {
  testWidgets('travel catalog refreshes after package install and deletion', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final travel = ChangingTravelRepository();
    final catalogs = (await tester.runAsync(
      () => const LocalContentRepository().load(),
    ))!;
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        travelRepository: travel,
        travelCatalog: LocalTravelRepository.empty,
        narration: narration,
        settings: ReaderSettings(store, narration),
        packages: EmptyPackageManager(),
      ),
    );
    await tester.pumpAndSettle();
    expect(travel.loads, 0);
    for (final installed in [true, false]) {
      await tester.scrollUntilVisible(
        find.text('Çevrimdışı paketleri yönet'),
        250,
      );
      await tester.ensureVisible(find.text('Çevrimdışı paketleri yönet'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Çevrimdışı paketleri yönet'));
      await tester.pumpAndSettle();
      travel.current = installed ? fixture() : LocalTravelRepository.empty;
      Navigator.of(tester.element(find.byType(OfflinePackagesScreen))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yolculuk'));
      await tester.pumpAndSettle();
      expect(travel.loads, installed ? 1 : 2);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(
        tester
            .widget<TravelScreen>(find.byType(TravelScreen))
            .catalog
            .points
            .length,
        installed ? 1 : 0,
      );
      if (installed) {
        await tester.scrollUntilVisible(
          find.text('Teknik buluşma noktası'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(TravelScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      expect(
        find.text('Teknik buluşma noktası'),
        installed ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('Rehber').last);
      await tester.pumpAndSettle();
    }
    expect(travel.loads, 2);
  }, timeout: const Timeout(Duration(minutes: 1)));
  testWidgets('paket ekranından dönüş rehberi yeniden başlatmadan yeniler', (
    tester,
  ) async {
    final catalogs = (await tester.runAsync(
      () => const LocalContentRepository().load(),
    ))!;
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
      (await tester.runAsync(
        () => rootBundle.loadString('assets/content/umre_inventory.v1.json'),
      ))!,
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
  }, timeout: const Timeout(Duration(minutes: 1)));
}
