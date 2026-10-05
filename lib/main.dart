import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'content_repository.dart';
import 'guide_catalog.dart';
import 'narration_service.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'selection_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProgressStore();
  final narration = JustAudioNarrationService();
  final settings = ReaderSettings(store, narration);
  try {
    final catalogs = await const LocalContentRepository().load();
    await settings.load();
    runApp(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: settings,
      ),
    );
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Text(
                'İçerik veya yerel kayıt açılamadı. Uygulamayı yeniden başlat.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SesliRehberApp extends StatelessWidget {
  const SesliRehberApp({
    super.key,
    required this.store,
    required this.catalogs,
    required this.narration,
    required this.settings,
  });

  final ProgressStore store;
  final Map<GuideType, GuideCatalog> catalogs;
  final NarrationService narration;
  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => MaterialApp(
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176E68)),
        scaffoldBackgroundColor: const Color(0xFFF8F7F2),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF8F7F2)),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final systemScale = media.textScaler.scale(1);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              systemScale * settings.textMultiplier,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: settings,
      ),
    ),
  );
}
