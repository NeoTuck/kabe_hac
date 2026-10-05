import 'package:flutter/material.dart';

import 'demo_screen.dart';
import 'guide_catalog.dart';
import 'guide_screens.dart';
import 'narration_service.dart';
import 'progress_store.dart';
import 'reader_settings.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GuideSession? _latest;
  bool _demoVisited = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final session = await widget.store.readMostRecentSession();
      final lastDemo = await widget.store.readLastStepId();
      if (mounted) {
        setState(() {
          _latest = session;
          _demoVisited = lastDemo == DemoScreen.stepId;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Kayıtlar okunamadı.');
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _refresh();
  }

  void _choose(GuideType type) {
    _open(
      ModeSelectionScreen(
        type: type,
        store: widget.store,
        catalog: widget.catalogs[type]!,
        narration: widget.narration,
      ),
    );
  }

  void _resume(GuideSession session) {
    final catalog = widget.catalogs[session.type];
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
            const SizedBox(height: 12),
            Text(
              'Rehber',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Öğrenmek veya yolculukta kişisel ilerlemeni izlemek için bir bölüm seç.',
            ),
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
              icon: Icons.menu_book_rounded,
              title: 'Umre',
              subtitle: '18 başlık · içerik incelemede',
              onTap: () => _choose(GuideType.umrah),
            ),
            const SizedBox(height: 12),
            _ChoiceCard(
              icon: Icons.map_outlined,
              title: 'Hac',
              subtitle: '35 başlık · profil kuralları önizlemede',
              onTap: () => _choose(GuideType.hajj),
            ),
            const SizedBox(height: 32),
            Text(
              'Teknik deneme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _open(
                DemoScreen(store: widget.store, narration: widget.narration),
              ),
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(
                _demoVisited
                    ? 'Ses örneğine kaldığım yerden devam'
                    : 'Ses ve Arapça örnek kartını aç',
              ),
            ),
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
            Icon(icon, size: 34),
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
          const Text(
            'Profil kuralları henüz uzman onayından geçmedi. Seçim yalnız başlık envanterinin önizlemesini açar.',
          ),
          const SizedBox(height: 24),
          for (final profile in HajjProfile.values) ...[
            _ChoiceCard(
              icon: Icons.list_alt_rounded,
              title: profile.label,
              subtitle: 'Uygulanabilirlik doğrulanmadı',
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
