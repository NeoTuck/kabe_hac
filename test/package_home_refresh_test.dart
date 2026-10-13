import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/offline_city_map_screen.dart';
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

class StatusPackageManager extends EmptyPackageManager {
  bool verified = false;

  @override
  Future<List<PackageActivationState>> listActivations() async => [
    PackageActivationState(
      packageId: 'map-mecca',
      activeVersion: '1.0.0',
      previousVersion: null,
      activatedAt: DateTime.utc(2026, 10, 13),
    ),
  ];

  @override
  Future<OfflinePackageManifest?> verifyActivePackage(String packageId) async =>
      verified
      ? const OfflinePackageManifest(
          packageId: 'map-mecca',
          kind: OfflinePackageKind.map,
          version: '1.0.0',
          changeClass: ContentChangeClass.c0,
          minContentSchema: 1,
          maxContentSchema: 1,
          totalBytes: 0,
          files: [],
        )
      : null;
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
  testWidgets('boş harita ekranı indirme yolunu açar', (tester) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final catalogs = (await tester.runAsync(
      () => const LocalContentRepository().load(),
    ))!;
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
        packages: EmptyPackageManager(),
        travelCatalog: LocalTravelRepository.empty,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yolculuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çevrimdışı haritayı aç'));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineCityMapScreen), findsOneWidget);
    expect(
      find.textContaining('Bu cihazda şehir haritası kurulu değil'),
      findsOneWidget,
    );
    await tester.tap(find.text('Harita paketlerini yönet'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OfflinePackagesScreen>(find.byType(OfflinePackagesScreen))
          .focusKind,
      OfflinePackageKind.map,
    );
  });

  testWidgets('ana ekran kurulum kaydını doğrulanmış harita saymaz', (
    tester,
  ) async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final packages = StatusPackageManager();
    final catalogs = (await tester.runAsync(
      () => const LocalContentRepository().load(),
    ))!;
    await tester.pumpWidget(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: ReaderSettings(store, narration),
        packages: packages,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Mekke haritası: Dosyalar doğrulanamadı'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Çevrimdışı paketleri yönet'),
      250,
    );
    await tester.tap(find.text('Çevrimdışı paketleri yönet'));
    await tester.pumpAndSettle();
    packages.verified = true;
    Navigator.of(tester.element(find.byType(OfflinePackagesScreen))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Çevrimdışı durum'), -250);
    expect(
      find.textContaining('Mekke haritası: Dosyalar doğrulandı'),
      findsOneWidget,
    );
  });

  testWidgets('gezi boş durumundan yer paketi açılıp liste yenilenir', (
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
    await tester.tap(find.text('Yolculuk'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Yer kayıtlarını indir'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(TravelScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
      find
          .descendant(
            of: find.byType(TravelScreen),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yer kayıtlarını indir'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OfflinePackagesScreen>(find.byType(OfflinePackagesScreen))
          .focusKind,
      OfflinePackageKind.travel,
    );
    travel.current = fixture();
    Navigator.of(tester.element(find.byType(OfflinePackagesScreen))).pop();
    await tester.pumpAndSettle();
    expect(travel.loads, 1);
    await tester.scrollUntilVisible(
      find.text('Teknik buluşma noktası'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(TravelScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Teknik buluşma noktası'), findsOneWidget);
  });

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
