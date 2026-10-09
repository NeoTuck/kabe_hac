import 'package:flutter/material.dart';

import 'progress_store.dart';

class LocalDataScreen extends StatefulWidget {
  const LocalDataScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<LocalDataScreen> createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends State<LocalDataScreen> {
  bool _busy = false;

  Future<void> _clear() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cihazdaki kayıtlar silinsin mi?'),
        content: const Text(
          'Rehber ve prova ilerlemesi, sayaçlar, favoriler, gönderilmemiş '
          'kafile mesajları ve yerel konum paylaşımı ayarları silinir. '
          'Yazı ve ses ayarları ile indirilmiş paketler kalır. '
          'Bu işlem sunucudaki hesabı, mesajları veya etkin konum paylaşımını silmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yerel kayıtları sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.store.clearLocalRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cihazdaki kayıtlar silindi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kayıtlar silinemedi. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cihazdaki veriler')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Bu cihazdaki kişisel kayıtları silebilirsin. Kafile hesabı ve '
            'sunucudaki veriler için ayrı hesap silme işlemi gerekir.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _clear,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(_busy ? 'Siliniyor' : 'Yerel kayıtları sil'),
          ),
        ],
      ),
    ),
  );
}
