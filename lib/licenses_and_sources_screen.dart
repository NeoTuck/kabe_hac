import 'package:flutter/material.dart';

/// Attribution for assets shipped by this app. Package licenses are provided
/// separately by Flutter's LicenseRegistry on the same screen.
class LicensesAndSourcesScreen extends StatelessWidget {
  const LicensesAndSourcesScreen({super.key});

  Future<void> _showFontLicense(
    BuildContext context,
    String name,
    String asset,
  ) async {
    final text = await DefaultAssetBundle.of(context).loadString(asset);
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('$name lisansı')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(text),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lisanslar ve kaynaklar')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Uygulamaya gömülü yazı tipleri',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Noto Sans ve Noto Naskh Arabic, The Noto Project Authors '
            'tarafından SIL Open Font License 1.1 ile yayımlanır. '
            'Her yazı tipinin telif ve lisans metni aşağıdadır.',
          ),
          ListTile(
            title: const Text('Noto Sans'),
            subtitle: const Text('The Noto Project Authors · OFL 1.1'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontLicense(
              context,
              'Noto Sans',
              'assets/fonts/NotoSans-OFL.txt',
            ),
          ),
          ListTile(
            title: const Text('Noto Naskh Arabic'),
            subtitle: const Text('The Noto Project Authors · OFL 1.1'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontLicense(
              context,
              'Noto Naskh Arabic',
              'assets/fonts/NotoNaskhArabic-OFL.txt',
            ),
          ),
          const Divider(),
          Text('Rehber içeriği', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Umre ve Hac açıklamaları kaynaklara dayanılarak bu proje için '
            'özgün taslak olarak yazıldı. Dinî uzman incelemesi ve yayın '
            'hakları tamamlanmadığı için taslak metinler ve telbiye kullanıcı '
            'rehberinde gösterilmez. Her onaylı kaydın kaynak ayrıntısı '
            'ilgili adımda gösterilir.',
          ),
          const SizedBox(height: 20),
          Text(
            'Harita ve gezi verisi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            '© OpenStreetMap contributors · ODbL 1.0. Mekke ve Medine '
            'şehir haritaları ve yer kayıtları Geofabrik kaynak verisinden '
            'üretilmiştir. Paketler isteğe bağlı indirilir. Kaynak tarihi '
            'pakette ve haritada gösterilir; kayıtlar canlı açılış, '
            'güvenli yürüme rotası veya kutsal sınır doğrulaması değildir. '
            'Türetilmiş veri tabanı aynı ODbL lisansıyla aşağıdaki adreste yayımlanır.',
          ),
          const SelectableText(
            'https://github.com/NeoTuck/kabe_hac/tree/codex/mvp1-pilot/offline_packages/osm-2026-10-08',
          ),
          ListTile(
            title: const Text('OpenStreetMap veri lisansı'),
            subtitle: const Text('ODbL 1.0 · Tam lisans metni'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFontLicense(
              context,
              'OpenStreetMap',
              'assets/licenses/ODbL-1.0.txt',
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Hac ve Umre Sesli Rehber',
              applicationVersion: '0.1.0 · MVP 1 pilot',
            ),
            icon: const Icon(Icons.article_outlined),
            label: const Text('Açık kaynak paket lisansları'),
          ),
        ],
      ),
    ),
  );
}
