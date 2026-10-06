import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';
import 'package:hac_umre_sesli_rehber/package_screen.dart';

class FakePackageProvider extends OfflinePackageProvider {
  FakePackageProvider(this.manifest);

  final OfflinePackageManifest manifest;
  int downloadCalls = 0;

  @override
  Future<List<OfflinePackageManifest>> loadCatalog() async => [manifest];

  @override
  Future<PackageActivationState> downloadAndActivate(
    OfflinePackageManifest manifest,
  ) async {
    downloadCalls++;
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

void main() {
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
    final manifest = OfflinePackageManifest.fromJson({
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
    final provider = FakePackageProvider(manifest);
    await tester.pumpWidget(
      MaterialApp(
        home: OfflinePackagesScreen(manager: manager, provider: provider),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('umre-audio-tr'), findsOneWidget);
    expect(find.textContaining('audio · 1.0.0'), findsOneWidget);
    await tester.tap(find.text('İndir'));
    await tester.pumpAndSettle();
    expect(provider.downloadCalls, 1);
  });
}
