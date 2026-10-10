import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';
import 'package:hac_umre_sesli_rehber/package_screen.dart';

class FakePackageProvider extends OfflinePackageProvider {
  FakePackageProvider(this.manifest);

  final OfflinePackageManifest manifest;
  int downloadCalls = 0;
  Completer<void>? gate;
  Completer<void>? catalogGate;
  int catalogCalls = 0;

  @override
  Future<List<OfflinePackageManifest>> loadCatalog() async {
    catalogCalls++;
    if (catalogGate != null) await catalogGate!.future;
    return [manifest];
  }

  @override
  Future<PackageActivationState> downloadAndActivate(
    OfflinePackageManifest manifest,
  ) async {
    downloadCalls++;
    if (gate != null) await gate!.future;
    return PackageActivationState(
      packageId: manifest.packageId,
      activeVersion: manifest.version,
      previousVersion: null,
      activatedAt: DateTime.utc(2026, 10, 6),
    );
  }
}

class FakePackageStore extends OfflinePackageStore {
  final List<PackageActivationState> states = [];

  @override
  Future<void> deletePackage(String packageId) async {
    states.removeWhere((state) => state.packageId == packageId);
  }

  @override
  Future<List<PackageActivationState>> listActivations() async =>
      List.unmodifiable(states);

  @override
  Future<PackageActivationState> rollback(String packageId) async {
    throw StateError('Testte geri dönüş yok.');
  }
}

OfflinePackageManifest fixtureManifest() => OfflinePackageManifest.fromJson({
  'schemaVersion': 1,
  'packageId': 'umre-audio-tr',
  'kind': 'audio',
  'version': '1.0.0',
  'changeClass': 'C0',
  'minContentSchema': 1,
  'maxContentSchema': 1,
  'totalBytes': 1,
  'files': [
    {
      'path': 'audio/demo.m4a',
      'sha256': List.filled(64, '0').join(),
      'sizeBytes': 1,
      'downloadUrl': 'https://packages.example.test/audio/demo.m4a',
    },
  ],
});

class FailingPackageStore extends FakePackageStore {
  bool fail = true;
  @override
  Future<List<PackageActivationState>> listActivations() async {
    if (fail) throw StateError('disk');
    return super.listActivations();
  }
}

void main() {
  testWidgets('installed maps remain manageable while catalog is stalled', (
    tester,
  ) async {
    final store = FakePackageStore();
    store.states.add(
      PackageActivationState(
        packageId: 'map-mecca',
        activeVersion: '1.0.0',
        previousVersion: null,
        activatedAt: DateTime.utc(2026),
      ),
    );
    final provider = FakePackageProvider(fixtureManifest())
      ..catalogGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePackagesScreen(manager: store, provider: provider),
      ),
    );
    await tester.pump();
    expect(find.text('Mekke çevrimdışı haritası'), findsOneWidget);
    expect(find.textContaining('Çevrimdışı hazır'), findsOneWidget);
    await tester.tap(find.text('Paketi sil'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Paketi sil'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(store.states, isEmpty);
    expect(find.text('Kurulu çevrimdışı paket yok.'), findsOneWidget);
    expect(provider.catalogCalls, 1);
    provider.catalogGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('umre-audio-tr'), findsOneWidget);
    expect(find.textContaining('Çevrimdışı hazır'), findsNothing);
  });
  testWidgets('yapılandırma yokken paket ağı kapalı görünür', (tester) async {
    final manager = FakePackageStore();
    await tester.pumpWidget(
      MaterialApp(home: OfflinePackagesScreen(manager: manager)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Paket sağlayıcısı yapılandırılmadı'),
      findsOneWidget,
    );
    expect(find.text('Paket kataloğu kapalı.'), findsOneWidget);
  });

  testWidgets('güvenli katalog paketini listeler ve indirmeyi başlatır', (
    tester,
  ) async {
    final manager = FakePackageStore();
    final manifest = fixtureManifest();
    final provider = FakePackageProvider(manifest);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePackagesScreen(manager: manager, provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('umre-audio-tr'), findsOneWidget);
    expect(find.textContaining('Ses ve rehber · 1.0.0'), findsOneWidget);
    await tester.tap(find.text('İndir'));
    await tester.pumpAndSettle();
    expect(provider.downloadCalls, 1);
  });
  testWidgets('package download locks refresh and delete until it finishes', (
    tester,
  ) async {
    final store = FakePackageStore();
    final provider = FakePackageProvider(fixtureManifest())
      ..gate = Completer<void>();
    store.states.add(
      PackageActivationState(
        packageId: 'installed',
        activeVersion: '1',
        previousVersion: null,
        activatedAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePackagesScreen(manager: store, provider: provider),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('İndir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İndir'));
    await tester.pump();
    final delete = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Paketi sil'),
        matching: find.byType(TextButton),
      ),
    );
    expect(delete.onPressed, isNull);
    final refresh = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Paketleri yenile'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(refresh.onPressed, isNull);
    expect(provider.downloadCalls, 1);
    provider.gate!.complete();
    await tester.pumpAndSettle();
    expect(provider.downloadCalls, 1);
    expect(store.states.length, 1);
  });
  testWidgets(
    'failed package read offers recovery instead of endless spinner',
    (tester) async {
      final store = FailingPackageStore();
      await tester.pumpWidget(
        MaterialApp(home: OfflinePackagesScreen(manager: store)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      store.fail = false;
      await tester.tap(find.text('Paketleri yeniden dene'));
      await tester.pumpAndSettle();
      expect(find.text('Kurulu çevrimdışı paket yok.'), findsOneWidget);
    },
  );
}
