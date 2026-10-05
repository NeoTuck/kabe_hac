import 'package:flutter/material.dart';

import 'counter_screen.dart';
import 'guide_catalog.dart';
import 'progress_store.dart';

class UmrahFlowScreen extends StatefulWidget {
  const UmrahFlowScreen({
    super.key,
    required this.store,
    required this.catalog,
    required this.mode,
  });

  final ProgressStore store;
  final GuideCatalog catalog;
  final GuideMode mode;

  @override
  State<UmrahFlowScreen> createState() => _UmrahFlowScreenState();
}

class _UmrahFlowScreenState extends State<UmrahFlowScreen> {
  GuideSession? _session;
  Set<String> _markedIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = await widget.store.openOrCreateUmrahSession(
        mode: widget.mode,
        firstStepId: widget.catalog.steps.first.id,
        contentVersion: widget.catalog.contentVersion,
      );
      final markedIds = await widget.store.readMarkedStepIds(session.id);
      if (mounted) {
        setState(() {
          _session = session;
          _markedIds = markedIds;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Yerel ilerleme açılamadı.');
    }
  }

  Future<void> _openStep(GuideStep step) async {
    final session = _session;
    if (session == null) return;
    try {
      GuideStep? selected = step;
      while (selected != null && mounted) {
        final currentStep = selected;
        await widget.store.saveCurrentStep(session.id, currentStep.id);
        final markedIds = await widget.store.readMarkedStepIds(session.id);
        if (!mounted) return;
        setState(
          () => _session = session.copyWith(currentStepId: currentStep.id),
        );
        selected = await Navigator.of(context).push<GuideStep>(
          MaterialPageRoute(
            builder: (_) => UmrahStepScreen(
              store: widget.store,
              catalog: widget.catalog,
              session: session.copyWith(currentStepId: currentStep.id),
              step: currentStep,
              initiallyMarked: markedIds.contains(currentStep.id),
            ),
          ),
        );
      }
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Adım kaydedilemedi. Tekrar dene.')),
        );
      }
    }
  }

  Future<void> _startNewJourney() async {
    try {
      final session = await widget.store.startNewUmrahJourney(
        firstStepId: widget.catalog.steps.first.id,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yeni kayıt oluşturulamadı.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final current = session == null
        ? null
        : widget.catalog.stepById(session.currentStepId);
    return Scaffold(
      appBar: AppBar(title: Text('Umre · ${widget.mode.label}')),
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
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Bu 18 başlık plan envanteridir. Kaynaklı açıklamalar ve insan sesi inceleme sonrası eklenecek. İşaretler yalnız kişisel uygulama kaydıdır.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (current != null)
                    FilledButton.icon(
                      onPressed: () => _openStep(current),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Kaldığım başlığa git'),
                    ),
                  if (widget.mode == GuideMode.journey) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _startNewJourney,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Yeni yolculuk kaydı aç'),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Adımlar · ${_markedIds.length}/18 işaretli',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  for (final step in widget.catalog.steps)
                    Card.outlined(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 5,
                        ),
                        leading: CircleAvatar(child: Text('${step.order}')),
                        title: Text(step.title),
                        subtitle: Text('${step.group} · İçerik incelemede'),
                        trailing: Icon(
                          _markedIds.contains(step.id)
                              ? Icons.check_circle_rounded
                              : Icons.chevron_right_rounded,
                        ),
                        onTap: () => _openStep(step),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class UmrahStepScreen extends StatefulWidget {
  const UmrahStepScreen({
    super.key,
    required this.store,
    required this.catalog,
    required this.session,
    required this.step,
    required this.initiallyMarked,
  });

  final ProgressStore store;
  final GuideCatalog catalog;
  final GuideSession session;
  final GuideStep step;
  final bool initiallyMarked;

  @override
  State<UmrahStepScreen> createState() => _UmrahStepScreenState();
}

class _UmrahStepScreenState extends State<UmrahStepScreen> {
  late bool _marked = widget.initiallyMarked;
  bool _busy = false;

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

  void _goNext() {
    final next = widget.catalog.nextStep(widget.step);
    if (next == null || _busy) return;
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final next = widget.catalog.nextStep(step);
    return Scaffold(
      appBar: AppBar(title: Text('Umre · ${widget.session.mode.label}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              '${step.group} · ${step.order} / ${widget.catalog.steps.length}',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 14),
            Text(
              step.title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  step.isPublished ? step.summary! : 'Bu başlığın kaynaklı açıklaması ve dinî incelemesi henüz tamamlanmadı. Şu anda yalnızca içerik sırasını ve uygulama akışını deniyorsun.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (step.isPublished && step.fullText != null)
              ExpansionTile(
                title: const Text('Ayrıntı'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(step.fullText!),
                  ),
                ],
              ),
            if (step.isPublished && step.sourceReference != null)
              Text('Kaynak: ${step.sourceReference}'),
            if (!step.isPublished)
              const Text(
                'Ses kaydı, dua ve kaynaklı açıklama inceleme sonrası açılacak.',
              ),
            if (step.counterKey != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CounterScreen(
                      store: widget.store,
                      sessionId: widget.session.id,
                      counterKey: step.counterKey!,
                    ),
                  ),
                ),
                icon: const Icon(Icons.plus_one_rounded),
                label: const Text('Manuel sayacı aç'),
              ),
            ],
            const SizedBox(height: 26),
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
            const SizedBox(height: 10),
            if (next != null)
              FilledButton.icon(
                onPressed: _busy ? null : _goNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Sonraki başlığa geç'),
              )
            else
              const Text('Envanterin son başlığı.'),
          ],
        ),
      ),
    );
  }
}
