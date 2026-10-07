import 'package:flutter/material.dart';

import 'audio_controls.dart';
import 'narration_service.dart';
import 'progress_store.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key, required this.store, required this.narration});

  static const stepId = 'DEMO-001';
  static const audioAsset = 'assets/audio/teknik_demo.m4a';

  final ProgressStore store;
  final NarrationService narration;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  @override
  void initState() {
    super.initState();
    widget.store.saveLastStepId(DemoScreen.stepId);
  }

  @override
  void dispose() {
    widget.narration.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Teknik örnek kart')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'TEKNİK ÖRNEK · ${DemoScreen.stepId}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Ses ve Arapça yazı yönü',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const Text(
            'Bu kart ve sentetik kayıt teknik denemedir. Dinî açıklama veya dua değildir.',
          ),
          const SizedBox(height: 24),
          const Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'هذا نص تجريبي',
              textAlign: TextAlign.start,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: 26,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Türkçesi: Bu yalnızca deneme metnidir.'),
          const SizedBox(height: 28),
          AudioControls(
            narration: widget.narration,
            asset: DemoScreen.audioAsset,
            title: 'Sentetik teknik ses',
          ),
        ],
      ),
    ),
  );
}
