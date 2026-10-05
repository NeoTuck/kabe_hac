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
  });

  final ProgressStore store;
  final int sessionId;
  final String counterKey;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int? _count;
  bool _busy = false;
  String? _error;
  final Random _random = Random.secure();

  String get _title =>
      widget.counterKey == 'tawaf' ? 'Tavaf sayacı' : 'Sa‘y sayacı';

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
      if (mounted) setState(() => _count = count);
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
            const SizedBox(height: 32),
            Center(
              child: Semantics(
                label: count == null
                    ? 'Sayaç yükleniyor'
                    : '$count / 7 tamamlanan',
                child: Text(
                  count == null ? '…' : '$count / 7',
                  style: Theme.of(context).textTheme.displayLarge
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
