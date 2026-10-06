import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_controls.dart';
import 'counter_screen.dart';
import 'guide_catalog.dart';
import 'narration_service.dart';
import 'progress_store.dart';

class GuideFlowScreen extends StatefulWidget {
  const GuideFlowScreen({
    super.key,
    required this.store,
    required this.catalog,
    required this.narration,
    required this.mode,
    required this.profile,
    this.existingSession,
  });

  final ProgressStore store;
  final GuideCatalog catalog;
  final NarrationService narration;
  final GuideMode mode;
  final HajjProfile? profile;
  final GuideSession? existingSession;

  @override
  State<GuideFlowScreen> createState() => _GuideFlowScreenState();
}

class _GuideFlowScreenState extends State<GuideFlowScreen> {
  GuideSession? _session;
  Set<String> _markedIds = {};
  String? _error;

  List<GuideStep> get _flowSteps => widget.catalog.stepsForProfile(
    widget.catalog.type == GuideType.hajj ? widget.profile : null,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final known = _session ?? widget.existingSession;
      final session = known == null
          ? await widget.store.openOrCreateSession(
              type: widget.catalog.type,
              mode: widget.mode,
              profile: widget.profile,
              firstStepId: _flowSteps.first.id,
              contentVersion: widget.catalog.contentVersion,
            )
          : await widget.store.readSession(known.id);
      if (session == null) throw StateError('Kayıt bulunamadı.');
      final marked = await widget.store.readMarkedStepIds(session.id);
      final validIds = _flowSteps.map((s) => s.id).toSet();
      if (mounted) {
        setState(() {
          _session = session;
          _markedIds = marked.intersection(validIds);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Kayıt açılmadı. Tekrar dene.');
    }
  }

  Future<void> _openStep(GuideStep step) async {
    final session = _session;
    if (session == null) return;
    try {
      GuideStep? selected = step;
      while (selected != null && mounted) {
        final current = selected;
        await widget.narration.stop();
        await widget.store.saveCurrentStep(session.id, current.id);
        final marked = await widget.store.readMarkedStepIds(session.id);
        if (!mounted) return;
        setState(() => _session = session.copyWith(currentStepId: current.id));
        selected = await Navigator.of(context).push<GuideStep>(
          MaterialPageRoute(
            builder: (_) => GuideStepScreen(
              store: widget.store,
              catalog: widget.catalog,
              narration: widget.narration,
              session: session.copyWith(currentStepId: current.id),
              step: current,
              initiallyMarked: marked.contains(current.id),
            ),
          ),
        );
      }
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Başlık açılamadı. Tekrar dene.')),
        );
      }
    }
  }

