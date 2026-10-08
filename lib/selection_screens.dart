import 'package:flutter/material.dart';

import 'content_repository.dart';
import 'guide_catalog.dart';
import 'group_repository.dart';
import 'group_screen.dart';
import 'guide_screens.dart';
import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_screen.dart';
import 'practice_screen.dart';
import 'push_service.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'safety_catalog.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';
import 'travel_screen.dart';

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

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GroupRepository _fallbackGroups = UnconfiguredGroupRepository();
  GroupRepository get _groups => widget.groups ?? _fallbackGroups;
  late Map<GuideType, GuideCatalog> _catalogs;
  TravelCatalog? _travelCatalog;
  int _refreshEpoch = 0;
  GuideSession? _latest;
  String? _error;

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
          _latest = session;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && epoch == _refreshEpoch) {
        setState(() => _error = 'Kayıtlar okunamadı.');
      }
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh(reloadContent: screen is OfflinePackagesScreen);
  }

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

  void _openUmrah(GuideMode mode) {
    _open(
      GuideFlowScreen(
        store: widget.store,
        catalog: _catalogs[GuideType.umrah]!,
        narration: widget.narration,
        mode: mode,
        profile: null,
      ),
    );
  }

  void _resume(GuideSession session) {
    final catalog = _catalogs[session.type];
    if (catalog == null) return;
    _open(
      GuideFlowScreen(
        store: widget.store,
        catalog: catalog,
        narration: widget.narration,
        mode: session.mode,
        profile: session.profile,
        existingSession: session,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latest;
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            _open(
              TravelScreen(
                store: widget.store,
                catalog:
                    _travelCatalog ??
                    const TravelCatalog(
                      dataVersion: 'not-configured',
                      points: [],
                      routes: [],
                    ),
              ),
            );
          }
          if (index == 2) {
            _open(
              GroupScreen(
                repository: _groups,
                store: widget.store,
                push: widget.push,
              ),
            );
          }
          if (index == 3) _open(SettingsScreen(settings: widget.settings));
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Rehber',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Yolculuk',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: 'Kafile',
          ),
          NavigationDestination(icon: Icon(Icons.tune), label: 'Ayarlar'),
        ],
      ),
      appBar: AppBar(
        title: const Text('Hac ve Umre Sesli Rehber'),
        actions: [
          IconButton(
            tooltip: 'Yazı ve ses ayarları',
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => _open(SettingsScreen(settings: widget.settings)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Nasıl devam etmek istersin?',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hazırlık ve yolculuk kayıtların ayrı tutulur. İstediğin zaman diğer rehberlere geçebilirsin.',
            ),
            if (_catalogs[GuideType.umrah]!.isPreview) ...[
              const SizedBox(height: 16),
              const Card.filled(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Umre içeriği henüz incelemede. Yolculuk ekranı kişisel takip içindir; onaylı ibadet anlatımı ve insan sesi henüz yok.',
                  ),
                ),
              ),
            ],
            if (latest != null) ...[
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () => _resume(latest),
                icon: const Icon(Icons.bookmark_rounded),
                label: Text(
                  'Kaldığım yerden devam · ${latest.type.label}${latest.profile == null ? '' : ' / ${latest.profile!.label}'}',
                ),
              ),
            ],
            const SizedBox(height: 24),
            _ChoiceCard(
              icon: Icons.school_outlined,
              title: 'Umreye hazırlanıyorum',
              subtitle: 'Adımları öğren ve kendi hızında incele',
              onTap: () => _openUmrah(GuideMode.learning),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.route_outlined,
              title: 'Umredeyim',
              subtitle: _catalogs[GuideType.umrah]!.isPreview
                  ? 'Taslak başlıkları ve sayaçları kişisel olarak takip et'
                  : 'Yolculuk kaydını aç, adımları ve sayaçları takip et',
              onTap: () => _openUmrah(GuideMode.journey),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.play_circle_outline_rounded,
              title: 'Simülasyonu dene',
              subtitle:
                  'İsteğe bağlı eğitim provası · gerçek ibadetin yerine geçmez',
              onTap: () => _open(
                PracticeScreen(
                  store: widget.store,
                  catalogs: _catalogs,
                  bundledCatalogs: widget.bundledCatalogs,
                  narration: widget.narration,
                  contentRepository: widget.contentRepository,
                  packages: widget.packages,
                  packageProvider: widget.packageProvider,
                  packageConfigurationError: widget.packageConfigurationError,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Tüm rehberler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.menu_book_rounded,
              title: 'Umre',
              subtitle: _catalogs[GuideType.umrah]!.isPreview
                  ? '18 başlık · içerik incelemede'
                  : '18 başlık · içerik onaylı',
              onTap: () => _choose(GuideType.umrah),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.map_outlined,
              title: 'Hac',
              subtitle: _catalogs[GuideType.hajj]!.isPreview
                  ? '35 başlık · profil kuralları önizlemede'
                  : '35 başlık · içerik ve profiller onaylı',
              onTap: () => _choose(GuideType.hajj),
            ),
            const SizedBox(height: 32),
            if (_travelCatalog != null) ...[
              Text('Gezi', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _open(
                  TravelScreen(store: widget.store, catalog: _travelCatalog!),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Harita, yerler ve rotalar'),
              ),
              const SizedBox(height: 20),
            ],
            if (widget.safetyCatalog != null) ...[
              Text(
                'Yolculuk desteği',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () =>
                    _open(SafetyScreen(catalog: widget.safetyCatalog!)),
                icon: const Icon(Icons.health_and_safety_outlined),
                label: const Text('Güvenli gezi, iletişim ve dil'),
              ),
              const SizedBox(height: 20),
            ],
            if (widget.packages != null) ...[
              Text(
                'Çevrimdışı kullanım',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _open(
                  OfflinePackagesScreen(
                    manager: widget.packages!,
                    provider: widget.packageProvider,
                    configurationError: widget.packageConfigurationError,
                  ),
                ),
                icon: const Icon(Icons.offline_pin_outlined),
                label: const Text('Çevrimdışı paketleri yönet'),
              ),
              const SizedBox(height: 20),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
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
  Widget build(BuildContext context) => Card.outlined(
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
