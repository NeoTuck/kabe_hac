// Dedicated native QA entry point. Never imported by lib/main.dart.
import 'package:flutter/material.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!const bool.fromEnvironment('KABE_AUDIO_QA') ||
      const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Audio probe is restricted to explicit debug QA builds.');
  }
  runApp(const MaterialApp(home: AudioProbe()));
}

class AudioProbe extends StatefulWidget {
  const AudioProbe({super.key});
  @override
  State<AudioProbe> createState() => _AudioProbeState();
}

class _AudioProbeState extends State<AudioProbe> {
  final audio = JustAudioNarrationService();
  @override
  void dispose() {
    audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yalnız teknik ses testi')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: audio,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Dinî içerik veya insan sesi kabulü değildir.'),
            Text(switch (audio.state.status) {
              NarrationStatus.idle => 'Ses durdu',
              NarrationStatus.loading => 'Ses yükleniyor',
              NarrationStatus.playing => 'Ses oynuyor',
              NarrationStatus.paused => 'Ses duraklatıldı',
              NarrationStatus.completed => 'Ses tamamlandı',
              NarrationStatus.error => 'Ses hatası',
            }),
            Text('Konum: ${audio.position.inSeconds}'),
            if (audio.position >= const Duration(seconds: 1))
              const Text('Konum ilerledi'),
            if (audio.duration != null) const Text('Süre alındı'),
            FilledButton(
              onPressed: () => audio.playAsset('assets/audio/teknik_demo.m4a'),
              child: const Text('Test sesini oynat'),
            ),
            FilledButton(onPressed: audio.pause, child: const Text('Duraklat')),
            FilledButton(
              onPressed: audio.resume,
              child: const Text('Devam et'),
            ),
            FilledButton(
              onPressed: () => audio.seek(const Duration(seconds: 29)),
              child: const Text('Sona yaklaş'),
            ),
            FilledButton(
              onPressed: audio.replay,
              child: const Text('Baştan dinle'),
            ),
            FilledButton(onPressed: audio.stop, child: const Text('Durdur')),
          ],
        ),
      ),
    ),
  );
}
