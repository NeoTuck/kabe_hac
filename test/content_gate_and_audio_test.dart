import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_repository.dart';
import 'package:hac_umre_sesli_rehber/group_screen.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/guide_sections_screen.dart';
import 'package:hac_umre_sesli_rehber/prayers_screen.dart';

import 'test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('İş 1 & 2: İçerik Kapısı & Yanıltıcı Rota/Ses Doğrulaması', () {
    testWidgets(
      'GuideSectionsScreen: Boş katalog verildiğinde dürüst boş durum gösterir, onaysız metin sızmaz',
      (tester) async {
        final store = MemoryGuideStore();
        final narration = FakeNarration();
        final unavailableCatalog = GuideCatalog.unavailable(GuideType.umrah);

        await tester.pumpWidget(
          MaterialApp(
            home: GuideSectionsScreen(
              type: GuideType.umrah,
              store: store,
              narration: narration,
              catalog: unavailableCatalog,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Dürüst boş durum başlığı ve açıklaması görünür
        expect(
          find.text('Onaylı rehber içeriği henüz bulunmuyor'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Rehber ve dinî adımlar uzman incelemesi tamamlandığında sunulacak',
          ),
          findsOneWidget,
        );

        // Sabit kodlanmış dinî bölümler normal boş uygulamada görünmez
        expect(
          find.textContaining('Bölüm 1: Valiz & Hazırlık Eşyaları'),
          findsNothing,
        );
        expect(
          find.textContaining('Bölüm 2: Mîkāt & İhram Kuralları'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'GuideSectionsScreen: Hac için de boş katalogda dürüst boş durum gösterir',
      (tester) async {
        final store = MemoryGuideStore();
        final narration = FakeNarration();
        final unavailableCatalog = GuideCatalog.unavailable(GuideType.hajj);

        await tester.pumpWidget(
          MaterialApp(
            home: GuideSectionsScreen(
              type: GuideType.hajj,
              store: store,
              narration: narration,
              catalog: unavailableCatalog,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Onaylı rehber içeriği henüz bulunmuyor'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Bölüm 1: Hac Hazırlığı & Mîkāt'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'PrayersScreen: Katalog olmadan veya boş katalogla açıldığında dürüst boş durum gösterir',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: PrayersScreen(catalog: null)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Onaylı dua kaydı henüz bulunmuyor'), findsOneWidget);
        expect(
          find.textContaining(
            'Dua metinleri dinî inceleme ve onay tamamlandığında sunulacak',
          ),
          findsOneWidget,
        );

        // Sabit 8 dua hardcoded olarak listelenmez
        expect(find.text('İhram ve Umre Niyeti'), findsNothing);
        expect(find.text('Telbiye Duası'), findsNothing);
      },
    );

    testWidgets(
      'GroupScreen: Uydurma otel lobisi ve sahte 1.4 km rota duyuruları temizlenmiştir',
      (tester) async {
        final store = MemoryGuideStore();
        final repository = UnconfiguredGroupRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: GroupScreen(repository: repository, store: store),
          ),
        );
        await tester.pumpAndSettle();

        // Sahte demo verileri bulunmaz
        expect(
          find.textContaining('otel lobisinde toplanıyoruz'),
          findsNothing,
        );
        expect(find.textContaining('1.4 km · 18 dk'), findsNothing);
        expect(find.textContaining('Rotayı Haritada Aç'), findsNothing);
        expect(find.textContaining('herkes otele ulaştı mı?'), findsNothing);

        // Dürüst boş durum görünür
        expect(find.text('Kafile duyurusu henüz bulunmuyor.'), findsOneWidget);
      },
    );
  });
}
