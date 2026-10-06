import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'content_repository.dart';
import 'guide_catalog.dart';
import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_downloader.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'safety_catalog.dart';
import 'selection_screens.dart';
import 'travel_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = ProgressStore();
  final narration = JustAudioNarrationService();
  final settings = ReaderSettings(store, narration);
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId:
          'com.mustafasenoglu.hac_umre_sesli_rehber.audio',
      androidNotificationChannelName: 'Sesli rehber oynatma',
    );
    await narration.initialize();
    final catalogs = await const LocalContentRepository().load();
    final supportDirectory = await getApplicationSupportDirectory();
    OfflinePackageRuntimeConfig? packageConfig;
    String? packageConfigurationError;
    try {
      packageConfig = OfflinePackageRuntimeConfig.fromCompileTime();
    } on PackageCatalogException catch (error) {
      packageConfigurationError = error.message;
    }
    final packageTrust = packageConfig == null
        ? const RejectUntrustedManifests()
        : PinnedManifestDigestPolicy(packageConfig.trustedManifestDigests);
    final packages = OfflinePackageManager(
      root: Directory(path.join(supportDirectory.path, 'offline_packages')),
      trustPolicy: packageTrust,
    );
    final packageProvider = packageConfig == null
        ? null
        : ConfiguredOfflinePackageProvider(
            client: PackageCatalogClient(
              catalogUri: packageConfig.catalogUri,
              allowedHosts: packageConfig.allowedHosts,
              trustPolicy: packageTrust,
              fetcher: HttpPackageCatalogTextFetcher(),
            ),
            downloader: PackageDownloadCoordinator(
              manager: packages,
              fetcher: HttpPackageFileFetcher(),
              allowedHosts: packageConfig.allowedHosts,
            ),
          );
    await settings.load();
    runApp(
      SesliRehberApp(
        store: store,
        catalogs: catalogs,
        narration: narration,
        settings: settings,
        packages: packages,
        packageProvider: packageProvider,
        packageConfigurationError: packageConfigurationError,
        travelCatalog: const TravelCatalog(
          dataVersion: 'not-configured',
          points: [],
          routes: [],
        ),
        safetyCatalog: const SafetyCatalog(
          dataVersion: 'not-configured',
          contacts: [],
          languageCards: [],
          fieldInformation: [],
        ),
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
    this.packages,
    this.packageProvider,
    this.packageConfigurationError,
    this.travelCatalog,
    this.safetyCatalog,
  });

  final ProgressStore store;
  final Map<GuideType, GuideCatalog> catalogs;
  final NarrationService narration;
  final ReaderSettings settings;
  final OfflinePackageManager? packages;
  final OfflinePackageProvider? packageProvider;
  final String? packageConfigurationError;
  final TravelCatalog? travelCatalog;
  final SafetyCatalog? safetyCatalog;

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
        packages: packages,
        packageProvider: packageProvider,
        packageConfigurationError: packageConfigurationError,
        travelCatalog: travelCatalog,
        safetyCatalog: safetyCatalog,
      ),
    ),
  );
}
