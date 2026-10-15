import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/content_repository.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/journey_preparation_screen.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';

class NetworkMustNotBeCalled extends OfflinePackageProvider {
  int calls = 0;
  @override
  Future<List<OfflinePackageManifest>> loadCatalog() async {
    calls++;
    throw StateError('Preparation must only read local data');
  }

  @override
  Future<PackageActivationState> downloadAndActivate(
    OfflinePackageManifest m,
  ) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<GuideType, GuideCatalog> catalogs;
  setUpAll(() async {
    catalogs = await const LocalContentRepository().load();
  });
  testWidgets('hazırlık ağ istemez ve onaysız Hac içeriğini hazır göstermez', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('preparation_');
    addTearDown(() => root.deleteSync(recursive: true));
    final provider = NetworkMustNotBeCalled();
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: JourneyPreparationScreen(
            catalogs: catalogs,
            packages: OfflinePackageManager(root: root),
            provider: provider,
            initialType: GuideType.hajj,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(provider.calls, 0);
    await tester.scrollUntilVisible(find.text('Onaylı adım bulunmuyor'), 200);
    expect(find.text('Onaylı adım bulunmuyor'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('0 / 0 izinli ses'),
      200,
    );
    expect(find.textContaining('0 / 0 izinli ses'), findsOneWidget);
    expect(find.textContaining('taslak ses'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Rehber ve ses paketlerine git'),
      200,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      await tester.tap(find.text('Rehber ve ses paketlerine git'));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('Rehber ve izinli ses paketleri'), findsOneWidget);
    expect(provider.calls, 1);
  });
  testWidgets('Umre hazırlığında demo anlatım görünmez', (tester) async {
    final root = Directory.systemTemp.createTempSync('preparation_umrah_');
    addTearDown(() => root.deleteSync(recursive: true));
    final provider = NetworkMustNotBeCalled();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: JourneyPreparationScreen(
            catalogs: catalogs,
            packages: OfflinePackageManager(root: root),
            provider: provider,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Onaylı adım bulunmuyor'), 200);
    await tester.scrollUntilVisible(
      find.textContaining('0 / 0 izinli ses dosyası'),
      200,
    );
    expect(find.textContaining('0 / 0 izinli ses dosyası'), findsOneWidget);
    expect(find.textContaining('taslak kayıt'), findsNothing);
    expect(provider.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
