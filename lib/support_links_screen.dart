import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'service_readiness.dart';

class SupportLinksScreen extends StatelessWidget {
  const SupportLinksScreen({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı. Tekrar dene.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        'Gizlilik politikası',
        const String.fromEnvironment('PRIVACY_POLICY_URL'),
      ),
      ('Destek', const String.fromEnvironment('SUPPORT_URL')),
      (
        'Hesap silme sayfası',
        const String.fromEnvironment('ACCOUNT_DELETION_URL'),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik ve destek')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Bağlantılar ürün sorumlusu tarafından doğrulanıp dağıtım sürümüne eklenir.',
            ),
            const SizedBox(height: 16),
            for (final (label, value) in entries)
              ListTile(
                title: Text(label),
                subtitle: Text(
                  ServiceReadiness.httpsUrl(value) == null
                      ? 'Bağlantı henüz sağlanmadı.'
                      : value,
                ),
                trailing: ServiceReadiness.httpsUrl(value) == null
                    ? null
                    : const Icon(Icons.open_in_new_rounded),
                onTap: ServiceReadiness.httpsUrl(value) == null
                    ? null
                    : () => _open(context, ServiceReadiness.httpsUrl(value)!),
              ),
          ],
        ),
      ),
    );
  }
}
