import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'local_map_repository.dart';
import 'offline_package.dart';
import 'source_details.dart';
import 'travel_catalog.dart';
import 'travel_repository.dart';
import 'travel_details.dart';
import 'map_place_picker.dart';

class OfflineCityMapScreen extends StatefulWidget {
  const OfflineCityMapScreen({
    super.key,
    required this.packages,
    required this.catalog,
    this.initialPackageId,
    this.onManageMaps,
    this.travelRepository,
    this.mapRepository,
  });
  final OfflinePackageManager packages;
  final TravelCatalog catalog;
  final String? initialPackageId;
  final Future<void> Function()? onManageMaps;
  final LocalTravelRepository? travelRepository;
  final LocalMapRepository? mapRepository;

  @override
  State<OfflineCityMapScreen> createState() => _OfflineCityMapScreenState();
}

class _OfflineCityMapScreenState extends State<OfflineCityMapScreen> {
  late final _repository =
      widget.mapRepository ?? LocalMapRepository(widget.packages);
  List<LocalMapDescriptor> _maps = [];
  LocalMapDescriptor? _selected;
  String? _style;
  String? _error;
  bool _loading = true;
  bool _styleReady = false;
  bool _styleLoaded = false;
  bool _checkingRendered = false;
  bool _checkRenderedAgain = false;
  Size _mapSize = Size.zero;
  int _epoch = 0;
  MapLibreMapController? _controller;
  final _filter = MapPlaceFilter();
  late TravelCatalog _catalog = widget.catalog;
  bool _managingMaps = false;
  bool _placesNeedReload = false;
  bool _filterApplying = false;
  bool _filterPending = false;
  List<TravelPoi> get _points => _catalog.points
      .where((p) => !p.isTestData && p.region == _selected?.region)
      .toList();
  Future<void> _applyFilter() async {
    if (!mounted) return;
    setState(() {});
    _filterPending = true;
    if (_filterApplying || !_styleLoaded || _controller == null) return;
    _filterApplying = true;
    final epoch = _epoch;
    try {
      while (_filterPending && mounted && _styleLoaded && _controller != null) {
        _filterPending = false;
        await _controller!.setFilter('places', _filter.nativeFilter(_points));
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = 'Yer filtresi uygulanamadı. Yeniden dene.');
      }
    } finally {
      _filterApplying = false;
      if (mounted && epoch != _epoch && _styleLoaded && _filterPending) {
        _applyFilter();
      }
    }
  }

  @override
  void dispose() {
    _filter.removeListener(_applyFilter);
    _filter.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filter.addListener(_applyFilter);
    _load();
  }

  Future<void> _load({bool reloadPlaces = false}) async {
    if (reloadPlaces) _placesNeedReload = true;
    final previousPackageId = _selected?.packageId;
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _error = null;
      _maps = [];
      _selected = null;
      _style = null;
      _styleReady = false;
      _styleLoaded = false;
      _controller = null;
    });
    try {
      if (_placesNeedReload) {
        _catalog = LocalTravelRepository.empty;
        final catalog =
            await (widget.travelRepository ??
                    LocalTravelRepository(packages: widget.packages))
                .load();
        if (!mounted || epoch != _epoch) return;
        _catalog = catalog;
        _placesNeedReload = false;
      }
      final maps = await _repository.list();
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _maps = maps;
        _loading = false;
      });
      if (maps.isNotEmpty) {
        await _select(
          maps
                  .where(
                    (map) =>
                        map.packageId ==
                        (previousPackageId ?? widget.initialPackageId),
                  )
                  .firstOrNull ??
              maps.first,
        );
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = 'Harita paketleri okunamadı.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _manageMaps() async {
    if (_managingMaps || widget.onManageMaps == null) return;
    setState(() => _managingMaps = true);
    try {
      await widget.onManageMaps!();
      if (mounted) await _load(reloadPlaces: true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Paket yönetimi açılamadı. Yeniden dene.');
      }
    } finally {
      if (mounted) setState(() => _managingMaps = false);
    }
  }

  Future<void> _select(LocalMapDescriptor map) async {
    final epoch = ++_epoch;
    setState(() {
      _selected = map;
      _loading = true;
      _error = null;
      _style = null;
      _controller = null;
      _styleReady = false;
      _styleLoaded = false;
    });
    try {
      final points = _catalog.points
          .where((p) => p.region == map.region)
          .toList();
      final style = await _repository.loadStyle(map, points);
      if (mounted && epoch == _epoch) {
        setState(() {
          _style = style;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = 'Harita açılamadı. Paketi yeniden indirip deneyebilirsin.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmRendered() async {
    final controller = _controller;
    if (!mounted ||
        !_styleLoaded ||
        _styleReady ||
        controller == null ||
        _mapSize.isEmpty) {
      return;
    }
    if (_checkingRendered) {
      _checkRenderedAgain = true;
      return;
    }
    final epoch = _epoch;
    _checkingRendered = true;
    try {
      final features = await controller.queryRenderedFeaturesInRect(
        Rect.fromLTWH(0, 0, _mapSize.width, _mapSize.height),
        ['roads', 'buildings', 'water'],
        null,
      );
      if (mounted && epoch == _epoch && features.isNotEmpty) {
        setState(() => _styleReady = true);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(
          () => _error = 'Harita görüntüsü hazırlanamadı. Yeniden dene.',
        );
      }
    } finally {
      _checkingRendered = false;
      if (_checkRenderedAgain) {
        _checkRenderedAgain = false;
        _confirmRendered();
      }
    }
  }

  Future<void> _places() async {
    final map = _selected;
    if (map == null) return;
    final points = _catalog.points
        .where((p) => !p.isTestData && p.region == map.region)
        .toList();
    final chosen = await showModalBottomSheet<TravelPoi>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MapPlacePicker(points: points, filter: _filter),
    );
    if (chosen == null || !mounted || map != _selected) return;
    try {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(chosen.point.latitude, chosen.point.longitude),
          16,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Harita konumu değiştirilemedi. Yeniden deneyebilirsin.',
          ),
        ),
      );
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chosen.nameTr),
          action: SnackBarAction(
            label: 'Ayrıntı',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => TravelPoiScreen(point: chosen)),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      appBar: AppBar(title: const Text('Çevrimdışı şehir haritası')),
      body: SafeArea(
        child: Column(
          children: [
            if (_maps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<LocalMapDescriptor>(
                        isExpanded: true,
                        value: selected,
                        items: [
                          for (final map in _maps)
                            DropdownMenuItem(
                              value: map,
                              child: Text(
                                map.region == TravelRegion.mecca
                                    ? 'Mekke ve hac durakları'
                                    : 'Medine',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) _select(value);
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: 'Haritada yer bul',
                      onPressed: _styleReady ? _places : null,
                      icon: const Icon(Icons.search),
                    ),
                  ],
                ),
              ),
            if (selected != null && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      '${_filter.apply(_points).length} yer${_filter.category == null ? '' : ' · ${_filter.category!.label}'}',
                    ),
                    if (_filter.query.isNotEmpty)
                      Text('Arama: ${_filter.query}'),
                    if (_filter.query.isNotEmpty || _filter.category != null)
                      TextButton(
                        onPressed: _filter.clear,
                        child: const Text('Filtreleri temizle'),
                      ),
                    if (_filter.apply(_points).isEmpty)
                      const Text(
                        'Eşleşen yer yok. Filtreleri temizleyerek tüm yerleri göster.',
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => selected == null
                                  ? _load()
                                  : _select(selected),
                              child: const Text('Yeniden dene'),
                            ),
                            if (widget.onManageMaps != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _managingMaps ? null : _manageMaps,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Harita paketlerini yönet'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : _style == null || selected == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Bu cihazda şehir haritası kurulu değil. Mekke veya Medine haritasını indirip burada çevrimdışı açabilirsin.',
                              textAlign: TextAlign.center,
                            ),
                            if (widget.onManageMaps != null) ...[
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _managingMaps ? null : _manageMaps,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Harita paketlerini yönet'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        _mapSize = constraints.biggest;
                        return MapLibreMap(
                          key: ValueKey(
                            '${selected.packageId}/${selected.version}',
                          ),
                          styleString: _style!,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              selected.centerLatitude,
                              selected.centerLongitude,
                            ),
                            zoom: 14,
                          ),
                          onMapCreated: (controller) =>
                              _controller = controller,
                          onStyleLoadedCallback: () {
                            if (mounted && selected == _selected) {
                              _styleLoaded = true;
                              _applyFilter();
                              _confirmRendered();
                            }
                          },
                          onMapIdle: _confirmRendered,
                          myLocationEnabled: false,
                          cameraTargetBounds: CameraTargetBounds(
                            LatLngBounds(
                              southwest: LatLng(selected.south, selected.west),
                              northeast: LatLng(selected.north, selected.east),
                            ),
                          ),
                          compassEnabled: true,
                          minMaxZoomPreference: const MinMaxZoomPreference(
                            10,
                            18,
                          ),
                        );
                      },
                    ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_styleReady) const Text('Harita hazır · Çevrimdışı'),
                    Text(
                      selected.attribution,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'Kaynak: ${localDateTimeLabel(selected.snapshotAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Text(
                      'Yol ve bina kaydıdır; canlı yoğunluk, açık kapı veya güvenli yürüme rotası göstermez.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
