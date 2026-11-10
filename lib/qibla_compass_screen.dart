import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const EventChannel _compassChannel = EventChannel(
    'com.mustafasenoglu.hac_umre_sesli_rehber/compass',
  );

  // Default to Mecca Hotel Area (Aziziyah / Misfalah)
  double _userLat = 21.4133;
  double _userLng = 39.8261;
  double _heading = 0.0; // Device compass heading (0 = North)
  bool _hasSensor = false;
  bool _loadingLocation = false;
  String? _customLocationName;
  StreamSubscription<dynamic>? _compassSubscription;
  DateTime _lastHapticTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const double _kaabaLat = 21.422487;
  static const double _kaabaLng = 39.826206;

  static const List<Map<String, dynamic>> _quickCities = [
    {'name': 'Mekke', 'lat': 21.4133, 'lng': 39.8261},
    {'name': 'Medine', 'lat': 24.4672, 'lng': 39.6111},
    {'name': 'İstanbul', 'lat': 41.0082, 'lng': 28.9784},
    {'name': 'Ankara', 'lat': 39.9334, 'lng': 32.8597},
    {'name': 'İzmir', 'lat': 38.4237, 'lng': 27.1428},
    {'name': 'Konya', 'lat': 37.8746, 'lng': 32.4932},
    {'name': 'Bursa', 'lat': 40.1885, 'lng': 29.0610},
    {'name': 'Gaziantep', 'lat': 37.0662, 'lng': 37.3833},
    {'name': 'Trabzon', 'lat': 41.0027, 'lng': 39.7168},
    {'name': 'Diyarbakır', 'lat': 37.9144, 'lng': 40.2306},
    {'name': 'Cidde', 'lat': 21.5433, 'lng': 39.1728},
    {'name': 'Almanya / Frankfurt', 'lat': 50.1109, 'lng': 8.6821},
  ];

  @override
  void initState() {
    super.initState();
    _startCompassStream();
    _requestGpsLocation(silent: true);
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _startCompassStream() {
    try {
      _compassSubscription = _compassChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event is num && mounted) {
            final newHeading = event.toDouble();
            setState(() {
              _hasSensor = true;
              // Smooth angular filter (damping short jitter)
              _heading = _smoothAngle(_heading, newHeading);
            });
            _checkHapticAlignment();
          }
        },
        onError: (_) {
          if (mounted) setState(() => _hasSensor = false);
        },
      );
    } catch (_) {
      _hasSensor = false;
    }
  }

  double _smoothAngle(double current, double target) {
    var diff = (target - current) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (current + diff * 0.35 + 360) % 360;
  }

  void _checkHapticAlignment() {
    final qibla = _qiblaBearing;
    final relative = (qibla - _heading + 360) % 360;
    final isAligned = relative < 4 || relative > 356;
    if (isAligned) {
      final now = DateTime.now();
      if (now.difference(_lastHapticTime).inMilliseconds > 900) {
        _lastHapticTime = now;
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _requestGpsLocation({bool silent = false}) async {
    if (!silent) setState(() => _loadingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent && mounted) {
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
      if (permission == LocationPermission.denied && !silent) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!silent && mounted) {
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
          timeLimit: Duration(seconds: 6),
        ),
      );

      if (mounted) {
        setState(() {
          _userLat = position.latitude;
          _userLng = position.longitude;
          _customLocationName =
              'Mevcut GPS (${position.latitude.toStringAsFixed(2)}°, ${position.longitude.toStringAsFixed(2)}°)';
        });
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mevcut GPS konumunuz alındı ve Kıble açısı güncellendi.',
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPS konumu alınamadı. Lütfen hazır şehirlerden seçin.',
            ),
          ),
        );
      }
    } finally {
      if (!silent && mounted) {
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
    final isAligned = relativeAngle < 4.5 || relativeAngle > 355.5;

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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Status & Information Banner
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: isAligned
                      ? const LinearGradient(
                          colors: [Color(0xFF0F382A), Color(0xFF1B5E44)],
                        )
                      : RehberTheme.welcomeGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAligned
                        ? RehberTheme.goldLight
                        : RehberTheme.gold.withValues(alpha: 0.35),
                    width: isAligned ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isAligned
                          ? RehberTheme.emerald.withValues(alpha: 0.45)
                          : Colors.black.withValues(alpha: 0.2),
                      blurRadius: isAligned ? 14 : 8,
                    ),
                  ],
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
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isAligned
                                ? const Color(0xFF2E7D32)
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAligned
                                  ? RehberTheme.goldLight
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            isAligned
                                ? '✓ KIBLEYE YÖNELDİNİZ'
                                : 'Pusulayı Çevirin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: isAligned
                                  ? FontWeight.w900
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                              'Cihaz Yönü',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_heading.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                color: Colors.white,
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
                              'Kâbe’ye Mesafe',
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
              const SizedBox(height: 28),

              // Visual Compass Dial (Full Interactive Rotation)
              Center(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Manual interactive rotation fallback
                    final delta = details.delta.dx;
                    setState(() {
                      _heading = (_heading - delta * 0.7 + 360) % 360;
                    });
                    _checkHapticAlignment();
                  },
                  child: SizedBox(
                    width: 290,
                    height: 290,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Phone Forward Marker (Top Notch indicating where phone points)
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isAligned
                                  ? RehberTheme.goldLight
                                  : Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isAligned
                                              ? RehberTheme.goldLight
                                              : Colors.redAccent)
                                          .withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Rotating Compass Rose (Rotates counter-heading so North points to real North)
                        Transform.rotate(
                          angle: (-_heading) * (math.pi / 180),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer Dial Ring
                              Container(
                                width: 260,
                                height: 260,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dark
                                      ? const Color(0xFF0F1E19)
                                      : const Color(0xFFEDF5F2),
                                  border: Border.all(
                                    color: isAligned
                                        ? RehberTheme.goldLight
                                        : (dark
                                              ? Colors.white24
                                              : Colors.black12),
                                    width: isAligned ? 3.5 : 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isAligned
                                          ? RehberTheme.gold.withValues(
                                              alpha: 0.35,
                                            )
                                          : Colors.black.withValues(
                                              alpha: 0.15,
                                            ),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),

                              // Inner Degree Tick Marks
                              CustomPaint(
                                size: const Size(260, 260),
                                painter: _CompassDialPainter(
                                  isAligned: isAligned,
                                ),
                              ),

                              // Cardinal Marks (N, S, E, W)
                              const Positioned(
                                top: 12,
                                child: Text(
                                  'K (Kuzey)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Positioned(
                                bottom: 12,
                                child: Text(
                                  'G (Güney)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 12,
                                child: Text(
                                  'D (Doğu)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Positioned(
                                left: 12,
                                child: Text(
                                  'B (Batı)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              // Qibla Indicator on the Dial at Qibla Bearing
                              Transform.rotate(
                                angle: qiblaAngle * (math.pi / 180),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: isAligned
                                            ? const Color(0xFF1B5E44)
                                            : const Color(0xFF133E35),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: RehberTheme.goldLight,
                                          width: 2.0,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: RehberTheme.goldLight
                                                .withValues(alpha: 0.5),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.mosque_rounded,
                                        color: RehberTheme.goldLight,
                                        size: 20,
                                      ),
                                    ),
                                    Container(
                                      width: 3.5,
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
                                        color: Color(0xFF133E35),
                                      ),
                                    ),
                                    Container(
                                      width: 2,
                                      height: 40,
                                      color: Colors.grey.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Orientation Guidance Text
              Center(
                child: Text(
                  isAligned
                      ? 'Harika! Telefonunuz şu anda tam olarak Kâbe-i Muazzama yönüne bakıyor.'
                      : (_hasSensor
                            ? 'Telefonunuzu yatay tutun ve altın Kâbe simgesini tepeye çevirin.'
                            : 'Cihazınızı yatay tutun. Parmağınızla pusulayı çevirerek de yönü ayarlayabilirsiniz.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isAligned ? const Color(0xFF2E7D32) : Colors.grey,
                    fontWeight: isAligned ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // GPS Button
              Center(
                child: FilledButton.tonalIcon(
                  onPressed: _loadingLocation
                      ? null
                      : () => _requestGpsLocation(silent: false),
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

              // Quick Location preset buttons (Popüler Şehirler)
              const Center(
                child: Text(
                  'Veya Şehir Seçerek Kıble Açısını Ayarlayın:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final city in _quickCities)
                    ChoiceChip(
                      label: Text(city['name'] as String),
                      selected:
                          _customLocationName == null &&
                          (_userLat - (city['lat'] as double)).abs() < 0.05 &&
                          (_userLng - (city['lng'] as double)).abs() < 0.05,
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _userLat = city['lat'] as double;
                            _userLng = city['lng'] as double;
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest
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

class _CompassDialPainter extends CustomPainter {
  const _CompassDialPainter({required this.isAligned});
  final bool isAligned;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final tickPaint = Paint()
      ..color = (isAligned ? RehberTheme.goldLight : Colors.grey).withValues(
        alpha: 0.35,
      )
      ..strokeWidth = 1.0;

    for (int deg = 0; deg < 360; deg += 15) {
      final rad = deg * math.pi / 180;
      final isMajor = deg % 45 == 0;
      final tickLength = isMajor ? 10.0 : 5.0;
      final outerX = center.dx + (radius - 6) * math.sin(rad);
      final outerY = center.dy - (radius - 6) * math.cos(rad);
      final innerX = center.dx + (radius - 6 - tickLength) * math.sin(rad);
      final innerY = center.dy - (radius - 6 - tickLength) * math.cos(rad);
      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompassDialPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned;
}
