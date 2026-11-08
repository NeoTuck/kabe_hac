import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'offline_city_map_screen.dart';
import 'offline_package.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';

class RouteStudioScreen extends StatefulWidget {
  const RouteStudioScreen({
    super.key,
    required this.catalog,
    this.packages,
    this.travelRepository,
    this.onManagePackages,
    this.isTab = false,
  });

  final TravelCatalog catalog;
  final OfflinePackageManager? packages;
  final LocalTravelRepository? travelRepository;
  final Future<void> Function(OfflinePackageKind kind)? onManagePackages;
  final bool isTab;

  @override
  State<RouteStudioScreen> createState() => _RouteStudioScreenState();
}

class _RouteStudioScreenState extends State<RouteStudioScreen> {
  String _hotelName = 'Mekke Towers Oteli';
  String _hotelDist = '750 m · 10 dk yürüme';

  final List<Map<String, String>> _customRoutes = [
    {
      'title': 'Otelimden Kâbe Kral Abdülaziz Kapısına',
      'distance': '850 m',
      'duration': '12 dk yürüme',
    },
    {
      'title': 'Mescid-i Nebevi Cennet Bahçesi (Ravza)',
      'distance': '400 m',
      'duration': '6 dk yürüme',
    },
  ];

  void _showHotelDialog() {
    final ctrl = TextEditingController(text: _hotelName);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.hotel_rounded, color: RehberTheme.ink),
            SizedBox(width: 8),
            Text('Otelimi Kaydet'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kaldığınız otelin adını yazın veya mevcut GPS konumunuzu kaydedin. Kâbe’den çıkınca tek tıkla otelinize yol tarifi alabilirsiniz.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Otel Adı / Oda No',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() {
                  _hotelName = ctrl.text.trim();
                  _hotelDist = 'Mevcut konumdan rota hesaplandı';
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '"${ctrl.text.trim()}" oteliniz olarak kaydedildi.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _openMap() {
    if (widget.packages != null) {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => OfflineCityMapScreen(
            packages: widget.packages!,
            catalog: widget.catalog,
            travelRepository: widget.travelRepository,
            onManageMaps: widget.onManagePackages == null
                ? null
                : () => widget.onManagePackages!(OfflinePackageKind.map),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita paketleri henüz kurulu değil.')),
      );
    }
  }

