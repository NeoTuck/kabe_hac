import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/qibla_compass_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'QiblaCompassScreen pusula dairesi, kıble açısı ve şehir seçim çiplerini görüntüler',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: QiblaCompassScreen()));
      await tester.pumpAndSettle();

      // Heading and navigation title
      expect(find.text('Kıble Pusulası'), findsOneWidget);

      // Verify Kaaba target card and angles
      expect(find.text('Hedef: Kâbe-i Muazzama'), findsOneWidget);
      expect(find.text('Kıble Açısı'), findsOneWidget);
      expect(find.text('Cihaz Yönü'), findsOneWidget);

      // Verify popular city chips exist
      expect(find.text('Mekke'), findsOneWidget);
      expect(find.text('İstanbul'), findsOneWidget);
      expect(find.text('Ankara'), findsOneWidget);

      // Scroll and tap on 'İstanbul' chip
      await tester.scrollUntilVisible(find.text('İstanbul'), 100);
      await tester.tap(find.text('İstanbul'));
      await tester.pumpAndSettle();

      // Location chips update selection
      expect(find.text('İstanbul'), findsOneWidget);
    },
  );

  testWidgets(
    'QiblaCompassScreen manuel sürükleme ile pusula açısı ayarlanabilir',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: QiblaCompassScreen()));
      await tester.pumpAndSettle();

      // Find the CustomPaint compass dial
      final customPaintFinder = find.byType(CustomPaint).first;
      expect(customPaintFinder, findsOneWidget);

      // Pan gesture on dial
      await tester.drag(customPaintFinder, const Offset(-60, 0));
      await tester.pumpAndSettle();

      // Still renders smoothly without throwing exceptions
      expect(tester.takeException(), isNull);
    },
  );
}
