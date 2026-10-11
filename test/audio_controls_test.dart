import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/audio_controls.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';

import 'test_fakes.dart';

class SpeedFailureNarration extends FakeNarration {
  bool fail = false;
  @override
  Future<void> setSpeed(double value) async {
    if (fail) throw StateError('device unavailable');
    await super.setSpeed(value);
  }
}

void main() {
  testWidgets(
    'speed failure preserves preference and paused playback is not resumed',
    (tester) async {
      final audio = SpeedFailureNarration();
      await audio.playAsset('bundled-fixture');
      await audio.pause();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AudioControls(
                narration: audio,
                asset: 'bundled-fixture',
                title: 'Taslak anlatım',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Anlatım hızı · 1.0×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.25×'));
      await tester.pumpAndSettle();
      expect(find.text('Anlatım hızı · 1.25×'), findsOneWidget);
      expect(audio.state.status, NarrationStatus.paused);
      audio.fail = true;
      await tester.tap(find.text('Anlatım hızı · 1.25×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.5×'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ses hızı değiştirilemedi. Yeniden dene.'),
        findsOneWidget,
      );
      expect(find.text('Anlatım hızı · 1.25×'), findsOneWidget);
      expect(audio.state.status, NarrationStatus.paused);
      audio.fail = false;
      await tester.tap(find.text('Anlatım hızı · 1.25×'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0.75×'));
      await tester.pumpAndSettle();
      expect(find.text('Anlatım hızı · 0.75×'), findsOneWidget);
      expect(find.text('Devam et'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      audio.dispose();
    },
  );

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
      expect(find.text('Devam et'), findsOneWidget);
      await tester.tap(find.text('Devam et'));
      await tester.pumpAndSettle();
      expect(find.text('Duraklat'), findsOneWidget);
      expect(find.text('Ses duraklatıldı'), findsNothing);
      audio.finish();
      await tester.pumpAndSettle();
      expect(find.text('Ses tamamlandı'), findsOneWidget);
      expect(find.text('Ses duraklatıldı'), findsNothing);
      expect(find.text('Baştan dinle'), findsOneWidget);
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
