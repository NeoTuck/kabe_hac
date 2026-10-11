import 'package:flutter/material.dart';

import 'travel_catalog.dart';

class MapPlaceFilter extends ChangeNotifier {
  String query = '';
  PoiCategory? category;
  void update({required String query, required PoiCategory? category}) {
    this.query = query;
    this.category = category;
    notifyListeners();
  }

  void clear() => update(query: '', category: null);
  List<TravelPoi> apply(Iterable<TravelPoi> points) => searchTravelPoints(
    points.where((point) => !point.isTestData),
    query: query,
    category: category,
  );
  // The native layer uses the exact same IDs as the list, including search.
  List<Object> nativeFilter(Iterable<TravelPoi> points) => [
    'in',
    ['get', 'id'],
    ['literal', apply(points).map((p) => p.id).toList()],
  ];
}

class MapPlacePicker extends StatefulWidget {
  const MapPlacePicker({super.key, required this.points, this.filter});
  final MapPlaceFilter? filter;
  final List<TravelPoi> points;

  @override
  State<MapPlacePicker> createState() => _MapPlacePickerState();
}

class _MapPlacePickerState extends State<MapPlacePicker> {
  late final _filter = widget.filter ?? MapPlaceFilter();
  late final _search = TextEditingController(text: _filter.query);
  PoiCategory? get _category => _filter.category;
  void _update() {
    _filter.update(query: _search.text, category: _category);
    setState(() {});
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.filter == null) _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = _filter.apply(widget.points);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: (media.size.height - media.viewInsets.bottom) * 0.75,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Haritada yer bul',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      decoration: InputDecoration(
                        labelText: 'Yer ara',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Aramayı temizle',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _search.clear();
                                  _update();
                                },
                              ),
                      ),
                      onChanged: (_) => _update(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PoiCategory>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Yer türü'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Tüm yerler'),
                        ),
                        for (final category in PoiCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        _filter.update(query: _search.text, category: value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('${values.length} yer · Çevrimdışı arama'),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Filtreyi haritada göster'),
                    ),
                    if (values.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          'Eşleşen yer yok. Aramayı veya yer türünü değiştir.',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverList.builder(
              itemCount: values.length,
              itemBuilder: (context, index) {
                final point = values[index];
                return ListTile(
                  title: Text(point.nameTr),
                  subtitle: Text(point.category.label),
                  onTap: () => Navigator.of(context).pop(point),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