  Future<void> _newJourney() async {
    try {
      final session = await widget.store.startNewJourney(
        type: widget.catalog.type,
        profile: widget.profile,
        firstStepId: _flowSteps.first.id,
        contentVersion: widget.catalog.contentVersion,
      );
      if (mounted) {
        setState(() {
          _session = session;
          _markedIds = {};
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Yeni kayıt açılamadı.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final flowSteps = _flowSteps;
    final current = session == null
        ? null
        : flowSteps
              .where((step) => step.id == session.currentStepId)
              .firstOrNull;
    final isHajj = widget.catalog.type == GuideType.hajj;
    final profileVerified =
        isHajj && widget.catalog.isProfileFlowVerified(widget.profile!);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.catalog.type.label} · ${widget.mode.label}${widget.profile == null ? '' : ' / ${widget.profile!.label}'}',
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!))
            : session == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        isHajj && !profileVerified
                            ? 'Hac türlerinin hangi başlıklardan geçeceği henüz onaylanmadı. Bu liste 35 başlığın önizlemesidir; kişisel işaretleme kapalıdır.'
                            : isHajj
                            ? '${widget.profile!.label} için onaylı profil akışı gösteriliyor. İşaretler yalnız kişisel kayıttır.'
                            : 'Bu başlıklar içerik taslağıdır. Kaynaklı açıklama ve insan sesi inceleme sonrası açılacak. İşaretler yalnız kişisel kayıttır.',
                      ),
                    ),
                  ),
                  if (current == null) ...[
                    const SizedBox(height: 12),
                    const Card.outlined(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Önceki kayıtlı başlık bu içerik sürümünde bulunamadı. Aşağıdaki listeden bir başlık seçerek devam edebilirsin; eski kayıt kendiliğinden silinmez.',
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _openStep(current),
                      icon: const Icon(Icons.bookmark_rounded),
                      label: const Text('Kaldığım başlığa git'),
                    ),
                  ],
                  if (widget.mode == GuideMode.journey) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _newJourney,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Yeni yolculuk kaydı aç'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    isHajj
                        ? '${profileVerified ? 'Profil akışı' : 'Başlık envanteri'} · ${flowSteps.length}'
                        : 'Adımlar · ${_markedIds.length}/${flowSteps.length} işaretli',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  for (final group
                      in GuideCatalog
                          .expectedGroups[widget.catalog.type]!
                          .keys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                      child: Text(
                        group,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final step in flowSteps.where(
                      (s) => s.groupId == group,
                    ))
                      Card.outlined(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
                          leading: CircleAvatar(child: Text('${step.order}')),
                          title: Text(step.title),
                          subtitle: Text(
                            isHajj && !profileVerified
                                ? 'Profil uygunluğu doğrulanmadı'
                                : 'İçerik: ${step.status.label}',
                          ),
                          trailing: Icon(
                            !isHajj && _markedIds.contains(step.id)
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                          ),
                          onTap: () => _openStep(step),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class GuideStepScreen extends StatefulWidget {
  const GuideStepScreen({
    super.key,
    required this.store,
    required this.catalog,
    required this.narration,
    required this.session,
    required this.step,
    required this.initiallyMarked,
  });

  final ProgressStore store;
  final GuideCatalog catalog;
  final NarrationService narration;
  final GuideSession session;
  final GuideStep step;
  final bool initiallyMarked;

  @override
  State<GuideStepScreen> createState() => _GuideStepScreenState();
}

class _GuideStepScreenState extends State<GuideStepScreen> {
  late bool _marked = widget.initiallyMarked;
  bool _busy = false;

  @override
  void dispose() {
    unawaited(widget.narration.stop());
    super.dispose();
  }

  Future<void> _toggleMarked() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.setStepMarked(
        widget.session.id,
        widget.step.id,
        !_marked,
      );
      if (mounted) setState(() => _marked = !_marked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('İşaret kaydedilemedi.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(GuideStep step) async {
    await widget.narration.stop();
    if (mounted) Navigator.of(context).pop(step);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final previous = widget.catalog.previousStep(
      step,
      profile: widget.session.profile,
    );
    final next = widget.catalog.nextStep(step, profile: widget.session.profile);
    final isHajj = widget.catalog.type == GuideType.hajj;
    final canMark =
        !isHajj ||
        widget.catalog.isProfileFlowVerified(widget.session.profile!);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.catalog.type.label} · ${widget.session.mode.label}',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${step.groupId} · ${step.order} / ${widget.catalog.steps.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            Text(
              step.title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'İçerik durumu: ${step.status.label}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 18),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  step.isApproved
                      ? step.summary!
                      : isHajj
                      ? 'Bu başlık envanter önizlemesidir. ${widget.session.profile?.label} türündeki uygulanabilirliği ve açıklaması henüz doğrulanmadı.'
                      : 'Bu başlığın kaynaklı açıklaması ve dinî incelemesi henüz tamamlanmadı. Hazırlama kaydı onaylı içerik değildir.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            if (step.isApproved && step.details != null)
              ExpansionTile(
                title: const Text('Ayrıntı'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(step.details!),
                  ),
                ],
              ),
            if (step.isApproved && step.arabic != null) ...[
              const SizedBox(height: 20),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  step.arabic!,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 26, height: 1.6),
                ),
              ),
            ],
            if (step.isApproved && step.transliteration != null)
              Text(step.transliteration!),
            if (step.isApproved && step.meaningTr != null)
              Text(step.meaningTr!),
            if (step.isApproved && step.sourceTitle != null) ...[
              const SizedBox(height: 18),
              Text('Kaynak: ${step.sourceTitle} · ${step.sourceLocation}'),
              if (step.sourceUrl != null) SelectableText(step.sourceUrl!),
            ],
            for (final prayerId in step.prayerIds)
              _PrayerCard(
                prayer: widget.catalog.prayerRecords[prayerId]!,
                narration: widget.narration,
                audioRecords: widget.catalog.audioRecords,
                parentApproved: step.isApproved,
              ),
            const SizedBox(height: 20),
            if (step.linkedAudioIds.isEmpty)
              const Text('Bu başlık için onaylı ses kaydı henüz yok.'),
            for (final audioId in step.linkedAudioIds)
              _LinkedAudio(
                audio: widget.catalog.audioRecords[audioId]!,
                narration: widget.narration,
                textApproved: step.isApproved,
              ),
            if (step.counterKey != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => step.counterKey == 'jamarat'
                        ? JamaratCounterHubScreen(
                            store: widget.store,
                            sessionId: widget.session.id,
                          )
                        : CounterScreen(
                            store: widget.store,
                            sessionId: widget.session.id,
                            counterKey: step.counterKey!,
                          ),
                  ),
                ),
                icon: const Icon(Icons.plus_one_rounded),
                label: Text(
                  step.counterKey == 'jamarat'
                      ? 'Gün/hedef sayaçlarını aç'
                      : 'Manuel sayacı aç',
                ),
              ),
            ],
            if (canMark) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggleMarked,
                icon: Icon(
                  _marked
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                label: Text(
                  _marked
                      ? 'İşareti geri al'
                      : 'Kişisel ilerleme olarak işaretle',
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (previous != null)
              OutlinedButton.icon(
                onPressed: () => _select(previous),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Önceki başlık'),
              ),
            if (next != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _select(next),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Sonraki başlık'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  const _PrayerCard({
    required this.prayer,
    required this.narration,
    required this.audioRecords,
    required this.parentApproved,
  });

  final PrayerRecord prayer;
  final NarrationService narration;
  final Map<String, AudioRecord> audioRecords;
  final bool parentApproved;

  @override
  Widget build(BuildContext context) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Dua ${prayer.id}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text('İçerik durumu: ${prayer.status.label}'),
          const SizedBox(height: 12),
          if (!prayer.isApproved || !parentApproved)
            const Text(
              'Bu dua hazırlama kaydıdır; dinî incelemesi tamamlanmadı.',
            ),
          if (prayer.arabic == null &&
              prayer.transliteration == null &&
              prayer.meaningTr == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Arapça metin, okunuş ve Türkçe anlam henüz sağlanmadı.',
            ),
          ],
          if (prayer.arabic != null)
            Semantics(
              label: 'Arapça dua metni',
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  prayer.arabic!,
                  textAlign: TextAlign.start,
                  style: const TextStyle(fontSize: 26, height: 1.6),
                ),
              ),
            ),
          if (prayer.transliteration != null) Text(prayer.transliteration!),
          if (prayer.meaningTr != null) Text(prayer.meaningTr!),
          if (prayer.sourceTitle != null) ...[
            const SizedBox(height: 8),
            Text('Kaynak: ${prayer.sourceTitle} · ${prayer.sourceLocation}'),
            if (prayer.sourceUrl != null) SelectableText(prayer.sourceUrl!),
          ] else ...[
            const SizedBox(height: 8),
            const Text('Kaynak bilgisi henüz sağlanmadı.'),
          ],
          const SizedBox(height: 12),
          for (final audioId in prayer.linkedAudioIds)
            _LinkedAudio(
              audio: audioRecords[audioId]!,
              narration: narration,
              textApproved: parentApproved && prayer.isApproved,
            ),
        ],
      ),
    ),
  );
}

class _LinkedAudio extends StatelessWidget {
  const _LinkedAudio({
    required this.audio,
    required this.narration,
    required this.textApproved,
  });

  final AudioRecord audio;
  final NarrationService narration;
  final bool textApproved;

  @override
  Widget build(BuildContext context) {
    final playable =
        textApproved &&
        audio.status == ReviewStatus.approved &&
        audio.asset != null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: playable
          ? AudioControls(
              narration: narration,
              asset: audio.asset!,
              title: audio.kind.label,
            )
          : Semantics(
              label: '${audio.kind.label} ses durumu: ${audio.status.label}',
              child: Text(
                '${audio.kind.label}: ${audio.status.label}. '
                '${audio.asset == null ? 'Ses dosyası henüz sağlanmadı.' : 'Metin ve ses onayı tamamlanmadı.'}',
              ),
            ),
    );
  }
}
