import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/audio_controls.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('paused and completed audio have distinct visible states', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final audio = FakeNarration();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioControls(
              narration: audio,
              asset: 'demo',
              title: 'Teknik ses',
            ),
          ),
        ),
      );
      await tester.tap(find.text('Anlatımı dinle'));
      await tester.pumpAndSettle();
      expect(find.text('Duraklat'), findsOneWidget);
      await tester.tap(find.text('Duraklat'));
      await tester.pumpAndSettle();
      expect(find.text('Ses duraklatıldı'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Ses duraklatıldı')).label,
        'Ses duraklatıldı',
      );
      expect(find.text('Ses tamamlandı'), findsNothing);
      audio.finish();
      await tester.pumpAndSettle();
      expect(find.text('Ses tamamlandı'), findsOneWidget);
      expect(find.text('Ses duraklatıldı'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      audio.dispose();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('another card never claims the selected audio paused', (
    tester,
  ) async {
    final audio = FakeNarration()
      ..current = const NarrationState(NarrationStatus.paused, asset: 'other');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AudioControls(
            narration: audio,
            asset: 'demo',
            title: 'Teknik ses',
          ),
        ),
      ),
    );
    expect(find.text('Ses duraklatıldı'), findsNothing);
    expect(find.text('Anlatımı dinle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    audio.dispose();
  });
}
