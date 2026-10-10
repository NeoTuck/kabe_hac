import 'package:flutter/material.dart';

import 'progress_store.dart';
import 'push_service.dart';

class LocalDataScreen extends StatefulWidget {
  const LocalDataScreen({super.key, required this.store, this.push});

  final ProgressStore store;
  final PushTokenCoordinator? push;

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
          'Bu cihazın açık bildirim kaydı önce kapatılır. '
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
      final savedPushUser = await widget.store.readAppValue('push_opt_in_user');
      if (savedPushUser != null &&
          savedPushUser.isNotEmpty &&
          (widget.push == null ||
              widget.push!.currentUserId() != savedPushUser)) {
        throw const _PushCleanupUnavailable();
      }
      await widget.push?.disable();
      await widget.store.clearLocalRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cihazdaki kayıtlar silindi.')),
        );
      }
    } on _PushCleanupUnavailable {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bildirim kaydı kapatılamıyor. Kafile bağlantısını ve bildirimi açtığın hesabı kontrol edip tekrar dene.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kayıtlar silinemedi. Bildirimleri kapatma işlemi başarısız olmuş olabilir; tekrar dene.',
            ),
          ),
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

class _PushCleanupUnavailable implements Exception {
  const _PushCleanupUnavailable();
}
