import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_screen.dart';
import 'reader_settings.dart';
import 'licenses_and_sources_screen.dart';
import 'local_data_screen.dart';
import 'push_service.dart';
import 'support_links_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    this.push,
    this.packages,
    this.packageProvider,
    this.packageConfigurationError,
    this.onOpenPackage,
    this.onPackagesChanged,
  });

  final ReaderSettings settings;
  final PushTokenCoordinator? push;
  final OfflinePackageManager? packages;
  final OfflinePackageProvider? packageProvider;
  final String? packageConfigurationError;
  final Future<void> Function(OfflinePackageManifest manifest)? onOpenPackage;
  final Future<void> Function()? onPackagesChanged;

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
            const Text('Onaylı anlatım kayıtları henüz eklenmedi.'),
            if (packages != null) ...[
              const SizedBox(height: 20),
              Card.outlined(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RehberTheme.goldLight.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.download_for_offline_rounded,
                      color: RehberTheme.goldLight,
                    ),
                  ),
                  title: const Text(
                    'İndirilebilir Öğeler ve Paketler',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Çevrimdışı haritalar, yer kayıtları ve ses paketlerini hızlıca yönet',
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                  ),
                  onTap: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => OfflinePackagesScreen(
                          manager: packages!,
                          provider: packageProvider,
                          configurationError: packageConfigurationError,
                          onOpen: onOpenPackage,
                        ),
                      ),
                    );
                    if (onPackagesChanged != null) {
                      await onPackagesChanged!();
                    }
                  },
                ),
              ),
            ],
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
                  builder: (_) =>
                      LocalDataScreen(store: settings.store, push: push),
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
