import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/main.dart';
import 'package:hac_umre_sesli_rehber/local_map_repository.dart';
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
  bool failing = false;
  @override
  Future<TravelCatalog> load() async {
    loads++;
    if (failing) throw const FormatException('Test catalog read failure');
    return current;
  }
}

class CapturingMapRepository extends LocalMapRepository {
  CapturingMapRepository(super.packages);
  List<String> receivedIds = [];
  int styleLoads = 0;

  @override
  Future<List<LocalMapDescriptor>> list() async => [
    LocalMapDescriptor(
      packageId: 'map-mecca',
      region: TravelRegion.mecca,
      version: '1.0.0',
      attribution: 'Test fixture',
      sourceUri: Uri.parse('https://example.com/source'),
      licenseUri: Uri.parse('https://example.com/license'),
      snapshotAt: DateTime.utc(2026, 10, 13),
      featureFile: 'test.geojson.gz',
      west: 39,
      south: 21,
      east: 40,
      north: 22,
    ),
  ];

  @override
  Future<String> loadStyle(
    LocalMapDescriptor map,
    List<TravelPoi> points,
  ) async {
    styleLoads++;
    receivedIds = points.map((point) => point.id).toList();
    // Exercise recovery without claiming to render a native map in a widget test.
    throw const FormatException('Test renderer unavailable');
  }
}

void main() {
  testWidgets('açık harita paket dönüşünde yer ekleme ve silmeyi okur', (
    tester,
  ) async {
    final packages = EmptyPackageManager();
    final travel = ChangingTravelRepository();
    final maps = CapturingMapRepository(packages);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineCityMapScreen(
          packages: packages,
          catalog: LocalTravelRepository.empty,
          travelRepository: travel,
          mapRepository: maps,
          onManageMaps: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(maps.receivedIds, isEmpty);
    for (final installed in [true, false]) {
      travel.current = installed ? fixture() : LocalTravelRepository.empty;
      await tester.tap(find.text('Harita paketlerini yönet'));
      await tester.pumpAndSettle();
      expect(maps.receivedIds, installed ? ['TEST-POI-1'] : isEmpty);
    }
    expect(travel.loads, 2);
    expect(maps.styleLoads, 3);
  });

  testWidgets('paketten açılan bağımsız gezi listesi de yenilenir', (
    tester,
  ) async {
    final travel = ChangingTravelRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: TravelScreen(
          store: MemoryGuideStore(),
          catalog: LocalTravelRepository.empty,
          packages: EmptyPackageManager(),
          travelRepository: travel,
          onManagePackages: (_) async {
            travel.current = fixture();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Yer kayıtlarını indir'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Yer kayıtlarını indir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yer kayıtlarını indir'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Teknik buluşma noktası'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Teknik buluşma noktası'), findsOneWidget);
    expect(travel.loads, 1);
  });

  testWidgets(
    'harita yer okuma hatasından sonra güncel kataloğu yeniden dener',
    (tester) async {
      final packages = EmptyPackageManager();
      final travel = ChangingTravelRepository()..failing = true;
      final maps = CapturingMapRepository(packages);
      await tester.pumpWidget(
        MaterialApp(
          home: OfflineCityMapScreen(
            packages: packages,
            catalog: LocalTravelRepository.empty,
            travelRepository: travel,
            mapRepository: maps,
            onManageMaps: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harita paketlerini yönet'));
      await tester.pumpAndSettle();
      expect(find.text('Harita paketleri okunamadı.'), findsOneWidget);
      travel
        ..failing = false
        ..current = fixture();
      await tester.tap(find.text('Yeniden dene'));
      await tester.pumpAndSettle();
      expect(travel.loads, 2);
      expect(maps.receivedIds, ['TEST-POI-1']);
    },
  );
  testWidgets(
    'gezi paket hatası favori hatası değildir ve yeniden denenebilir',
    (tester) async {
      final travel = ChangingTravelRepository()..current = fixture();
      var failing = true;
      await tester.pumpWidget(
        MaterialApp(
          home: TravelScreen(
            store: MemoryGuideStore(),
            catalog: fixture(),
            packages: EmptyPackageManager(),
            travelRepository: travel,
            onManagePackages: (_) async {
              if (failing) {
                throw const FormatException('Test management failure');
              }
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harita paketlerini yönet'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Favorileri yeniden dene'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Yer paketlerini yeniden kontrol et'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(
        find.widgetWithText(
          OutlinedButton,
          'Yer paketlerini yeniden kontrol et',
        ),
      );
      await tester.pumpAndSettle();
      failing = false;
      await tester.tap(find.text('Yer paketlerini yeniden kontrol et'));
      await tester.pumpAndSettle();
      expect(find.text('Yer paketlerini yeniden kontrol et'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Teknik buluşma noktası'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Teknik buluşma noktası'), findsOneWidget);
    },
  );

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
