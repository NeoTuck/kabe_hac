import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'app_theme.dart';
import 'content_repository.dart';
import 'guide_catalog.dart';
import 'group_repository.dart';
import 'group_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_downloader.dart';
import 'progress_store.dart';
import 'push_service.dart';
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
    final bundledCatalogs = await const LocalContentRepository().load();
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
    final navigatorKey = GlobalKey<NavigatorState>();
    PushTokenCoordinator? push;
    if (groups is SupabaseGroupRepository &&
        (Platform.isAndroid || Platform.isIOS)) {
      try {
        final config = PushRuntimeConfig.fromCompileTime();
        if (config != null) {
          await Firebase.initializeApp(options: config.firebaseOptions);
          push = PushTokenCoordinator(
            source: const FirebasePushTokenSource(),
            remote: SupabasePushTokenRemote(groups.client),
            currentUserId: () => groups.userId,
            platform: Platform.isAndroid ? 'android' : 'ios',
            store: store,
          );
          unawaited(push.resumeIfEnabled().catchError((Object _) {}));
          _wirePushRouting(
            FirebaseMessaging.instance,
            groups,
            store,
            navigatorKey,
          );
        }
      } catch (_) {
        // No permission is requested when project setup is incomplete.
      }
    }
    await settings.load();
    runApp(
      SesliRehberApp(
        groups: groups,
        push: push,
        navigatorKey: navigatorKey,
        store: store,
        catalogs: catalogs,
        bundledCatalogs: bundledCatalogs,
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

void _wirePushRouting(
  FirebaseMessaging messaging,
  GroupRepository groups,
  ProgressStore store,
  GlobalKey<NavigatorState> navigatorKey,
) {
  Future<void> open(RemoteMessage message) async {
    final target = PushRouteTarget.parse(message.data);
    final uid = groups.userId;
    if (target == null || uid == null) return;
    try {
      final available = await groups.groups();
      if (groups.userId != uid) return;
      final matching = available
          .where((g) => g.id == target.groupId)
          .firstOrNull;
      final navigator = navigatorKey.currentState;
      if (matching == null || navigator == null) return;
      await navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(
            group: matching,
            repository: groups,
            store: store,
          ),
        ),
      );
    } catch (_) {
      // Revoked membership or network failure never exposes notification data.
    }
  }

  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => unawaited(open(message)),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      messaging
          .getInitialMessage()
          .then((message) async {
            if (message != null) await open(message);
          })
          .catchError((Object _) {}),
    );
  });
}

class SesliRehberApp extends StatelessWidget {
  const SesliRehberApp({
    super.key,
    required this.store,
    required this.catalogs,
    this.bundledCatalogs,
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
    this.push,
    this.navigatorKey,
  });

  final GroupRepository? groups;
  final LocalContentRepository? contentRepository;
  final LocalTravelRepository? travelRepository;
  final ProgressStore store;
  final Map<GuideType, GuideCatalog> catalogs;
  final Map<GuideType, GuideCatalog>? bundledCatalogs;
  final NarrationService narration;
  final ReaderSettings settings;
  final OfflinePackageManager? packages;
  final OfflinePackageProvider? packageProvider;
  final String? packageConfigurationError;
  final TravelCatalog? travelCatalog;
  final SafetyCatalog? safetyCatalog;
  final PushTokenCoordinator? push;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
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
        push: push,
        contentRepository: contentRepository,
        travelRepository: travelRepository,
        store: store,
        catalogs: catalogs,
        bundledCatalogs: bundledCatalogs,
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
