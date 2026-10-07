import 'dart:math';

import 'package:flutter/material.dart';

import 'progress_store.dart';

enum CounterAction { increment, undo, reset }

class CounterScreen extends StatefulWidget {
  const CounterScreen({
    super.key,
    required this.store,
    required this.sessionId,
    required this.counterKey,
    this.title,
    this.contextLabel,
  });

  final ProgressStore store;
  final int sessionId;
  final String counterKey;
  final String? title;
  final String? contextLabel;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int? _count;
  bool _busy = false;
  String? _error;
  final Random _random = Random.secure();

  String get _title =>
      widget.title ??
      switch (widget.counterKey) {
        'tawaf' => 'Tavaf sayacı',
        'say' => 'Sa‘y sayacı',
        _ => 'Cemarat sayacı',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final count = await widget.store.readCounterCount(
        widget.sessionId,
        widget.counterKey,
      );
      if (mounted) {
        setState(() {
          _count = count;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Sayaç okunamadı.');
    }
  }

  String _actionToken() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';

  Future<void> _apply(CounterAction action) async {
    if (_busy || _count == null) return;
    setState(() => _busy = true);
    try {
      final token = _actionToken();
      final next = switch (action) {
        CounterAction.increment => await widget.store.incrementCounter(
          widget.sessionId,
          widget.counterKey,
          token,
        ),
        CounterAction.undo => await widget.store.undoCounter(
          widget.sessionId,
          widget.counterKey,
          token,
        ),
        CounterAction.reset => await widget.store.resetCounter(
          widget.sessionId,
          widget.counterKey,
          token,
        ),
      };
      if (mounted) {
        setState(() {
          _count = next;
          _error = null;
        });
        if (next == 7 && action == CounterAction.increment) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Hedef sayı görüldü. Sonraki adıma geçiş senin seçimin.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Sayaç kaydedilemedi. Tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReset() async {
    if (_busy || (_count ?? 0) == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sayacı sıfırla?'),
        content: const Text(
          'Bu kişisel uygulama kaydındaki sayı sıfırlanacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _apply(CounterAction.reset);
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Bu yalnızca manuel kişisel sayaçtır. İbadetin yapıldığını veya geçerliliğini değerlendirmez.',
            ),
            if (widget.contextLabel != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.contextLabel!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 32),
            Center(
              child: Semantics(
                liveRegion: true,
                excludeSemantics: true,
                label: count == null
                    ? 'Sayaç yükleniyor'
                    : '$count / 7 tamamlanan',
                child: Text(
                  count == null ? '…' : '$count / 7',
                  style: Theme.of(context).textTheme.displayMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: !_busy && count != null && count < 7
                  ? () => _apply(CounterAction.increment)
                  : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('+1 ekle'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: !_busy && count != null && count > 0
                  ? () => _apply(CounterAction.undo)
                  : null,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('Son sayımı geri al'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: !_busy && count != null && count > 0
                  ? _confirmReset
                  : null,
              child: const Text('Sayacı sıfırla'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              if (_count == null)
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
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

class JamaratCounterHubScreen extends StatefulWidget {
  const JamaratCounterHubScreen({
    super.key,
    required this.store,
    required this.sessionId,
  });

  final ProgressStore store;
  final int sessionId;

  @override
  State<JamaratCounterHubScreen> createState() =>
      _JamaratCounterHubScreenState();
}

class _JamaratCounterHubScreenState extends State<JamaratCounterHubScreen> {
  List<JamaratCounterContext>? _contexts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contexts = await widget.store.readJamaratCounters(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _contexts = contexts;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Sayaçlar okunamadı.');
    }
  }

  Future<void> _addContext() async {
    final dayController = TextEditingController();
    final targetController = TextEditingController();
    try {
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Gün ve hedef sayacı ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Etiketler yalnız kişisel takip içindir; uygulama gün veya hedef sırası önermez.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dayController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Gün etiketi',
                    hintText: 'Örn. kişisel gün notu',
                  ),
                ),
                TextField(
                  controller: targetController,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Hedef etiketi',
                    hintText: 'Örn. hedef adı',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (dayController.text.trim().isEmpty ||
                    targetController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(context)
                    .pop((dayController.text, targetController.text));
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      );
      if (values == null) return;
      await widget.store.createJamaratCounter(
        sessionId: widget.sessionId,
        dayLabel: values.$1,
        targetLabel: values.$2,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Sayaç eklenemedi. Etiketleri kontrol et.');
      }
    } finally {
      dayController.dispose();
      targetController.dispose();
    }
  }

  Future<void> _open(JamaratCounterContext context) async {
    await Navigator.of(this.context).push<void>(
      MaterialPageRoute(
        builder: (_) => CounterScreen(
          store: widget.store,
          sessionId: widget.sessionId,
          counterKey: context.counterKey,
          title: 'Cemarat sayacı',
          contextLabel: context.label,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final contexts = _contexts;
    return Scaffold(
      appBar: AppBar(title: const Text('Cemarat sayaçları')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Her gün ve hedef için ayrı manuel sayaç açılır. Sayaç bir ibadet hükmü vermez ve rehber adımını tamamlamaz.',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _addContext,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Yeni gün/hedef sayacı'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            if (contexts == null)
              const Center(child: CircularProgressIndicator())
            else if (contexts.isEmpty)
              const Text('Henüz gün/hedef sayacı eklenmedi.')
            else
              for (final item in contexts)
                Card.outlined(
                  child: ListTile(
                    title: Text(item.label),
                    subtitle: Text('${item.count} / 7'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _open(item),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
