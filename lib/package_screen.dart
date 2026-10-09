import 'package:flutter/material.dart';

import 'offline_package.dart';
import 'package_catalog.dart';

String _packageTitle(String id) => switch (id) {
  'map-mecca' => 'Mekke çevrimdışı haritası',
  'map-medina' => 'Medine çevrimdışı haritası',
  'travel-pilgrim-snapshot' => 'Mekke ve Medine yerleri',
  _ => id,
};

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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
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
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(PackageActivationState state) async {
    if (_busyPackageId != null || _loading) return;
    setState(() => _busyPackageId = state.packageId);
    try {
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
      if (confirmed != true || !mounted) return;
      await widget.manager.deletePackage(state.packageId);
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'Paket silinemedi.');
    } finally {
      if (mounted) setState(() => _busyPackageId = null);
    }
  }

  Future<void> _rollback(PackageActivationState state) async {
    if (_busyPackageId != null || _loading) return;
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
    if (provider == null || _busyPackageId != null || _loading) return;
    try {
      setState(() {
        _busyPackageId = manifest.packageId;
        _catalogError = null;
      });
      await provider.downloadAndActivate(manifest);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_packageTitle(manifest.packageId)} indirildi.'),
          ),
        );
      }
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

  Widget _installedCard(PackageActivationState state) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _packageTitle(state.packageId),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'Etkin sürüm: ${state.activeVersion}${state.previousVersion == null ? '' : '\nGeri dönüş: ${state.previousVersion}'}',
          ),
          const SizedBox(height: 8),
          if (_busyPackageId == state.packageId)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (state.previousVersion != null)
                  OutlinedButton.icon(
                    onPressed: _busyPackageId != null || _loading
                        ? null
                        : () => _rollback(state),
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Önceki sürüme dön'),
                  ),
                TextButton.icon(
                  onPressed: _busyPackageId != null || _loading
                      ? null
                      : () => _delete(state),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Paketi sil'),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _downloadCard(
    OfflinePackageManifest manifest,
    List<PackageActivationState>? states,
  ) {
    final installed =
        states?.any(
          (s) =>
              s.packageId == manifest.packageId &&
              s.activeVersion == manifest.version,
        ) ==
        true;
    final label = switch (manifest.kind) {
      OfflinePackageKind.audio => 'Ses ve rehber',
      OfflinePackageKind.map => 'Harita',
      OfflinePackageKind.travel => 'Gezi ve rotalar',
      OfflinePackageKind.language => 'Dil ve iletişim',
    };
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _packageTitle(manifest.packageId),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '$label · ${manifest.version} · ${_sizeLabel(manifest.totalBytes)}',
            ),
            const SizedBox(height: 12),
            if (_busyPackageId == manifest.packageId)
              const LinearProgressIndicator()
            else
              FilledButton(
                onPressed: installed || _busyPackageId != null || _loading
                    ? null
                    : () => _download(manifest),
                child: Text(
                  installed
                      ? 'Doğrulandı'
                      : switch (manifest.packageId) {
                          'map-mecca' => 'Mekke haritasını indir',
                          'map-medina' => 'Medine haritasını indir',
                          'travel-pilgrim-snapshot' => 'Yer kayıtlarını indir',
                          _ => 'İndir',
                        },
                ),
              ),
          ],
        ),
      ),
    );
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
            if (states == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (states == null)
              OutlinedButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Paketleri yeniden dene'),
              )
            else if (states.isEmpty)
              const Text('Kurulu çevrimdışı paket yok.')
            else
              for (final state in states) _installedCard(state),
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
                onPressed: _busyPackageId != null || _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Kataloğu yeniden dene'),
              ),
            ] else if (_catalog == null)
              const Center(child: CircularProgressIndicator())
            else if (_catalog!.isEmpty)
              const Text('Katalogda indirilebilir paket yok.')
            else
              for (final manifest in _catalog!) _downloadCard(manifest, states),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busyPackageId != null || _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Paketleri yenile'),
            ),
          ],
        ),
      ),
    );
  }
}
