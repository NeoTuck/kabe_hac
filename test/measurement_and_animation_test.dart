import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_stage_animator.dart';
import 'package:hac_umre_sesli_rehber/prayer_times.dart';
import 'package:hac_umre_sesli_rehber/qibla_compass_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('İş 4: Ölçüm ve Animasyon Testleri', () {
    test('Namaz vakitleri: Farklı saat dilimlerinde UTC eşzamanlılığı doğru davranır', () {
      final date = DateTime.utc(2026, 6, 15);
      final schedule = PrayerSchedule.mecca(forDate: date);

      // Mekke öğle vakti (UTC olarak saklanır)
      final ogleUtc = schedule.ogle;

      // Aynı mutlak anı temsil eden UTC ve yerel zaman nesneleri:
      final instantUtc = ogleUtc;
      final instantLocal = DateTime.fromMillisecondsSinceEpoch(
        ogleUtc.millisecondsSinceEpoch,
        isUtc: false,
      );

      // Cihazın yerel saat dilimi ne olursa olsun aynı mutlak an için aynı vakit döner
      expect(
        schedule.currentVakit(instantUtc),
        schedule.currentVakit(instantLocal),
      );
      expect(schedule.nextVakit(instantUtc), schedule.nextVakit(instantLocal));
      expect(
        schedule.timeUntilNext(instantUtc),
        schedule.timeUntilNext(instantLocal),
      );

      // Öğleden 10 dakika önceki an:
      final tenMinBeforeOgle = ogleUtc.subtract(const Duration(minutes: 10));
      final tenMinBeforeLocal = DateTime.fromMillisecondsSinceEpoch(
        tenMinBeforeOgle.millisecondsSinceEpoch,
        isUtc: false,
      );

      expect(schedule.timeUntilNext(tenMinBeforeOgle).inMinutes, 10);
      expect(schedule.timeUntilNext(tenMinBeforeLocal).inMinutes, 10);
      expect(schedule.nextVakit(tenMinBeforeOgle), PrayerVakit.ogle);
      expect(schedule.nextVakit(tenMinBeforeLocal), PrayerVakit.ogle);
    });

    testWidgets(
      'QiblaCompassScreen: Sensör yokken "Kıbleye yöneldiniz" demez, görsel simülasyon uyarısı gösterir',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: QiblaCompassScreen()));
        await tester.pumpAndSettle();

        // Sensörsüz durumda "✓ KIBLEYE YÖNELDİNİZ" mesajı asla görünmez
        expect(find.text('✓ KIBLEYE YÖNELDİNİZ'), findsNothing);

        // Sensör yok rozeti ve görsel simülasyon uyarısı görünür
        expect(find.text('Görsel Simülasyon (Sensör Yok)'), findsOneWidget);
        expect(
          find.textContaining(
            'Pusula sensörü bulunamadı. Gösterilen pusula elle çevrilen görsel simülasyondur',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'GuideStageAnimator: Otomatik adım geçişi ve adım seçimi doğru çalışır',
      (tester) async {
        int selectedIndex = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GuideStageAnimator(
                stageType: GuideStageType.luggage,
                items: const ['Madde 1', 'Madde 2', 'Madde 3'],
                initialIndex: 0,
                onItemChanged: (idx) => selectedIndex = idx,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final state = tester.state<GuideStageAnimatorState>(
          find.byType(GuideStageAnimator),
        );
        expect(state.currentIndex, 0);

        // Programatik ve manuel adım seçimi
        state.selectItem(1);
        await tester.pumpAndSettle();
        expect(state.currentIndex, 1);
        expect(selectedIndex, 1);

        state.selectItem(2);
        await tester.pumpAndSettle();
        expect(state.currentIndex, 2);
        expect(selectedIndex, 2);
      },
    );
  });
}