  void _showCreateRouteDialog() {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: 'Kaldığım Otel');
    final endCtrl = TextEditingController(text: 'Kâbe Babü’s-Selam Kapısı');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_road_rounded, color: RehberTheme.ink),
            SizedBox(width: 10),
            Text('Yeni Rota Oluştur'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nereden nereye gitmek istediğinizi yazın veya haritadan çizin. Oluşturulan rota telefonunuza kaydedilecektir.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Rota İsmi (Örn: Sabah Tavafı Yolu)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: 'Başlangıç Noktası',
                  prefixIcon: Icon(Icons.my_location_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: 'Varış Noktası',
                  prefixIcon: Icon(Icons.location_on_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () {
              final title = nameCtrl.text.trim();
              if (title.isNotEmpty) {
                setState(() {
                  _customRoutes.add({
                    'title': title,
                    'distance': '1.2 km',
                    'duration': '16 dk yürüme',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$title" rotası kaydedildi.')),
                );
              }
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Rotayı Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showMyRoutesSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bookmark_added_rounded,
                    color: RehberTheme.ink,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Rotalarım (${_customRoutes.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_customRoutes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Henüz kaydedilmiş rotanız yok.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _customRoutes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = _customRoutes[i];
                      return Card.outlined(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFD6E4E2),
                            child: Icon(
                              Icons.directions_walk_rounded,
                              color: RehberTheme.ink,
                            ),
                          ),
                          title: Text(
                            item['title']!,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${item['distance']} · ${item['duration']}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                            ),
                            onPressed: () {
                              setState(() => _customRoutes.removeAt(i));
                              setSheetState(() {});
                            },
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openMap();
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommunityRoutesSheet() {
    final communityRoutes = [
      {
        'title': 'Kâbe Tavaf & Çevre Yürüyüşü',
        'info': '1.2 km · 25 dk · Kolay',
        'desc':
            'Harem çevresi geniş tavaf avlusu ve kapılar arası bağlantı yolu.',
      },
      {
        'title': 'Cebel-i Nur & Hira Mağarası Tırmanışı',
        'info': '3.8 km · 1 sa 40 dk · Dik/Orta',
        'desc':
            'İlk vahyin geldiği Hira Mağarasına basamaklı tırmanış parkuru.',
      },
      {
        'title': 'Sevr Mağarası Ziyaret Parkuru',
        'info': '4.2 km · 2 saat · Zorlu',
        'desc': 'Hicret yolculuğunun başlangıç noktası tarihi Sevr Dağı yolu.',
      },
      {
        'title': 'Cennetü’l-Muallâ Kabristanı Rotası',
        'info': '2.0 km · 30 dk · Düz/Kolay',
        'desc': 'Hz. Hatice validemizin kabrinin bulunduğu tarihi mezarlık güzergahı.',
      },
      {
        'title': 'Mescid-i Nebevi → Kuba Yürüyüş Sünnet Yolu',
        'info': '3.5 km · 45 dk · Düz/Rahat',
        'desc': 'Peygamber Efendimiz’in (s.a.v) yürüdüğü sünnet yürüyüş yolu.',
      },
      {
        'title': 'Uhud Şehitliği ve Okçular Tepesi',
        'info': '2.8 km · 35 dk · Düz/Kolay',
        'desc': 'Hz. Hamza ve Uhud şehitlerinin ziyaret güzergahı.',
      },
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.explore_rounded, color: RehberTheme.ink),
                  const SizedBox(width: 10),
                  const Text(
                    'Mevcut Rotalarda Gezin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  itemCount: communityRoutes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = communityRoutes[i];
                    return Card.outlined(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8F3EE),
                          child: Icon(
                            Icons.alt_route_rounded,
                            color: RehberTheme.ink,
                          ),
                        ),
                        title: Text(
                          item['title']!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              item['info']!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['desc']!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _openMap();
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockupCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
      ),
      color: color ?? const Color(0xFFD6E4E2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF133F3B), size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF133F3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF133F3B).withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF133F3B)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rota & Keşif'),
        automaticallyImplyLeading: !widget.isTab,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Otelim & Beni Otele Götür Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF133F3B), Color(0xFF1E5E57)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: RehberTheme.goldLight.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.hotel_rounded,
                        color: RehberTheme.goldLight,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KAYITLI OTELİM',
                            style: TextStyle(
                              color: RehberTheme.goldLight,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _hotelName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _hotelDist,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_location_alt_rounded,
                        color: Colors.white70,
                      ),
                      tooltip: 'Oteli Güncelle',
                      onPressed: _showHotelDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: RehberTheme.goldLight,
                    foregroundColor: const Color(0xFF133F3B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$_hotelName rotası haritada açılıyor…'),
                      ),
                    );
                    _openMap();
                  },
                  icon: const Icon(Icons.navigation_rounded),
                  label: const Text(
                    'Beni Otele Götür (Harita & Rota)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4 Mockup Cards Matching Layout Page 3
          _buildMockupCard(
            title: 'rota oluştur +',
            subtitle: 'Haritadan çiz veya nokta yazarak özel rota kaydet',
            icon: Icons.add_location_alt_rounded,
            onTap: _showCreateRouteDialog,
          ),
          const SizedBox(height: 14),

          _buildMockupCard(
            title: 'rotalarım',
            subtitle: 'Kayıtlı ${_customRoutes.length} kişisel yürüyüş rotan',
            icon: Icons.bookmark_added_rounded,
            onTap: _showMyRoutesSheet,
          ),
          const SizedBox(height: 14),

          _buildMockupCard(
            title: 'mevcut rotalarda gezin',
            subtitle: 'Hira, Sevr, Kuba ve kutsal mekan popüler rotaları',
            icon: Icons.explore_rounded,
            onTap: _showCommunityRoutesSheet,
          ),
          const SizedBox(height: 14),

          _buildMockupCard(
            title: 'haritada gezin',
            subtitle: 'Mekke ve Medine çevrimdışı vektör haritasını aç',
            icon: Icons.map_rounded,
            onTap: _openMap,
          ),
          if (widget.catalog.points.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Kayıtlı Yerler ve Noktalar (${widget.catalog.points.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final point in widget.catalog.points)
              Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.place_rounded, color: RehberTheme.ink),
                  title: Text(point.nameTr),
                  subtitle: Text(point.category.label),
                  onTap: _openMap,
                ),
              ),
          ],
          const SizedBox(height: 24),

          // Bottom Quick Card ("alttaki yeşilimsi yerde ayarların felan olduğu yer")
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC8E6C9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF81C784)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF1B5E20)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Harita & Paket Ayarları',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        'Çevrimdışı harita paketlerini ve doğrulama durumunu incele',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onManagePackages != null)
                  TextButton(
                    onPressed: () =>
                        widget.onManagePackages!(OfflinePackageKind.travel),
                    child: const Text('Yönet'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
