import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'audio_controls.dart';
import 'content_repository.dart';
import 'guide_catalog.dart';
import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_screen.dart';
import 'progress_store.dart';
import 'support_links_screen.dart';

enum _PracticeView { entry, selection, packages, preparation, running, summary }

enum _ProductScenario { audioInterrupted, packageNotOffline, leftGroup }

/// A local educational rehearsal. It never writes guide progress or counters.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.store,
    required this.catalogs,
    this.bundledCatalogs,
    required this.narration,
    this.contentRepository,
    this.packages,
    this.packageProvider,
    this.packageConfigurationError,
  });

  final ProgressStore store;
  final Map<GuideType, GuideCatalog> catalogs;
  final Map<GuideType, GuideCatalog>? bundledCatalogs;
  final NarrationService narration;
  final LocalContentRepository? contentRepository;
  final OfflinePackageManager? packages;
  final OfflinePackageProvider? packageProvider;
  final String? packageConfigurationError;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  _PracticeView _view = _PracticeView.entry;
  GuideType _type = GuideType.umrah;
  HajjProfile _profile = HajjProfile.temettu;
  String? _sectionGroupId;
  bool _audioEnabled = false;
  bool _useOptionalPackage = false;
  bool _busy = false;
  String? _error;
  PracticeSession? _latest;
  PracticeSession? _session;
  Map<GuideType, GuideCatalog>? _catalogs;
  Set<String> _marked = {};
  int _counter = 0;
  final Random _random = Random.secure();

  Map<GuideType, GuideCatalog> get catalogs => _useOptionalPackage
      ? (_catalogs ?? widget.catalogs)
      : (widget.bundledCatalogs ?? widget.catalogs);
  GuideCatalog get catalog => catalogs[_session?.type ?? _type]!;
  List<GuideStep> get steps {
    final profile = (_session?.type ?? _type) == GuideType.hajj
        ? (_session?.profile ?? _profile)
        : null;
    final all = catalog.stepsForProfile(profile);
    final group = _session == null ? _sectionGroupId : _session!.sectionGroupId;
    return group == null
        ? all
        : all.where((step) => step.groupId == group).toList();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLatest());
  }

  @override
  void dispose() {
    final narration = widget.narration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(narration.stop());
    });
    super.dispose();
  }

  Future<void> _loadLatest() async {
    try {
      final latest = await widget.store.readLatestPracticeSession();
      if (mounted) setState(() => _latest = latest);
    } catch (_) {
      if (mounted) setState(() => _error = 'Prova kaydı okunamadı.');
    }
  }

  Future<void> _newPractice() => _run(() async {
    await widget.narration.stop();
    if (mounted) {
      setState(() {
        _session = null;
        _sectionGroupId = null;
        _view = _PracticeView.selection;
      });
    }
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _error = 'İşlem tamamlanamadı. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() => _run(() async {
    final latest = _latest;
    if (latest == null) return;
    final restored = await widget.store.readPracticeSession(latest.id);
    if (restored == null) throw StateError('Prova bulunamadı.');
    final marked = await widget.store.readPracticeMarkedStepIds(restored.id);
    final counter = await widget.store.readPracticeCounter(
      restored.id,
      restored.currentStepId,
    );
    if (!mounted) return;
    setState(() {
      _session = restored;
      _useOptionalPackage = restored.useOptionalPackage;
      _marked = marked;
      _counter = counter;
      _view = restored.phase == PracticePhase.finished
          ? _PracticeView.summary
          : restored.phase == PracticePhase.preparation
          ? _PracticeView.preparation
          : _PracticeView.running;
    });
  });

  Future<void> _openPackages() async {
    final manager = widget.packages;
    if (manager == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OfflinePackagesScreen(
          manager: manager,
          provider: widget.packageProvider,
          configurationError: widget.packageConfigurationError,
        ),
      ),
    );
    if (!mounted || widget.contentRepository == null) return;
    await _run(() async {
      final refreshed = await widget.contentRepository!.load();
      if (mounted) setState(() => _catalogs = refreshed);
    });
  }

  Future<void> _showProductScenario(_ProductScenario scenario) async {
    final (title, description, recovery) = switch (scenario) {
      _ProductScenario.audioInterrupted => (
        'Ses kesildi',
        'Ses durduğunda cihazın ses düzeyini ve kulaklık bağlantısını kontrol et. '
            'Rehber veya prova ekranındaki ses düğmesinden yeniden başlatmayı dene.',
        'Ses geri gelmezse metin ve başlıklarla devam edebilirsin. Ses, prova işaretlerini değiştirmez.',
      ),
      _ProductScenario.packageNotOffline => (
        'Paket çevrimdışı değil',
        'İsteğe bağlı paketin indirilip etkinleştiğini paket yöneticisinde kontrol et. '
            'İndirme için bağlantı gerekebilir; temel rehber indirme olmadan açılır.',
        'Paket hazır görünmüyorsa temel içerikle devam et. Harita veya ses paketini çevrimdışı hazır sayma.',
      ),
      _ProductScenario.leftGroup => (
        'Kafileden ayrıldım',
        'Kafile sekmesinde üyeliğini kontrol et. Ayrıldıysan eski sohbet, duyuru ve konum paylaşımına erişimin sürüyormuş gibi davranma.',
        'Yeniden katılmak için kafile yetkilisinden yeni davet iste. Bu kart üyeliği veya konum paylaşımını değiştirmez.',
      ),
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(description),
              const SizedBox(height: 12),
              Text(recovery),
              const SizedBox(height: 20),
              if (scenario == _ProductScenario.packageNotOffline &&
                  widget.packages != null)
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    if (mounted) await _openPackages();
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Paketleri yönet'),
                ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  if (!mounted) return;
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const SupportLinksScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('Destek bağlantılarını gör'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Provaya dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start() => _run(() async {
    final selected = steps;
    if (selected.isEmpty) throw StateError('Prova adımı bulunamadı.');
    final session = await widget.store.startPracticeSession(
      type: _type,
      profile: _type == GuideType.hajj ? _profile : null,
      contentVersion: catalog.contentVersion,
      firstStepId: selected.first.id,
      sectionGroupId: _sectionGroupId,
      audioEnabled: _audioEnabled,
      useOptionalPackage: _useOptionalPackage,
    );
    if (!mounted) return;
    setState(() {
      _session = session;
      _latest = session;
      _marked = {};
      _counter = 0;
      _view = _PracticeView.preparation;
    });
  });

  Future<void> _setPhase(PracticePhase phase) => _run(() async {
    final current = _session!;
    if (phase != PracticePhase.practicing) await widget.narration.stop();
    final updated = await widget.store.updatePracticeSession(
      current.id,
      phase: phase,
    );
    if (mounted) {
      setState(() {
        _session = updated;
        _latest = updated;
        _view = phase == PracticePhase.finished
            ? _PracticeView.summary
            : _PracticeView.running;
      });
    }
  });

  Future<void> _goTo(int index) => _run(() async {
    final current = _session!;
    final selected = steps;
    if (index < 0 || index >= selected.length) return;
    await widget.narration.stop();
    final next = await widget.store.updatePracticeSession(
      current.id,
      currentStepId: selected[index].id,
    );
    final count = await widget.store.readPracticeCounter(
      next.id,
      next.currentStepId,
    );
    if (mounted) {
      setState(() {
        _session = next;
        _latest = next;
        _counter = count;
      });
    }
  });

  Future<void> _showStepOrder(
    List<GuideStep> selected,
    int currentIndex,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            children: [
              const ListTile(
                title: Text('Prova adımları'),
                subtitle: Text(
                  'Bir başlığa geçmek prova işaretlerini değiştirmez.',
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: selected.length,
                  itemBuilder: (context, index) {
                    final step = selected[index];
                    return ListTile(
                      key: ValueKey('practice-step-${step.id}'),
                      selected: index == currentIndex,
                      leading: Text('${index + 1}'),
                      title: Text(step.title),
                      subtitle: Text(
                        _marked.contains(step.id)
                            ? 'Prova edildi · ${step.groupId}'
                            : 'Henüz işaretlenmedi · ${step.groupId}',
                      ),
                      trailing: index == currentIndex
                          ? const Icon(Icons.place_rounded)
                          : null,
                      onTap: _busy
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              unawaited(_goTo(index));
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _recoverChangedCatalog() => _run(() async {
    final current = _session!;
    final available = catalog.stepsForProfile(current.profile);
    final groupStillExists = available.any(
      (step) => step.groupId == current.sectionGroupId,
    );
    final selected = groupStillExists
        ? available
              .where((step) => step.groupId == current.sectionGroupId)
              .toList()
        : available;
    if (selected.isEmpty) throw StateError('Prova adımı bulunamadı.');
    await widget.narration.stop();
    final updated = await widget.store.startPracticeSession(
      type: current.type,
      profile: current.profile,
      contentVersion: catalog.contentVersion,
      firstStepId: selected.first.id,
      sectionGroupId: groupStillExists ? current.sectionGroupId : null,
      audioEnabled: current.audioEnabled,
      useOptionalPackage: current.useOptionalPackage,
    );
    if (mounted) {
      setState(() {
        _session = updated;
        _latest = updated;
        _marked = {};
        _counter = 0;
        _view = _PracticeView.preparation;
      });
    }
  });

  Future<void> _reviewFromStart() {
    if (_session!.contentVersion != catalog.contentVersion || steps.isEmpty) {
      return _recoverChangedCatalog();
    }
    return _run(() async {
      final current = _session!;
      final selected = steps;
      if (selected.isEmpty) return;
      await widget.narration.stop();
      final updated = await widget.store.updatePracticeSession(
        current.id,
        currentStepId: selected.first.id,
        phase: PracticePhase.practicing,
      );
      final count = await widget.store.readPracticeCounter(
        updated.id,
        selected.first.id,
      );
      if (mounted) {
        setState(() {
          _session = updated;
          _latest = updated;
          _counter = count;
          _view = _PracticeView.running;
        });
      }
    });
  }

  Future<void> _mark(GuideStep step, bool value) => _run(() async {
    await widget.store.setPracticeStepMarked(_session!.id, step.id, value);
    if (mounted) {
      setState(() {
        if (value) {
          _marked.add(step.id);
        } else {
          _marked.remove(step.id);
        }
      });
    }
  });

  Future<void> _countAction(GuideStep step, String action) => _run(() async {
    final target = step.counterTarget;
    if (!step.isApproved || target == null) return;
    final next = await widget.store.applyPracticeCounter(
      sessionId: _session!.id,
      stepId: step.id,
      actionToken:
          '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}',
      action: action,
      target: target,
    );
    if (mounted) setState(() => _counter = next);
  });

  Future<void> _confirmReset(GuideStep step) async {
    if (_busy || _counter == 0) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prova sayacını sıfırla?'),
        content: const Text('Yalnız bu prova kaydındaki sayı sıfırlanır.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _countAction(step, 'reset');
  }

  Future<void> _setAudio(bool value) => _run(() async {
    if (!value) await widget.narration.stop();
    final current = _session;
    if (current == null) {
      if (mounted) setState(() => _audioEnabled = value);
      return;
    }
    final updated = await widget.store.updatePracticeSession(
      current.id,
      audioEnabled: value,
    );
    if (mounted) {
      setState(() {
        _session = updated;
        _latest = updated;
      });
    }
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (_view) {
      _PracticeView.entry => 'Simülasyon',
      _PracticeView.selection => 'Prova seçimi',
      _PracticeView.packages => 'Paket seçimi',
      _PracticeView.preparation => 'Hazırlık',
      _PracticeView.running => 'Prova',
      _PracticeView.summary => 'Prova özeti',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _view == _PracticeView.entry || _view == _PracticeView.preparation
                  ? 'Bu eğitim amaçlı bir provadır; gerçek ibadetin yerine geçmez. '
                        'İçerik uzman incelemesindeyse yalnız başlıklar gösterilir.'
                  : 'Eğitim provası · gerçek ibadetin yerine geçmez.',
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            switch (_view) {
              _PracticeView.entry => _entry(),
              _PracticeView.selection => _selection(),
              _PracticeView.packages => _packages(),
              _PracticeView.preparation => _preparation(),
              _PracticeView.running => _running(),
              _PracticeView.summary => _summary(),
            },
          ],
        ),
      ),
    );
  }

  Widget _entry() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton.icon(
        onPressed: _busy ? null : _newPractice,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Yeni prova'),
      ),
      if (_latest != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _resume,
          icon: const Icon(Icons.bookmark_outline_rounded),
          label: Text(
            _latest!.phase == PracticePhase.finished
                ? 'Son prova özetini aç'
                : 'Kaldığım provadan devam et',
          ),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        'Uygulama durumları',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const Text(
        'Bu kısa kartlar uygulamayı kullanmayı prova ettirir; kayıtlarını değiştirmez.',
      ),
      for (final (scenario, title, subtitle, icon) in [
        (
          _ProductScenario.audioInterrupted,
          'Ses kesildi',
          'Sesi yeniden başlatma ve metinle devam etme',
          Icons.volume_off_outlined,
        ),
        (
          _ProductScenario.packageNotOffline,
          'Paket çevrimdışı değil',
          'Paket durumunu kontrol etme ve temel içeriğe dönme',
          Icons.download_outlined,
        ),
        (
          _ProductScenario.leftGroup,
          'Kafileden ayrıldım',
          'Üyeliği kontrol etme ve yeniden davet isteme',
          Icons.group_off_outlined,
        ),
      ])
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: _busy ? null : () => _showProductScenario(scenario),
        ),
    ],
  );

  Widget _selection() {
    final groups = <String, String>{};
    final selectedCatalog = catalogs[_type]!;
    for (final step in selectedCatalog.stepsForProfile(
      _type == GuideType.hajj ? _profile : null,
    )) {
      groups.putIfAbsent(step.groupId, () => step.title);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<GuideType>(
          segments: const [
            ButtonSegment(value: GuideType.umrah, label: Text('Umre')),
            ButtonSegment(value: GuideType.hajj, label: Text('Hac')),
          ],
          selected: {_type},
          onSelectionChanged: (value) => setState(() {
            _type = value.single;
            _sectionGroupId = null;
          }),
        ),
        if (_type == GuideType.hajj) ...[
          const SizedBox(height: 16),
          DropdownButtonFormField<HajjProfile>(
            initialValue: _profile,
            decoration: const InputDecoration(labelText: 'Hac türü'),
            items: [
              for (final value in HajjProfile.values)
                DropdownMenuItem(value: value, child: Text(value.label)),
            ],
            onChanged: (value) => setState(() {
              _profile = value ?? _profile;
              _sectionGroupId = null;
            }),
          ),
          if (!selectedCatalog.isProfileFlowVerified(_profile))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bu Hac türünün adım kuralları henüz doğrulanmadı; yalnız envanter başlıkları açılır.',
              ),
            ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('${_type.name}-${_profile.name}'),
          initialValue: _sectionGroupId ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Çalışma kapsamı'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Baştan sona')),
            for (final entry in groups.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  '${entry.key} · ${entry.value}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(
            () =>
                _sectionGroupId = value == null || value.isEmpty ? null : value,
          ),
        ),
        if (selectedCatalog
            .stepsForProfile(_type == GuideType.hajj ? _profile : null)
            .any((step) => !step.isApproved))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Bu akışta uzman incelemesi bekleyen başlıklar var. Taslak açıklamalar onaylı anlatım olarak gösterilmez.',
            ),
          ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          title: const Text('Sesli kullanım'),
          subtitle: const Text(
            'Erişilebilir sentetik taslak kayıtlar ayrıca işaretlenir.',
          ),
          value: _audioEnabled,
          onChanged: _busy ? null : _setAudio,
        ),
        const ListTile(
          title: Text('Ortam sesi'),
          subtitle: Text('İzinli ortam sesi paketi henüz sağlanmadı.'),
          leading: Icon(Icons.volume_off_outlined),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy
              ? null
              : () => setState(() => _view = _PracticeView.packages),
          child: const Text('Paket seçimine geç'),
        ),
      ],
    );
  }

  Widget _packages() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ListTile(
        leading: Icon(Icons.menu_book_outlined),
        title: Text('Temel metin ve şemalar'),
        subtitle: Text(
          'İndirme gerekmez. Taslak metinler onaylı anlatım gibi gösterilmez.',
        ),
      ),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Temel içerik')),
          ButtonSegment(value: true, label: Text('Etkin paket')),
        ],
        selected: {_useOptionalPackage},
        onSelectionChanged: widget.packages == null
            ? null
            : (value) => setState(() => _useOptionalPackage = value.single),
      ),
      const SizedBox(height: 8),
      Text(
        _useOptionalPackage
            ? 'Paket yöneticisindeki etkin ve doğrulanmış içerik kullanılır; geçersiz pakette temel içerik açılır.'
            : 'Temel içerik seçildi. Büyük ses ve medya paketleri indirilmez.',
      ),
      if (widget.packages != null)
        OutlinedButton.icon(
          onPressed: _busy ? null : _openPackages,
          icon: const Icon(Icons.download_outlined),
          label: const Text('İsteğe bağlı paketleri yönet'),
        ),
      if (widget.packageProvider == null)
        const Text(
          'İndirme hizmeti henüz yapılandırılmadı. Temel prova yine açılır.',
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _start,
        child: const Text('Hazırlığa geç'),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() => _view = _PracticeView.selection),
        child: const Text('Seçime dön'),
      ),
    ],
  );

  Widget _preparation() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${_session!.type.label}${_session!.profile == null ? '' : ' · ${_session!.profile!.label}'}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        '${steps.length} başlık · ${_session!.sectionGroupId ?? 'tüm akış'}',
      ),
      const SizedBox(height: 8),
      const Text(
        'İlerleme ve sayaçlar gerçek rehber kayıtlarından ayrıdır. Adımları yalnız sen işaretlersin.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : () => _setPhase(PracticePhase.practicing),
        child: const Text('Provaya başla'),
      ),
    ],
  );

  Widget _running() {
    final session = _session!;
    final selected = steps;
    final index = selected.indexWhere(
      (step) => step.id == session.currentStepId,
    );
    if (index < 0 || session.contentVersion != catalog.contentVersion) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Kayıtlı adım veya içerik sürümü değişmiş. Eski prova kaydı korunuyor.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _recoverChangedCatalog,
            child: const Text('Yeni katalogla prova aç'),
          ),
        ],
      );
    }
    final step = selected[index];
    if (session.phase == PracticePhase.paused) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Prova duraklatıldı · ${step.title}'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _setPhase(PracticePhase.practicing),
            child: const Text('Devam et'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${index + 1} / ${selected.length} · ${step.groupId}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        LinearProgressIndicator(value: (index + 1) / selected.length),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : () => _showStepOrder(selected, index),
            icon: const Icon(Icons.list_alt_rounded),
            label: Text('Adım sırasını gör (${_marked.length} işaretli)'),
          ),
        ),
        const SizedBox(height: 18),
        Text(step.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        _PracticeDiagram(kind: step.counterKey),
        const SizedBox(height: 16),
        Text(
          'Şimdi ne yapacağım?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          step.isApproved && step.summary != null ? step.summary! : 'Bu başlığın açıklaması uzman incelemesinde. Şimdilik yalnız çalışma sırasını prova edebilirsin.',
        ),
        if (step.isApproved && step.details != null)
          ExpansionTile(
            title: const Text('Ayrıntı ve dikkat edilecekler'),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(step.details!),
              ),
            ],
          ),
        if (step.prayerIds.isNotEmpty)
          ExpansionTile(
            title: const Text('Dua'),
            children: [
              for (final id in step.prayerIds)
                _prayer(catalog.prayerRecords[id]!, step.isApproved),
            ],
          ),
        ExpansionTile(
          title: const Text('Kaynak ve onay durumu'),
          children: [
            ListTile(
              title: Text(step.status.label),
              subtitle: Text(
                step.isApproved && step.sourceTitle != null
                    ? '${step.sourceTitle} · ${step.sourceLocation ?? ''}'
                    : 'Kaynak ve uzman onayı henüz tamamlanmadı.',
              ),
            ),
          ],
        ),
        _audio(step, session),
        if (step.counterKey != null) _counterControls(step),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Bu başlığı prova ettim'),
          subtitle: const Text(
            'Gerçek ibadet tamamlanması olarak kaydedilmez.',
          ),
          value: _marked.contains(step.id),
          onChanged: _busy ? null : (value) => _mark(step, value ?? false),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy || index == 0 ? null : () => _goTo(index - 1),
                child: const Text('Önceki'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : index == selected.length - 1
                    ? () => _setPhase(PracticePhase.finished)
                    : () => _goTo(index + 1),
                child: Text(
                  index == selected.length - 1 ? 'Özete geç' : 'Sonraki',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _busy ? null : () => _setPhase(PracticePhase.paused),
          icon: const Icon(Icons.pause_rounded),
          label: const Text('Provayı duraklat'),
        ),
      ],
    );
  }

  Widget _prayer(PrayerRecord prayer, bool parentApproved) {
    if (!parentApproved || !prayer.isApproved) {
      return const ListTile(title: Text('Dua metni uzman incelemesinde.'));
    }
    return Column(
      children: [
        if (prayer.arabic != null)
          Directionality(
            textDirection: TextDirection.rtl,
            child: ListTile(
              title: Text(prayer.arabic!, textAlign: TextAlign.right),
            ),
          ),
        if (prayer.transliteration != null)
          ListTile(title: Text(prayer.transliteration!)),
        if (prayer.meaningTr != null) ListTile(title: Text(prayer.meaningTr!)),
      ],
    );
  }

  Widget _audio(GuideStep step, PracticeSession session) {
    final records = step.linkedAudioIds
        .map((id) => catalog.audioRecords[id])
        .whereType<AudioRecord>()
        .where(
          (record) =>
              record.isSyntheticDraftPreview ||
              (step.isApproved &&
                  record.status == ReviewStatus.approved &&
                  record.asset != null),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile.adaptive(
          title: const Text('Sesli kullanım'),
          value: session.audioEnabled,
          onChanged: _busy ? null : _setAudio,
        ),
        if (!session.audioEnabled)
          const Text('Sessiz prova seçildi.')
        else if (records.isEmpty)
          const Text('Bu başlık için onaylı ses henüz yok.')
        else
          for (final record in records) ...[
            if (record.isSyntheticDraftPreview)
              const Text(
                'Sentetik taslak kayıt. Dinî, dil ve kullanım hakkı incelemesi tamamlanmadı.',
              ),
            AudioControls(
              narration: widget.narration,
              asset: record.asset!,
              title: record.isSyntheticDraftPreview
                  ? '${record.kind.label} · sentetik taslak'
                  : record.kind.label,
            ),
          ],
        const Text(
          'Ortam sesi: izinli paket henüz yok; varsayılan olarak kapalı.',
        ),
      ],
    );
  }

  Widget _counterControls(GuideStep step) {
    final target = step.counterTarget;
    if (!step.isApproved || target == null) {
      return const ListTile(
        leading: Icon(Icons.lock_outline_rounded),
        title: Text('Manuel prova sayacı bekliyor'),
        subtitle: Text(
          'Sayı ve sıra kuralı onaylı içerikte belirtilince açılır.',
        ),
      );
    }
    return Column(
      children: [
        Text(
          'Prova sayacı: $_counter / $target',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(
              onPressed: _busy || _counter >= target
                  ? null
                  : () => _countAction(step, 'increment'),
              child: const Text('+1 ekle'),
            ),
            OutlinedButton(
              onPressed: _busy || _counter == 0
                  ? null
                  : () => _countAction(step, 'undo'),
              child: const Text('Geri al'),
            ),
            TextButton(
              onPressed: _busy || _counter == 0
                  ? null
                  : () => _confirmReset(step),
              child: const Text('Sıfırla'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '${_session!.type.label} prova özeti',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      if (_session!.contentVersion == catalog.contentVersion &&
          steps.isNotEmpty)
        Text(
          '${_marked.intersection(steps.map((step) => step.id).toSet()).length} / ${steps.length} başlık prova edildi.',
        ),
      if (_session!.contentVersion == catalog.contentVersion &&
          steps.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          'Prova edilen başlıklar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (!steps.any((step) => _marked.contains(step.id)))
          const Text('Henüz bir başlık işaretlenmedi.'),
        for (final step in steps.where((step) => _marked.contains(step.id)))
          ListTile(
            title: Text(step.title),
            subtitle: Text('${step.groupId} · ${step.status.label}'),
          ),
      ],
      const Text(
        'Bu sonuç gerçek ibadetin yapıldığını veya geçerliliğini göstermez.',
      ),
      if (_session!.contentVersion != catalog.contentVersion || steps.isEmpty)
        const Text(
          'İçerik değişmiş. Eski prova kaydı korunuyor; yeni başlıklarla sayısal karşılaştırma yapılmaz. Yeniden çalışmak için yeni kayıt açılır.',
        ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: _busy ? null : _reviewFromStart,
        child: const Text('Baştan tekrar gözden geçir'),
      ),
      FilledButton(
        onPressed: _busy ? null : _newPractice,
        child: const Text('Yeni prova'),
      ),
    ],
  );
}

class _PracticeDiagram extends StatelessWidget {
  const _PracticeDiagram({required this.kind});
  final String? kind;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      'tawaf' => 'Tavaf için soyut yön şeması; gerçek mekân haritası değildir.',
      'say' =>
        'Safa ve Merve arasında soyut yön şeması; gerçek mesafe göstermez.',
      'jamarat' =>
        'Cemarat için soyut hedef şeması; gerçek saha veya sıra göstermez.',
      _ => 'Bu aşama için görsel şema bulunmuyor.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Container(
            height: 132,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: switch (kind) {
                'tawaf' => const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rotate_left_rounded, size: 45),
                    SizedBox(width: 16),
                    Icon(Icons.crop_square_rounded, size: 60),
                    SizedBox(width: 8),
                    Icon(Icons.flag_outlined),
                  ],
                ),
                'say' => const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Safa'),
                    SizedBox(width: 12),
                    Icon(Icons.swap_horiz_rounded, size: 55),
                    SizedBox(width: 12),
                    Text('Merve'),
                  ],
                ),
                'jamarat' => const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_forward_rounded, size: 42),
                    SizedBox(width: 16),
                    Icon(Icons.adjust_rounded, size: 58),
                  ],
                ),
                _ => const Icon(Icons.menu_book_outlined, size: 54),
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }
}
