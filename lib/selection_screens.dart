import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'content_repository.dart';
import 'guide_catalog.dart';
import 'guide_sections_screen.dart';
import 'journey_preparation_screen.dart';
import 'offline_city_map_screen.dart';
import 'group_repository.dart';
import 'group_screen.dart';
import 'guide_screens.dart';
import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_screen.dart';
import 'push_service.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'safety_catalog.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';
import 'travel_screen.dart';
import 'route_studio_screen.dart';
import 'qibla_compass_screen.dart';
import 'prayers_screen.dart';
import 'prayer_times_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
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
    this.initialEnteredMainScreen = false,
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
  final bool initialEnteredMainScreen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GroupRepository _fallbackGroups = UnconfiguredGroupRepository();
  GroupRepository get _groups => widget.groups ?? _fallbackGroups;
  late Map<GuideType, GuideCatalog> _catalogs;
  TravelCatalog? _travelCatalog;
  int _refreshEpoch = 0;
  int _catalogRevision = 0;
  GuideSession? _latest;
  int _selectedTab = 0;
  final Set<int> _openedTabs = {0};
  late bool _hasEnteredMainScreen = widget.initialEnteredMainScreen;

  @override
  void initState() {
    super.initState();
    _catalogs = widget.catalogs;
    _travelCatalog = widget.travelCatalog;
    _refresh();
  }

  @override
  void dispose() {
    _fallbackGroups.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool reloadContent = false}) async {
    final epoch = ++_refreshEpoch;
    try {
      final catalogs = reloadContent
          ? await widget.contentRepository?.load() ?? widget.catalogs
          : _catalogs;
      final travel = reloadContent
          ? await widget.travelRepository?.load() ?? widget.travelCatalog
          : _travelCatalog;
      final session = await widget.store.readMostRecentSession();
      if (mounted && epoch == _refreshEpoch) {
        setState(() {
          _catalogs = catalogs;
          _travelCatalog = travel;
          if (reloadContent) _catalogRevision++;
          _latest = session;
        });
      }
    } catch (_) {}
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) {
      final reloadContent =
          screen is OfflinePackagesScreen || screen is JourneyPreparationScreen;
      await _refresh(reloadContent: reloadContent);
    }
  }

  void _openHajjGuide({HajjProfile? profile}) {
    _open(
      GuideSectionsScreen(
        type: GuideType.hajj,
        profile: profile,
        store: widget.store,
        narration: widget.narration,
        catalog: _catalogs[GuideType.hajj],
      ),
    );
  }

  Future<void> _openInstalledPackage(OfflinePackageManifest manifest) async {
    if (manifest.kind == OfflinePackageKind.map ||
        manifest.kind == OfflinePackageKind.travel) {
      final travel = await LocalTravelRepository(packages: widget.packages!)
          .load();
      if (!mounted) return;
      await _open(
        manifest.kind == OfflinePackageKind.map
            ? OfflineCityMapScreen(
                packages: widget.packages!,
                catalog: travel,
                initialPackageId: manifest.packageId,
                travelRepository: widget.travelRepository,
                onManageMaps: () =>
                    _manageTravelPackages(OfflinePackageKind.map),
              )
            : TravelScreen(
                store: widget.store,
                packages: widget.packages,
                catalog: travel,
                travelRepository: widget.travelRepository,
                onManagePackages: _manageTravelPackages,
              ),
      );
    } else if (manifest.kind == OfflinePackageKind.audio) {
      await _refresh(reloadContent: true);
      if (mounted) _choose(_latest?.type ?? GuideType.umrah);
    } else if (widget.safetyCatalog != null) {
      await _open(SafetyScreen(catalog: widget.safetyCatalog!));
    }
  }

  Future<void> _manageTravelPackages(OfflinePackageKind kind) => _open(
    OfflinePackagesScreen(
      manager: widget.packages!,
      provider: widget.packageProvider,
      configurationError: widget.packageConfigurationError,
      focusKind: kind,
      onOpen: _openInstalledPackage,
    ),
  );

  void _choose(GuideType type) {
    _open(
      ModeSelectionScreen(
        type: type,
        store: widget.store,
        catalog: _catalogs[type]!,
        narration: widget.narration,
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    setState(() {
      _selectedTab = index;
      _openedTabs.add(index);
    });
    if (index == 0) _refresh();
  }

  Widget _tab(int index) {
    if (!_openedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      1 => RouteStudioScreen(
        key: ValueKey(_catalogRevision),
        catalog:
            _travelCatalog ??
            const TravelCatalog(
              dataVersion: 'not-configured',
              points: [],
              routes: [],
            ),
        packages: widget.packages,
        travelRepository: widget.travelRepository,
        onManagePackages: widget.packages == null
            ? null
            : _manageTravelPackages,
        isTab: true,
      ),
      2 => GroupScreen(
        repository: _groups,
        store: widget.store,
        push: widget.push,
      ),
      3 => SettingsScreen(
        settings: widget.settings,
        push: widget.push,
        packages: widget.packages,
        packageProvider: widget.packageProvider,
        packageConfigurationError: widget.packageConfigurationError,
        onOpenPackage: _openInstalledPackage,
        onPackagesChanged: () => _refresh(reloadContent: true),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (!_hasEnteredMainScreen) {
            return;
          }
          if (_selectedTab != 0) {
            _selectTab(0);
          } else {
            setState(() => _hasEnteredMainScreen = false);
          }
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: !_hasEnteredMainScreen
            ? Scaffold(
                key: const ValueKey('portal_view'),
                body: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF05140F),
                        Color(0xFF0B261D),
                        Color(0xFF133B2E),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        child: KutluYolculukPortal(
                          progressPercent: 0,
                          onOpenHajj: () {
                            setState(() {
                              _hasEnteredMainScreen = true;
                              _selectedTab = 0;
                            });
                            _openHajjGuide();
                          },
                          onOpenUmrah: () {
                            setState(() {
                              _hasEnteredMainScreen = true;
                              _selectedTab = 0;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Scaffold(
                key: const ValueKey('main_view'),
                bottomNavigationBar: NavigationBar(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: _selectTab,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.auto_stories_outlined),
                      selectedIcon: Icon(Icons.auto_stories),
                      label: 'Rehber',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: 'Rota, Harita',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups),
                      label: 'Kafile',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune),
                      label: 'Ayarlar',
                    ),
                  ],
                ),
                appBar: _selectedTab == 0
                    ? AppBar(
                        title: const Text('Hac ve Umre Sesli Rehber'),
                        actions: [
                          IconButton(
                            tooltip: 'Yazı ve ses ayarları',
                            icon: const Icon(Icons.settings_rounded),
                            onPressed: () => _open(
                              SettingsScreen(
                                settings: widget.settings,
                                push: widget.push,
                                packages: widget.packages,
                                packageProvider: widget.packageProvider,
                                packageConfigurationError:
                                    widget.packageConfigurationError,
                                onOpenPackage: _openInstalledPackage,
                                onPackagesChanged: () =>
                                    _refresh(reloadContent: true),
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
                body: IndexedStack(
                  index: _selectedTab,
                  children: [
                    SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // 1. Namaz Vakitleri (Requirement 5)
                          const PrayerTimesCard(),
                          const SizedBox(height: 20),

                          // 2. Umre Eğitimi Butonu (Requirement 8)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _open(
                                GuideSectionsScreen(
                                  type: GuideType.umrah,
                                  store: widget.store,
                                  narration: widget.narration,
                                  catalog: _catalogs[GuideType.umrah],
                                ),
                              ),
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF133E35),
                                      Color(0xFF1C5A4E),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: RehberTheme.goldLight.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: RehberTheme.goldLight.withValues(
                                          alpha: 0.18,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.school_rounded,
                                        color: RehberTheme.goldLight,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Umre Eğitimi',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Tüm rehber adımları, sesli anlatım ve dualar',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: RehberTheme.goldLight,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 3. Hac Eğitimi & Rehberi Butonu
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openHajjGuide,
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF1B4332),
                                      Color(0xFF2D6A4F),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: RehberTheme.goldLight.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: RehberTheme.goldLight.withValues(
                                          alpha: 0.18,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.mosque_rounded,
                                        color: RehberTheme.goldLight,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Hac Eğitimi & Rehberi',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Terviye, Arafat, Cemarat ve Farz Tavaf rehberi',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: RehberTheme.goldLight,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. Yardım ve önemli numaralar (Requirement 9)
                          if (widget.safetyCatalog != null)
                            _ChoiceCard(
                              icon: Icons.phone_in_talk_outlined,
                              title: 'Yardım ve önemli numaralar',
                              subtitle: 'Konsolosluk, acil servis ve sağlık iletişim hatları',
                              onTap: () => _open(
                                SafetyScreen(catalog: widget.safetyCatalog!),
                              ),
                            ),
                          const SizedBox(height: 12),

                          // 4. Kıble pusulası (Requirement 9)
                          _ChoiceCard(
                            icon: Icons.explore_outlined,
                            title: 'Kıble pusulası',
                            subtitle: 'Kâbe yönü, açısı ve mesafesi',
                            onTap: () => _open(
                              QiblaCompassScreen(
                                packages: widget.packages,
                                catalog: _travelCatalog,
                                travelRepository: widget.travelRepository,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // 5. Umre duaları (Requirement 9)
                          _ChoiceCard(
                            icon: Icons.menu_book_outlined,
                            title: 'Umre duaları',
                            subtitle: 'İhram, Telbiye, Tavaf ve Sa‘y duaları; zikir sayacı',
                            onTap: () => _open(
                              PrayersScreen(
                                catalog: _catalogs[GuideType.umrah],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _tab(1),
                    _tab(2),
                    _tab(3),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Card.outlined(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );
}

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({
    super.key,
    required this.type,
    required this.store,
    required this.catalog,
    required this.narration,
  });

  final GuideType type;
  final ProgressStore store;
  final GuideCatalog catalog;
  final NarrationService narration;

  void _select(BuildContext context, GuideMode mode) {
    final screen = type == GuideType.hajj
        ? HajjProfileScreen(
            mode: mode,
            store: store,
            catalog: catalog,
            narration: narration,
          )
        : GuideFlowScreen(
            mode: mode,
            profile: null,
            store: store,
            catalog: catalog,
            narration: narration,
          );
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${type.label} · kullanım biçimi')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ChoiceCard(
            icon: Icons.school_rounded,
            title: 'Öğrenme',
            subtitle: 'Başlıkları serbestçe incele',
            onTap: () => _select(context, GuideMode.learning),
          ),
          const SizedBox(height: 12),
          _ChoiceCard(
            icon: Icons.route_rounded,
            title: 'Yolculukta rehber',
            subtitle: 'Kişisel konumunu ve işaretlerini ayrı sakla',
            onTap: () => _select(context, GuideMode.journey),
          ),
        ],
      ),
    ),
  );
}

class HajjProfileScreen extends StatelessWidget {
  const HajjProfileScreen({
    super.key,
    required this.mode,
    required this.store,
    required this.catalog,
    required this.narration,
  });

  final GuideMode mode;
  final ProgressStore store;
  final GuideCatalog catalog;
  final NarrationService narration;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hac türü seç')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            HajjProfile.values.every(catalog.isProfileFlowVerified)
                ? 'Hac türüne göre incelenmiş akış açılır. İşaretler yalnız kişisel kayıttır.'
                : 'Profil kuralları henüz uzman onayından geçmedi. Seçim yalnız başlık envanterinin önizlemesini açar.',
          ),
          const SizedBox(height: 24),
          for (final profile in HajjProfile.values) ...[
            _ChoiceCard(
              icon: Icons.list_alt_rounded,
              title: profile.label,
              subtitle: catalog.isProfileFlowVerified(profile)
                  ? 'İncelenmiş profil akışı'
                  : 'Uygulanabilirlik doğrulanmadı',
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => GuideFlowScreen(
                    mode: mode,
                    profile: profile,
                    store: store,
                    catalog: catalog,
                    narration: narration,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );
}

class KutluYolculukPortal extends StatefulWidget {
  const KutluYolculukPortal({
    super.key,
    required this.onOpenHajj,
    required this.onOpenUmrah,
    this.progressPercent = 0,
  });

  final VoidCallback onOpenHajj;
  final VoidCallback onOpenUmrah;
  final int progressPercent;

  @override
  State<KutluYolculukPortal> createState() => _KutluYolculukPortalState();
}

class _KutluYolculukPortalState extends State<KutluYolculukPortal>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  AnimationController? _pulseController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _hacButtonSlide;
  late final Animation<double> _hacButtonFade;
  late final Animation<Offset> _umrahButtonSlide;
  late final Animation<double> _umrahButtonFade;
  late final Animation<double> _progressSweep;

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _scaleAnimation = Tween<double>(begin: 0.90, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack),
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, -0.20), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.15, 0.60, curve: Curves.easeOutCubic),
          ),
        );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.50, curve: Curves.easeIn),
      ),
    );
    _hacButtonSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.30, 0.75, curve: Curves.easeOutBack),
          ),
        );
    _hacButtonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.30, 0.65, curve: Curves.easeIn),
      ),
    );
    _umrahButtonSlide =
        Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.42, 0.88, curve: Curves.easeOutBack),
          ),
        );
    _umrahButtonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.42, 0.75, curve: Curves.easeIn),
      ),
    );
    _progressSweep = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.50, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    if (!_isTesting) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat(reverse: true);
    }

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetProgress = widget.progressPercent;

    return AnimatedBuilder(
      animation: Listenable.merge([_entryController, ?_pulseController]),
      builder: (context, _) {
        final pulse = _pulseController?.value ?? 1.0;
        final glowSpread = 1.0 + (pulse * 2.0);
        final glowBlur = 14.0 + (pulse * 10.0);

        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(
                  color: RehberTheme.goldLight.withValues(alpha: 0.65),
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: RehberTheme.emerald.withValues(
                      alpha: 0.45 + (pulse * 0.25),
                    ),
                    blurRadius: glowBlur,
                    spreadRadius: glowSpread,
                  ),
                  BoxShadow(
                    color: RehberTheme.goldLight.withValues(
                      alpha: 0.20 + (pulse * 0.15),
                    ),
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(35),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF071913),
                        Color(0xFF0E2D23),
                        Color(0xFF164234),
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 22,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Camera Notch / Dynamic Island simulation
                      Center(
                        child: Container(
                          width: 80,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF040D0A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0B241C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title & Subtitle
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleFade,
                          child: Column(
                            children: [
                              Text.rich(
                                const TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Kutlu Yolculuğunuza\n',
                                      style: TextStyle(
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x662D6A4F),
                                            blurRadius: 10,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Hoş Geldiniz',
                                      style: TextStyle(
                                        color: RehberTheme.goldLight,
                                        shadows: [
                                          Shadow(
                                            color: Color(0x66ECC46A),
                                            blurRadius: 10,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'NotoSans',
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'İbadetlerinizi adım adım,\nhuzur ve güvenle\ntamamlamanız için\nyanınızdayız. Lütfen\nbaşlamak istediğiniz rehberi\nseçin',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.45,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Hac Rehberim Button
                      SlideTransition(
                        position: _hacButtonSlide,
                        child: FadeTransition(
                          opacity: _hacButtonFade,
                          child: _SpringPillButton(
                            onTap: widget.onOpenHajj,
                            color: const Color(0xFF1B4332)
                                .withValues(alpha: 0.88),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.mosque_rounded,
                                      color: RehberTheme.goldLight,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Hac rehberim',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: RehberTheme.goldLight.withValues(
                                          alpha: 0.20,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: RehberTheme.goldLight
                                              .withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        'Rehbere Başla',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: RehberTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Umre Rehberim Button with Progress Ring
                      SlideTransition(
                        position: _umrahButtonSlide,
                        child: FadeTransition(
                          opacity: _umrahButtonFade,
                          child: _SpringPillButton(
                            onTap: widget.onOpenUmrah,
                            color: const Color(0xFF2D6A4F),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 24,
                                right: 8,
                              ),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Umre rehberim',
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  CustomPaint(
                                    painter: _ProgressRingPainter(
                                      progress:
                                          (targetProgress / 100.0) *
                                          _progressSweep.value,
                                      ringColor: RehberTheme.goldLight,
                                      trackColor: RehberTheme.goldLight
                                          .withValues(alpha: 0.25),
                                      strokeWidth: 3.5,
                                    ),
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF143B2C),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: RehberTheme.goldLight
                                              .withValues(alpha: 0.45),
                                          width: 1.0,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '${(targetProgress * _progressSweep.value).round()}%',
                                        style: const TextStyle(
                                          color: RehberTheme.goldLight,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpringPillButton extends StatefulWidget {
  const _SpringPillButton({
    required this.onTap,
    required this.child,
    required this.color,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  State<_SpringPillButton> createState() => _SpringPillButtonState();
}

class _SpringPillButtonState extends State<_SpringPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.12 : 0.22),
                blurRadius: _pressed ? 3 : 7,
                offset: Offset(0, _pressed ? 1.5 : 3.5),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    this.strokeWidth = 3.5,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
