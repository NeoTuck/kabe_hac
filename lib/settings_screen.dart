import 'package:flutter/material.dart';

import 'reader_settings.dart';
import 'licenses_and_sources_screen.dart';
import 'local_data_screen.dart';
import 'support_links_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final ReaderSettings settings;

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayar kaydedilemedi. Tekrar dene.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yazı ve ses ayarları')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Görünüm', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const {
                  ThemeMode.system: 'Sistem',
                  ThemeMode.light: 'Açık',
                  ThemeMode.dark: 'Koyu',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: settings.themeMode == entry.key,
                    onSelected: (_) =>
                        _save(context, () => settings.setThemeMode(entry.key)),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Yazı boyutu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [1.0, 1.25, 1.5, 2.0])
                  ChoiceChip(
                    label: Text('%${(value * 100).round()}'),
                    selected: settings.textMultiplier == value,
                    onSelected: (_) =>
                        _save(context, () => settings.setTextMultiplier(value)),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Türkçe anlatım hızı',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [1.0, 1.25])
                  ChoiceChip(
                    label: Text('${value}x'),
                    selected: settings.narrationSpeed == value,
                    onSelected: (_) =>
                        _save(context, () => settings.setNarrationSpeed(value)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Sentetik taslak sesler rehberde dinlenebilir. Onaylı anlatım kayıtları henüz eklenmedi.',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => const SupportLinksScreen()),
              ),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Gizlilik ve destek'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LocalDataScreen(store: settings.store),
                ),
              ),
              icon: const Icon(Icons.storage_outlined),
              label: const Text('Cihazdaki veriler'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const LicensesAndSourcesScreen(),
                ),
              ),
              icon: const Icon(Icons.info_outline),
              label: const Text('Lisanslar ve kaynaklar'),
            ),
          ],
        ),
      ),
    ),
  );
}
