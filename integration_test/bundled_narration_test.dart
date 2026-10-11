import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hac_umre_sesli_rehber/audio_controls.dart';
import 'package:hac_umre_sesli_rehber/guide_catalog.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';

// Real device plugins and production catalog/assets. No QA audio or approval fixture.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'every bundled narration loads and advances on the native player',
    (tester) async {
      final service = JustAudioNarrationService();
      final records = <AudioRecord>[];
      for (final catalog in ['umre', 'hac']) {
        final data = GuideCatalog.fromJsonText(
          await rootBundle.loadString(
            'assets/content/${catalog}_inventory.v1.json',
          ),
        );
        records.addAll(
          data.audioRecords.values.where((audio) => audio.asset != null),
        );
      }
      expect(records, isNotEmpty);
      expect(records.map((audio) => audio.id).toSet().length, records.length);
      try {
        for (final record in records) {
          final asset = record.asset!;
          expect(await rootBundle.load(asset), isNotNull, reason: record.id);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AudioControls(
                    narration: service,
                    asset: asset,
                    title: record.id,
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Anlatımı dinle'));
          final deadline = DateTime.now().add(const Duration(seconds: 20));
          while (service.position <= Duration.zero &&
              DateTime.now().isBefore(deadline)) {
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              service.state.status,
              isNot(NarrationStatus.error),
              reason: record.id,
            );
          }
          expect(service.state.asset, asset);
          expect(
            service.state.status,
            NarrationStatus.playing,
            reason: record.id,
          );
          expect(
            service.position,
            greaterThan(Duration.zero),
            reason: record.id,
          );
          expect(
            service.duration,
            greaterThan(Duration.zero),
            reason: record.id,
          );
          await tester.tap(find.text('Duraklat'));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            service.state.status,
            NarrationStatus.paused,
            reason: record.id,
          );
          await service.seek(const Duration(seconds: 1));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            service.position.inMilliseconds,
            inInclusiveRange(750, 1250),
            reason: '${record.id} native seek',
          );
          await service.setSpeed(1.25);
          expect(service.speed, 1.25);
          await tester.tap(find.text('Devam et'));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            service.state.status,
            NarrationStatus.playing,
            reason: record.id,
          );
          await service.stop();
          expect(service.state.status, NarrationStatus.idle);
          debugPrint('BUNDLED_NARRATION_NATIVE ${record.id} $asset passed');
        }
        // Rapid replacement uses two actual catalog files and keeps the final request.
        expect(records.length, greaterThan(1));
        await Future.wait([
          service.playAsset(records.first.asset!),
          service.playAsset(records.last.asset!),
          service.playAsset(records.last.asset!),
        ]);
        expect(service.state.asset, records.last.asset);
        expect(service.state.status, NarrationStatus.playing);
        final pendingSeek = service.seek(const Duration(seconds: 20));
        await tester.pump();
        final pendingPause = service.pause();
        final replacement = service.playAsset(records.first.asset!);
        await Future.wait([pendingSeek, pendingPause, replacement]);
        expect(service.state.asset, records.first.asset);
        expect(service.state.status, NarrationStatus.playing);
        expect(service.position, lessThan(const Duration(seconds: 1)));
        await service.stop();
      } finally {
        service.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
