import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';

import 'guide_catalog.dart';
import 'guide_screens.dart';
import 'progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final catalog = await GuideCatalog.loadAsset();
  runApp(SesliRehberApp(store: ProgressStore(), catalog: catalog));
}

class SesliRehberApp extends StatelessWidget {
  const SesliRehberApp({super.key, required this.store, required this.catalog});

  final ProgressStore store;
  final GuideCatalog catalog;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF176E68);
    return MaterialApp(
      title: 'Hac ve Umre Sesli Rehber',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        scaffoldBackgroundColor: const Color(0xFFF8F7F2),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF8F7F2)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
        ),
      ),
      home: HomeScreen(store: store, catalog: catalog),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store, required this.catalog});

  final ProgressStore store;
  final GuideCatalog catalog;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _lastStepId;
  String? _storageError;

  @override
  void initState() {
    super.initState();
    _loadLastStep();
  }

  Future<void> _loadLastStep() async {
    try {
      final id = await widget.store.readLastStepId();
      if (mounted) {
        setState(() {
          _lastStepId = id;
          _storageError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _storageError = 'Yerel kayıt okunamadı.');
      }
    }
  }

  Future<void> _openDemo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoStepScreen(store: widget.store),
      ),
    );
    if (mounted) await _loadLastStep();
  }

  Future<void> _openUmrah(GuideMode mode) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UmrahFlowScreen(
          store: widget.store,
          catalog: widget.catalog,
          mode: mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sesli Rehber')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            Icon(Icons.menu_book_rounded, size: 64, color: colors.primary),
            const SizedBox(height: 24),
            Text(
              'Hac ve Umre',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Türkçe sesli rehber',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 28),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UMRE · 18 ADIMLIK ENVANTER',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Öğrenme ve yolculuk akışı ayrı kaydedilir. Başlıklar hazır; kaynaklı dinî açıklama ve insan seslendirmesi inceleme aşamasında.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openUmrah(GuideMode.learning),
              icon: const Icon(Icons.school_rounded),
              label: const Text('Umreyi öğren'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openUmrah(GuideMode.journey),
              icon: const Icon(Icons.route_rounded),
              label: const Text('Yolculukta rehber'),
            ),
            const SizedBox(height: 30),
            Text(
              'Teknik deneme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openDemo,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(
                _lastStepId == DemoStepScreen.stepId
                    ? 'Ses örneğine kaldığım yerden devam'
                    : 'Ses ve Arapça örnek kartını aç',
              ),
            ),
            if (_storageError != null) ...[
              const SizedBox(height: 16),
              Text(_storageError!, style: TextStyle(color: colors.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class DemoStepScreen extends StatefulWidget {
  const DemoStepScreen({super.key, required this.store});

  static const stepId = 'DEMO-001';
  final ProgressStore store;

  @override
  State<DemoStepScreen> createState() => _DemoStepScreenState();
}

class _DemoStepScreenState extends State<DemoStepScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _audioReady = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.store.saveLastStepId(DemoStepScreen.stepId);
    } catch (_) {
      // The card remains readable if local storage is temporarily unavailable.
    }
    try {
      await _player.setAsset('assets/audio/teknik_demo.m4a');
      if (mounted) setState(() => _audioReady = true);
    } catch (_) {
      if (mounted) setState(() => _audioError = 'Örnek ses açılamadı.');
    }
  }

  Future<void> _toggleAudio() async {
    if (!_audioReady) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> _rewind() async {
    final position = _player.position - const Duration(seconds: 10);
    await _player.seek(position.isNegative ? Duration.zero : position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Örnek adım')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'TEKNİK PROTOTİP · ${DemoStepScreen.stepId}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Bir adım kartı nasıl görünür?',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bu kart okunabilirlik, Arapça yazı yönü, ses oynatma ve yerel kayıt için hazırlanmış bir denemedir. Dinî açıklama veya dua içermez.',
            ),
            const SizedBox(height: 28),
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Arapça yazı yönü örneği',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    const Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        'هذا نص تجريبي',
                        textAlign: TextAlign.start,
                        style: TextStyle(fontSize: 26, height: 1.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Türkçesi: Bu yalnızca deneme metnidir.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Örnek ses', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Cihazda saklanan, sentetik teknik demo kaydı.'),
            const SizedBox(height: 16),
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return FilledButton.icon(
                  onPressed: _audioReady ? _toggleAudio : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(playing ? 'Durdur' : 'Anlatımı dinle'),
                );
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _audioReady ? _rewind : null,
              icon: const Icon(Icons.replay_10_rounded),
              label: const Text('10 saniye geri sar'),
            ),
            if (_audioError != null) ...[
              const SizedBox(height: 12),
              Text(_audioError!, style: TextStyle(color: colors.error)),
            ],
            const SizedBox(height: 24),
            const Text('İçerik durumu: Uzman onaylı kart bekleniyor.'),
          ],
        ),
      ),
    );
  }
}
