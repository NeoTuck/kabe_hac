import 'package:flutter/material.dart';

import 'progress_store.dart';
import 'travel_catalog.dart';
import 'travel_details.dart';
import 'source_details.dart';
import 'offline_package.dart';
import 'offline_city_map_screen.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({
    super.key,
    required this.store,
    required this.catalog,
    this.packages,
  });

  final ProgressStore store;
  final TravelCatalog catalog;
  final OfflinePackageManager? packages;

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final _searchController = TextEditingController();
  PoiCategory? _category;
  bool _favoritesOnly = false;
  Set<String> _favorites = {};
  String? _error;
  bool _loading = true;
  final _savingFavorites = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      final values = await widget.store.readTravelFavoriteIds('poi');
      if (mounted) {
        setState(() {
          _favorites = values;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Favoriler okunamadı.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFavorite(TravelPoi point) async {
    if (_loading || _savingFavorites.contains(point.id)) return;
    final favorite = !_favorites.contains(point.id);
    setState(() => _savingFavorites.add(point.id));
    try {
      await widget.store.setTravelFavorite('poi', point.id, favorite);
      if (mounted) {
        setState(() {
          if (favorite) {
            _favorites.add(point.id);
          } else {
            _favorites.remove(point.id);
          }
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Favori kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _savingFavorites.remove(point.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visiblePoints = widget.catalog.points
        .where((point) => !point.isTestData)
        .toList();
    final visiblePointIds = visiblePoints.map((point) => point.id).toSet();
    final points = widget.catalog
        .searchPoints(query: _searchController.text, category: _category)
        .where((point) => !point.isTestData)
        .where((p) => !_favoritesOnly || _favorites.contains(p.id))
        .toList();
    final routes = widget.catalog.routes
        .where(
          (route) =>
              !route.isTestData &&
              route.stops.every(
                (stop) =>
                    stop.poiId == null || visiblePointIds.contains(stop.poiId),
              ),
        )
        .toList();
    final header = <Widget>[
      const Card.filled(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Şehir haritalarını Paketler ekranından seçerek indirebilirsin. Yer kayıtları ve indirilen haritalar çevrimdışı kullanılabilir; güncel açık/kapalı durumunu doğrulayın.',
          ),
        ),
      ),
      if (widget.packages != null) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.map_outlined),
          label: const Text('Çevrimdışı haritayı aç'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => OfflineCityMapScreen(
                packages: widget.packages!,
                catalog: widget.catalog,
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Yer ara',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchController.clear()),
                ),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<PoiCategory?>(
        initialValue: _category,
        isExpanded: true,
        itemHeight: null,
        decoration: const InputDecoration(labelText: 'Kategori'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Tümü')),
          for (final value in PoiCategory.values)
            DropdownMenuItem(
              value: value,
              child: Text(
                value.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          label: const Text('Yalnız favoriler'),
          selected: _favoritesOnly,
          onSelected: (value) => setState(() => _favoritesOnly = value),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (_error != null)
        OutlinedButton.icon(
          onPressed: _loading || _savingFavorites.isNotEmpty
              ? null
              : () {
                  setState(() => _loading = true);
                  _loadFavorites();
                },
          icon: const Icon(Icons.refresh),
          label: const Text('Favorileri yeniden dene'),
        ),
      const SizedBox(height: 20),
      Text('Önemli yerler', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (visiblePoints.isEmpty)
        const Text('Doğrulanmış yer bilgisi henüz yüklenmedi.')
      else if (points.isEmpty)
        const Text('Arama ölçütlerine uyan yer yok.'),
    ];
    final footer = <Widget>[
      const SizedBox(height: 24),
      Text('Rotalar', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (routes.isEmpty)
        const Text('Doğrulanmış veya kişisel rota paketi henüz yok.'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Gezi ve önemli yerler')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount:
              header.length + points.length + footer.length + routes.length,
          itemBuilder: (context, index) {
            if (index < header.length) return header[index];
            index -= header.length;
            if (index < points.length) {
              final point = points[index];
              return Card.outlined(
                child: ListTile(
                  title: Text(point.nameTr),
                  onTap: _loading || _savingFavorites.contains(point.id)
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TravelPoiScreen(point: point),
                          ),
                        ),
                  subtitle: Text(
                    '${point.category.label}\n'
                    '${point.isSourceSnapshot ? 'Kaynak tarihi' : 'Doğrulama'}: ${localDateTimeLabel(point.verifiedAt)}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: _favorites.contains(point.id)
                        ? 'Favoriden çıkar'
                        : 'Favoriye ekle',
                    onPressed: _loading || _savingFavorites.contains(point.id)
                        ? null
                        : () => _toggleFavorite(point),
                    icon: Icon(
                      _favorites.contains(point.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                  ),
                ),
              );
            }
            index -= points.length;
            if (index < footer.length) return footer[index];
            index -= footer.length;
            final route = routes[index];
            return Card.outlined(
              child: ListTile(
                title: Text(route.title),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TravelRouteScreen(
                      route: route,
                      catalog: widget.catalog,
                    ),
                  ),
                ),
                subtitle: Text(
                  '${route.stops.length} durak · '
                  '${route.hasRouteGeometry ? 'indirilen rota çizgisi' : 'yalnız durak listesi'}',
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
