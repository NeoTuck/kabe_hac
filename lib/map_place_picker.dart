import 'package:flutter/material.dart';

import 'travel_catalog.dart';

class MapPlacePicker extends StatefulWidget {
  const MapPlacePicker({super.key, required this.points});
  final List<TravelPoi> points;

  @override
  State<MapPlacePicker> createState() => _MapPlacePickerState();
}

class _MapPlacePickerState extends State<MapPlacePicker> {
  final _search = TextEditingController();
  PoiCategory? _category;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = searchTravelPoints(
      widget.points.where((point) => !point.isTestData),
      query: _search.text,
      category: _category,
    );
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
                                onPressed: () => setState(_search.clear),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
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
                      onChanged: (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 12),
                    Text('${values.length} yer · Çevrimdışı arama'),
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
