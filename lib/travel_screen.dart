import 'package:flutter/material.dart';

import 'progress_store.dart';
import 'travel_catalog.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key, required this.store, required this.catalog});

  final ProgressStore store;
  final TravelCatalog catalog;

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final _searchController = TextEditingController();
  PoiCategory? _category;
  Set<String> _favorites = {};
  String? _error;

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
      if (mounted) setState(() => _favorites = values);
    } catch (_) {
      if (mounted) setState(() => _error = 'Favoriler okunamadı.');
    }
  }

  Future<void> _toggleFavorite(TravelPoi point) async {
    final favorite = !_favorites.contains(point.id);
    try {
      await widget.store.setTravelFavorite('poi', point.id, favorite);
      await _loadFavorites();
    } catch (_) {
      if (mounted) setState(() => _error = 'Favori kaydedilemedi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.catalog.searchPoints(
      query: _searchController.text,
      category: _category,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Gezi ve önemli yerler')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card.filled(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Üretim harita sağlayıcısı ve izinli Mekke/Medine bölge paketi henüz seçilmedi. Kamusal OSM tile sunucularından şehir paketi indirilmeyecek.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Yer ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PoiCategory?>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Tümü')),
                for (final value in PoiCategory.values)
                  DropdownMenuItem(value: value, child: Text(value.label)),
              ],
              onChanged: (value) => setState(() => _category = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Önemli yerler',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (widget.catalog.points.isEmpty)
              const Text(
                'Kaynağı ve doğrulama tarihi bulunan gerçek POI paketi henüz yüklenmedi.',
              )
            else if (points.isEmpty)
              const Text('Arama ölçütlerine uyan yer yok.')
            else
              for (final point in points)
                Card.outlined(
                  child: ListTile(
                    title: Text(point.nameTr),
                    subtitle: Text(
                      '${point.category.label}\n'
                      '${point.isTestData ? 'TEKNİK TEST VERİSİ · ' : ''}'
                      'Doğrulama: ${point.verifiedAt.toLocal()}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: _favorites.contains(point.id)
                          ? 'Favoriden çıkar'
                          : 'Favoriye ekle',
                      onPressed: () => _toggleFavorite(point),
                      icon: Icon(
                        _favorites.contains(point.id)
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Text('Rotalar', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.catalog.routes.isEmpty)
              const Text('Doğrulanmış veya kişisel rota paketi henüz yok.')
            else
              for (final route in widget.catalog.routes)
                Card.outlined(
                  child: ListTile(
                    title: Text(route.title),
                    subtitle: Text(
                      '${route.stops.length} durak · '
                      '${route.hasRouteGeometry ? 'indirilen rota çizgisi' : 'yalnız durak listesi'}'
                      '${route.isTestData ? ' · TEKNİK TEST VERİSİ' : ''}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
