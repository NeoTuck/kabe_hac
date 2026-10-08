import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_theme.dart';
import 'content_repository.dart';
import 'guide_catalog.dart';
import 'group_repository.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_downloader.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'safety_catalog.dart';
import 'selection_screens.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final name in ['NotoSans', 'NotoNaskhArabic']) {
      yield LicenseEntryWithLineBreaks([
        name,
      ], await rootBundle.loadString('assets/fonts/$name-OFL.txt'));
    }
  });
  final store = ProgressStore();
  try {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId:
            'com.mustafasenoglu.hac_umre_sesli_rehber.audio',
        androidNotificationChannelName: 'Sesli rehber oynatma',
      );
    } catch (_) {
      // Keep the offline guide available; first play reports device audio errors.
    }
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
    final narration = JustAudioNarrationService(packages: packages);
    final settings = ReaderSettings(store, narration);
    // Device audio is initialized on first play; the guide remains available if it fails.
    final contentRepository = LocalContentRepository(packages: packages);
    final catalogs = await contentRepository.load();
    final travelRepository = LocalTravelRepository(packages: packages);
    final travelCatalog = await travelRepository.load();
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
    GroupRepository groups = UnconfiguredGroupRepository();
    try {
      final config = GroupRuntimeConfig.fromCompileTime();
      if (config != null) {
        await Supabase.initialize(
          url: config.url,
          publishableKey: config.publishableKey,
        );
        groups = SupabaseGroupRepository(Supabase.instance.client);
      }
    } catch (_) {
      // A backend failure never locks the offline guide behind sign-in.
    }
    await settings.load();
    runApp(
      SesliRehberApp(
        groups: groups,
        store: store,
        catalogs: catalogs,
        contentRepository: contentRepository,
        travelRepository: travelRepository,
        narration: narration,
        settings: settings,
        packages: packages,
        packageProvider: packageProvider,
        packageConfigurationError: packageConfigurationError,
        travelCatalog: travelCatalog,
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
    this.groups,
    this.contentRepository,
    this.travelRepository,
    this.packages,
    this.packageProvider,
    this.packageConfigurationError,
    this.travelCatalog,
    this.safetyCatalog,
  });

  final GroupRepository? groups;
  final LocalContentRepository? contentRepository;
  final LocalTravelRepository? travelRepository;
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
      theme: RehberTheme.build(Brightness.light),
      darkTheme: RehberTheme.build(Brightness.dark),
      themeMode: settings.themeMode,
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
        groups: groups,
        contentRepository: contentRepository,
        travelRepository: travelRepository,
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
