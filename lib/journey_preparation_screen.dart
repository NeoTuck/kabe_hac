import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'guide_catalog.dart';
import 'content_repository.dart';
import 'local_map_repository.dart';
import 'narration_service.dart';
import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_failure.dart';
import 'package_screen.dart';
import 'travel_repository.dart';

class JourneyPreparationScreen extends StatefulWidget {
  const JourneyPreparationScreen({
    super.key,
    required this.catalogs,
    required this.packages,
    this.provider,
    this.configurationError,
    this.initialType = GuideType.umrah,
    this.onOpenPackage,
  });
  final Map<GuideType, GuideCatalog> catalogs;
  final OfflinePackageManager packages;
  final OfflinePackageProvider? provider;
  final String? configurationError;
  final GuideType initialType;
  final Future<void> Function(OfflinePackageManifest)? onOpenPackage;

  @override
  State<JourneyPreparationScreen> createState() =>
      _JourneyPreparationScreenState();
}

class _JourneyPreparationScreenState extends State<JourneyPreparationScreen> {
  late GuideType _type = widget.initialType;
  late Map<GuideType, GuideCatalog> _catalogs = widget.catalogs;
  bool _checking = false;
  bool _mapDataReady = false;
  Map<String, String> _maps = {};
  int _places = 0;
  int _readyAudio = 0;
  int _availableAudio = 0;
  int _pendingAudio = 0;
  int _requiredAudio = 0;
  String? _error;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    final maps = <String, String>{};
    String? error;
    String? audioError;
    int places = 0, ready = 0, available = 0, pending = 0;
    var catalogs = _catalogs;
    var audioIds = <String>{};
    final readMaps = <String>{};
    try {
      catalogs = await LocalContentRepository(packages: widget.packages).load();
      final catalog = catalogs[_type]!;
      audioIds = {
        for (final step in catalog.steps) ...step.linkedAudioIds,
        for (final prayer in catalog.prayerRecords.values)
          ...prayer.linkedAudioIds,
      };
      // This check only reads local bytes; it never asks the network catalog.
      for (final state in await widget.packages.listActivations()) {
        try {
          final manifest = await widget.packages.verifyActivePackage(
            state.packageId,
          );
          if (manifest?.kind == OfflinePackageKind.map) {
            maps[state.packageId] =
                'Dosyalar doğrulandı · haritada açıp kontrol et.';
          }
        } catch (failure) {
          maps[state.packageId] = packageFailureMessage(failure);
        }
      }
      final repository = LocalMapRepository(widget.packages);
      for (final map in await repository.list()) {
        try {
          await repository.load(map);
          readMaps.add(map.packageId);
          maps[map.packageId] = 'Dosyalar doğrulandı ve harita verisi okundu · haritada açıp kontrol et.';
        } catch (failure) {
          maps[map.packageId] = packageFailureMessage(failure);
        }
      }
      places = (await LocalTravelRepository(
        packages: widget.packages,
      ).load()).points.where((p) => !p.isTestData).length;
      for (final id in audioIds) {
        final audio = catalog.audioRecords[id];
        if (audio == null || audio.asset == null || audio.assetSha256 == null) {
          continue;
        }
        final textApproved =
            catalog.stepById(audio.textId ?? '')?.isApproved ??
            catalog.prayerRecords[audio.textId]?.isApproved ??
            false;
        try {
          final asset = audio.asset!;
          String digest;
          if (asset.startsWith('package:')) {
            final file = await resolvePackageAudio(asset, widget.packages);
            if (file == null) continue;
            digest = (await sha256.bind(file.openRead()).first).toString();
          } else {
            final bytes = await rootBundle.load(asset);
            digest = sha256
                .convert(
                  bytes.buffer.asUint8List(
                    bytes.offsetInBytes,
                    bytes.lengthInBytes,
                  ),
                )
                .toString();
          }
          if (digest == audio.assetSha256) {
            available++;
            if (audio.status == ReviewStatus.approved &&
                !audio.reviewOnly &&
                textApproved) {
              ready++;
            } else {
              pending++;
            }
          }
        } catch (failure) {
          audioError = packageFailureMessage(failure);
        }
      }
    } catch (failure) {
      error = packageFailureMessage(failure);
    }
    if (!mounted) return;
    setState(() {
      _maps = maps;
      _catalogs = catalogs;
      _mapDataReady = readMaps.containsAll({'map-mecca', 'map-medina'});
      _places = places;
      _readyAudio = ready;
      _availableAudio = available;
      _pendingAudio = pending;
      _requiredAudio = audioIds.length;
      _error = error;
      _audioError = audioError;
      _checking = false;
    });
  }

  Future<void> _packages(OfflinePackageKind kind) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OfflinePackagesScreen(
          manager: widget.packages,
          provider: widget.provider,
          configurationError: widget.configurationError,
          focusKind: kind,
          onOpen: widget.onOpenPackage,
        ),
      ),
    );
    if (mounted) await _check();
  }

  Widget _card(
    String title,
    String status,
    String detail, {
    String? action,
    VoidCallback? onTap,
  }) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(status),
          const SizedBox(height: 8),
          Text(detail),
          if (action != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _checking ? null : onTap,
              child: Text(action),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final catalog = _catalogs[_type]!;
    final filesReady =
        _error == null &&
        _audioError == null &&
        !catalog.isPreview &&
        _mapDataReady &&
        _places > 0 &&
        _requiredAudio > 0 &&
        _readyAudio == _requiredAudio;
    return Scaffold(
      appBar: AppBar(title: const Text('Yolculuğa hazır mıyım?')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card.filled(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _checking
                        ? 'Cihazdaki hazırlık kontrol ediliyor…'
                        : filesReady
                        ? 'Çevrimdışı dosyalar hazır. Cihazda açılış ve dinleme kontrolü gerekli.'
                        : 'Hazırlık tamamlanmadı. Eksik veya inceleme bekleyen bölümleri aşağıdan kontrol et.',
                  ),
                ),
              ),
            ),
            const Text(
              'Cihazdaki dosyalar internet olmadan kontrol edilir. Teknik hazırlık, dinî onay veya saha güvenliği anlamına gelmez. Yola çıkmadan uçak modunda rehberi, haritayı ve izinli sesleri açıp dene.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<GuideType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Hazırlığını kontrol edeceğin rehber',
              ),
              items: [
                for (final type in GuideType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: _checking
                  ? null
                  : (type) {
                      if (type != null) {
                        setState(() => _type = type);
                        _check();
                      }
                    },
            ),
            if (_checking)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null) Text(_error!),
            _card(
              'Rehber',
              '${catalog.steps.length} adım cihazda · sürüm ${catalog.contentVersion}',
              catalog.isPreview
                  ? 'Başlıklar çevrimdışı açılır. İçerik incelemede; onaylı ibadet rehberi henüz hazır değil.'
                  : 'Rehber kataloğu okundu. Kaldığın yerden devam ederek açılmayı kontrol et.',
            ),
            _card(
              'Harita',
              _checking
                  ? 'Kontrol ediliyor…'
                  : 'Mekke: ${_maps['map-mecca'] ?? 'Kurulu değil'}\nMedine: ${_maps['map-medina'] ?? 'Kurulu değil'}',
              'Yer kayıtları: $_places cihazda. Harita ve yer kayıtları ayrı paketlerdir. Harita canlı veya güvenli rota sağlamaz.',
              action: 'Harita paketlerine git',
              onTap: () => _packages(OfflinePackageKind.map),
            ),
            OutlinedButton(
              onPressed: _checking
                  ? null
                  : () => _packages(OfflinePackageKind.travel),
              child: const Text('Yer kayıtları paketine git'),
            ),
            _card(
              'Cihazdaki sesler',
              _checking
                  ? 'Kontrol ediliyor…'
                  : '$_availableAudio / $_requiredAudio ses dosyası cihazda ve özeti doğrulandı',
              '$_pendingAudio taslak veya inceleme bekleyen kayıt. '
                  '${_requiredAudio - _availableAudio} kayıt eksik veya doğrulanamadı. '
                  'Taslak sesler öğrenme ve provada açık etiketle dinlenebilir; izinli yayın sesi sayılmaz.',
            ),
            _card(
              'İzinli sesler',
              _checking
                  ? 'Kontrol ediliyor…'
                  : '$_readyAudio / $_requiredAudio izinli ses dosyası doğrulandı',
              _audioError ?? 'Taslak kayıtlar bu sayıya dahil değildir. Arapça telbiye dahil eksik kayıtlar gerçek inceleme ve dağıtım izni bekler. Dosya kontrolü, cihazda dinleme kabulü değildir.',
              action: 'Rehber ve ses paketlerine git',
              onTap: () => _packages(OfflinePackageKind.audio),
            ),
            OutlinedButton.icon(
              onPressed: _checking ? null : _check,
              icon: const Icon(Icons.refresh),
              label: const Text('Cihazdaki hazırlığı yeniden kontrol et'),
            ),
          ],
        ),
      ),
    );
  }
}
