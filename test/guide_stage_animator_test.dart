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
}
