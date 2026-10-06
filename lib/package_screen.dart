import 'package:flutter/material.dart';

import 'offline_package.dart';
import 'package_catalog.dart';

class OfflinePackagesScreen extends StatefulWidget {
  const OfflinePackagesScreen({
    super.key,
    required this.manager,
    this.provider,
    this.configurationError,
  });

  final OfflinePackageStore manager;
  final OfflinePackageProvider? provider;
  final String? configurationError;

  @override
  State<OfflinePackagesScreen> createState() => _OfflinePackagesScreenState();
}

class _OfflinePackagesScreenState extends State<OfflinePackagesScreen> {
  List<PackageActivationState>? _states;
  List<OfflinePackageManifest>? _catalog;
  String? _error;
  String? _catalogError;
  String? _busyPackageId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final states = await widget.manager.listActivations();
      List<OfflinePackageManifest>? catalog;
      String? catalogError;
      final provider = widget.provider;
      if (provider != null) {
        try {
          catalog = await provider.loadCatalog();
        } catch (_) {
          catalogError = 'Paket kataloğu alınamadı veya güvenilir değil.';
        }
      }
      if (!mounted) return;
      setState(() {
        _states = states;
        _catalog = catalog;
        _error = null;
        _catalogError = catalogError;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Paket kayıtları okunamadı.');
    }
  }

  Future<void> _delete(PackageActivationState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paketi sil?'),
        content: Text(
          '${state.packageId} dosyaları silinir. Rehber ilerlemesi ve sayaçlar korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Paketi sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.manager.deletePackage(state.packageId);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Paket silinemedi.');
    }
  }

  Future<void> _rollback(PackageActivationState state) async {
    try {
      setState(() => _busyPackageId = state.packageId);
      await widget.manager.rollback(state.packageId);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Önceki paket sürümüne dönülemedi.');
    } finally {
      if (mounted) setState(() => _busyPackageId = null);
    }
  }

  Future<void> _download(OfflinePackageManifest manifest) async {
    final provider = widget.provider;
    if (provider == null) return;
    try {
      setState(() {
        _busyPackageId = manifest.packageId;
        _catalogError = null;
      });
      await provider.downloadAndActivate(manifest);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _catalogError =
              'Paket indirilemedi veya doğrulanamadı. Tekrar deneyebilirsin.';
        });
      }
    } finally {
      if (mounted) setState(() => _busyPackageId = null);
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
    return '${(kib / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final states = _states;
    return Scaffold(
      appBar: AppBar(title: const Text('Çevrimdışı paketler')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  widget.provider == null
                      ? widget.configurationError ?? 'Paket sağlayıcısı yapılandırılmadı. Uygulama paket ağına bağlanmayacak.'
                      : 'Yalnız izinli sunucudan gelen ve sabit özeti güvenilen paketler etkinleştirilir.',
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              'Kurulu paketler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (states == null)
              const Center(child: CircularProgressIndicator())
            else if (states.isEmpty)
              const Text('Kurulu çevrimdışı paket yok.')
            else
              for (final state in states)
                Card.outlined(
                  child: ListTile(
                    title: Text(state.packageId),
                    subtitle: Text(
                      'Etkin sürüm: ${state.activeVersion}'
                      '${state.previousVersion == null ? '' : '\nGeri dönüş: ${state.previousVersion}'}',
                    ),
                    isThreeLine: state.previousVersion != null,
                    trailing: _busyPackageId == state.packageId
                        ? const CircularProgressIndicator()
                        : Wrap(
                            children: [
                              if (state.previousVersion != null)
                                IconButton(
                                  tooltip: 'Önceki sürüme dön',
                                  onPressed: () => _rollback(state),
                                  icon: const Icon(Icons.restore_rounded),
                                ),
                              IconButton(
                                tooltip: 'Paketi sil',
                                onPressed: () => _delete(state),
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                  ),
                ),
            const SizedBox(height: 24),
            Text(
              'İndirilebilir paketler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (widget.provider == null)
              const Text('Paket kataloğu kapalı.')
            else if (_catalogError != null) ...[
              Text(
                _catalogError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Kataloğu yeniden dene'),
              ),
            ] else if (_catalog == null)
              const Center(child: CircularProgressIndicator())
            else if (_catalog!.isEmpty)
              const Text('Katalogda indirilebilir paket yok.')
            else
              for (final manifest in _catalog!)
                Card.outlined(
                  child: ListTile(
                    title: Text(manifest.packageId),
                    subtitle: Text(
                      '${manifest.kind.name} · ${manifest.version} · ${_sizeLabel(manifest.totalBytes)}',
                    ),
                    trailing: _busyPackageId == manifest.packageId
                        ? const CircularProgressIndicator()
                        : FilledButton(
                            onPressed:
                                states?.any(
                                      (state) =>
                                          state.packageId ==
                                              manifest.packageId &&
                                          state.activeVersion ==
                                              manifest.version,
                                    ) ==
                                    true
                                ? null
                                : () => _download(manifest),
                            child: Text(
                              states?.any(
                                        (state) =>
                                            state.packageId ==
                                                manifest.packageId &&
                                            state.activeVersion ==
                                                manifest.version,
                                      ) ==
                                      true
                                  ? 'Doğrulandı'
                                  : 'İndir',
                            ),
                          ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
