import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/guide_stage_animator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'GuideStageAnimator arafat sahnelerini gündüz ve gece doğru çizer',
    (tester) async {
      int activeIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuideStageAnimator(
              stageType: GuideStageType.arafat,
              items: const [
                'Arafat sınırları ve Cebelü’r-Rahme',
                'Nemire Mescidi cem-i takdim',
                'Arafat vakfesi ve dualar',
                'Müzdelife intikali',
                'Müzdelife cem-i tehir',
                '70 taş toplama',
              ],
              initialIndex: 0,
              onItemChanged: (idx) => activeIndex = idx,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify stage header and title
      expect(find.text('Arafat Vakfesi & Cebelü’r-Rahme'), findsOneWidget);
      expect(find.byType(GuideStageAnimator), findsOneWidget);

      // Switch to index 4 (Müzdelife gece aşaması)
      final state = tester.state<GuideStageAnimatorState>(
        find.byType(GuideStageAnimator),
      );
      state.selectItem(4);
      await tester.pumpAndSettle();
      expect(state.currentIndex, 4);
      expect(activeIndex, 4);
    },
  );

  testWidgets(
    'GuideStageAnimator sağa kaydırma ile sonraki adıma geçer ve sola kaydırma ile geri döner',
    (tester) async {
      int activeIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuideStageAnimator(
              stageType: GuideStageType.tawaf,
              items: const [
                'Şavt 1: Başlangıç',
                'Şavt 2: Devam',
                'Şavt 3: Dua',
              ],
              initialIndex: 0,
              onItemChanged: (idx) => activeIndex = idx,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state<GuideStageAnimatorState>(
        find.byType(GuideStageAnimator),
      );
      expect(state.currentIndex, 0);

      final stageGesture = find
          .descendant(
            of: find.byType(GuideStageAnimator),
            matching: find.byType(GestureDetector),
          )
          .first;
      // Fling horizontally to the right (velocity > 180) -> Parmakla sağa kaydırma: Sıradakine geçiş
      await tester.fling(stageGesture, const Offset(300, 0), 1000);
      await tester.pumpAndSettle();

      expect(state.currentIndex, 1);
      expect(activeIndex, 1);

      // Fling horizontally to the left (velocity < -180) -> Parmakla sola kaydırma: Öncekine geçiş
      await tester.fling(stageGesture, const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(state.currentIndex, 0);
      expect(activeIndex, 0);
    },
  );

  testWidgets('GuideStageAnimator büyüt tam ekran modunu açar ve kapatır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GuideStageAnimator(
            stageType: GuideStageType.say,
            items: const ['Safa tepesi', 'Merve intikali'],
            initialIndex: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap fullscreen icon
    final fullscreenButton = find.byTooltip('Büyüt / Tam Ekran');
    expect(fullscreenButton, findsOneWidget);
    await tester.tap(fullscreenButton);
    await tester.pumpAndSettle();

    // Fullscreen screen is displayed
    expect(find.byType(FullscreenStageScreen), findsOneWidget);
    expect(find.text('Safa tepesi'), findsWidgets);

    // Tap close button in fullscreen
    final closeButton = find.byTooltip('Kapat');
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    // Returned to normal screen
    expect(find.byType(FullscreenStageScreen), findsNothing);
    expect(find.byType(GuideStageAnimator), findsOneWidget);
  });
}
