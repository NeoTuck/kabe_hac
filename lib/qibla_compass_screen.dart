import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_theme.dart';
import 'offline_city_map_screen.dart';
import 'offline_package.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';

class QiblaCompassScreen extends StatefulWidget {
  const QiblaCompassScreen({
    super.key,
    this.packages,
    this.catalog,
    this.travelRepository,
  });

  final OfflinePackageManager? packages;
  final TravelCatalog? catalog;
  final LocalTravelRepository? travelRepository;

  @override
  State<QiblaCompassScreen> createState() => _QiblaCompassScreenState();
}

class _QiblaCompassScreenState extends State<QiblaCompassScreen> {
  // Default to Mecca Hotel Area (Aziziyah / Misfalah)
  double _userLat = 21.4133;
  double _userLng = 39.8261;
  final double _heading = 0.0; // Compass heading (0 = North)
  bool _loadingLocation = false;
  String? _customLocationName;

  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  Future<void> _requestGpsLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cihazın konum servisi kapalı. Lütfen GPS servisini açın.',
              ),
            ),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kıble yönü için konum izni verilmedi. Aşağıdaki hazır şehirlerden seçebilirsiniz.',
              ),
            ),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _customLocationName =
              'Mevcut GPS (${position.latitude.toStringAsFixed(3)}°, ${position.longitude.toStringAsFixed(3)}°)';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mevcut GPS konumunuz alındı ve Kıble açısı güncellendi.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPS konumu alınamadı. Lütfen açık alanda tekrar deneyin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  double get _qiblaBearing {
    const kaabaLatRad = _kaabaLat * math.pi / 180;
    const kaabaLngRad = _kaabaLng * math.pi / 180;
    final userLatRad = _userLat * math.pi / 180;
    final userLngRad = _userLng * math.pi / 180;

    final dLng = kaabaLngRad - userLngRad;
    final y = math.sin(dLng);
    final x =
        math.cos(userLatRad) * math.tan(kaabaLatRad) -
        math.sin(userLatRad) * math.cos(dLng);
    final qibla = math.atan2(y, x) * (180 / math.pi);
    return (qibla + 360) % 360;
  }

  double get _distanceKm {
    const r = 6371.0;
    final dLat = (_kaabaLat - _userLat) * math.pi / 180;
    final dLon = (_kaabaLng - _userLng) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_userLat * math.pi / 180) *
            math.cos(_kaabaLat * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final qiblaAngle = _qiblaBearing;
    final relativeAngle = (qiblaAngle - _heading + 360) % 360;
    final isAligned = relativeAngle < 5 || relativeAngle > 355;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kıble Pusulası'),
        actions: [
          IconButton(
            tooltip: 'Kâbe’yi Haritada Aç',
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              if (widget.packages != null && widget.catalog != null) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => OfflineCityMapScreen(
                      packages: widget.packages!,
                      catalog: widget.catalog!,
                      travelRepository: widget.travelRepository,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Harita Yolculuk sekmesinden açılabilir.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: RehberTheme.welcomeGradient,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: RehberTheme.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.mosque_rounded,
                              color: RehberTheme.goldLight,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Hedef: Kâbe-i Muazzama',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isAligned
                                ? const Color(0xFF2E7D32)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAligned
                                ? '✓ KIBLEYE YÖNELDİNİZ'
                                : 'Pusulayı Çevirin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Kıble Açısı',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${qiblaAngle.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                color: RehberTheme.goldLight,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(width: 1, height: 28, color: Colors.white24),
                        Column(
                          children: [
                            const Text(
                              'Kâbe’ye Kuş Uçuşu',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _distanceKm < 10
                                  ? '${(_distanceKm * 1000).round()} m'
                                  : '${_distanceKm.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Visual Compass Dial
              Center(
                child: SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Compass Outer Ring
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dark
                              ? const Color(0xFF13221E)
                              : const Color(0xFFEDF5F2),
                          border: Border.all(
                            color: isAligned
                                ? RehberTheme.goldLight
                                : (dark ? Colors.white24 : Colors.black12),
                            width: isAligned ? 3.5 : 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isAligned
                                  ? RehberTheme.gold.withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.1),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),

                      // Compass Cardinal Marks (N, S, E, W)
                      const Positioned(
                        top: 14,
                        child: Text(
                          'K (Kuzey)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Positioned(
                        bottom: 14,
                        child: Text(
                          'G (Güney)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Positioned(
                        right: 14,
                        child: Text(
                          'D (Doğu)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 14,
                        child: Text(
                          'B (Batı)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      // Rotating Needle towards Qibla
                      Transform.rotate(
                        angle: relativeAngle * (math.pi / 180),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Kaaba indicator needle head
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E3A1A),
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: RehberTheme.goldLight,
                                size: 30,
                              ),
                            ),
                            Container(
                              width: 4,
                              height: 60,
                              decoration: BoxDecoration(
                                color: RehberTheme.goldLight,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1E3A1A),
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 40,
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Orientation Guidance Text
              Center(
                child: Text(
                  isAligned
                      ? 'Harika! Telefonunuz şu anda tam olarak Kâbe-i Muazzama yönüne bakıyor.'
                      : 'Telefonunuzu yatay tutun ve altın oku Kâbe yönüne çevirin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isAligned ? const Color(0xFF2E7D32) : Colors.grey,
                    fontWeight: isAligned ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // GPS Button
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingLocation ? null : _requestGpsLocation,
                  icon: _loadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    _loadingLocation
                        ? 'GPS Konumu Alınıyor...'
                        : 'Mevcut Konumumu Kullan (GPS)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (_customLocationName != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    avatar: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF2E7D32),
                    ),
                    label: Text(
                      _customLocationName!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Quick Location preset buttons (Mekke / Medine / Otel)
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Mekke Oteller Bölgesi'),
                    selected:
                        _customLocationName == null &&
                        (_userLat - 21.4133).abs() < 0.001,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _userLat = 21.4133;
                          _userLng = 39.8261;
                          _customLocationName = null;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Medine Mescid-i Nebevi'),
                    selected:
                        _customLocationName == null &&
                        (_userLat - 24.4672).abs() < 0.001,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _userLat = 24.4672;
                          _userLng = 39.6111;
                          _customLocationName = null;
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Cidde Havalimanı'),
                    selected:
                        _customLocationName == null &&
                        (_userLat - 21.6796).abs() < 0.001,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _userLat = 21.6796;
                          _userLng = 39.1565;
                          _customLocationName = null;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KVKK & Local Processing Notice
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KVKK ve Gizlilik Güvencesi: Konumunuz yalnızca cihazınızda Kâbe açısını anlık hesaplamak için yerel kullanılır; hiçbir sunucuya aktarılmaz veya kaydedilmez.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
