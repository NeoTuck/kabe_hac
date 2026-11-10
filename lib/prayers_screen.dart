import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'guide_catalog.dart';

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key, this.catalog});

  final GuideCatalog? catalog;

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  final Map<String, int> _counters = {};

  List<PrayerRecord> get _prayers {
    final cat = widget.catalog;
    if (cat == null) return const [];
    if (cat.isPreview) {
      return cat.prayerRecords.values.toList();
    }
    return cat.prayerRecords.values.where((p) => p.isApproved).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final prayers = _prayers;

    if (prayers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hac ve Umre Duaları')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 64,
                  color: dark ? Colors.white38 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  'Onaylı dua kaydı henüz bulunmuyor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : RehberTheme.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Dua metinleri dinî inceleme ve onay tamamlandığında sunulacak. Önceki kişisel kayıtların cihazda korunur.',
                  style: TextStyle(
                    fontSize: 13,
                    color: dark ? Colors.white70 : Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hac ve Umre Duaları')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: prayers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final item = prayers[i];
            final count = _counters[item.id] ?? 0;
            final title = item.sourceReference ?? item.id;

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: dark
                      ? Colors.white12
                      : Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: Title & status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!item.isApproved)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Taslak İnceleme',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (item.sourceTitle != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: RehberTheme.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.sourceTitle!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: RehberTheme.goldLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Arabic Text Box (if available)
                    if (item.arabic != null && item.arabic!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: dark
                              ? const Color(0xFF162520)
                              : const Color(0xFFF3F7F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: RehberTheme.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          item.arabic!,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            fontFamily: 'NotoNaskhArabic',
                            fontSize: 20,
                            height: 1.7,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Transliteration (Okunuş)
                    if (item.transliteration != null &&
                        item.transliteration!.isNotEmpty) ...[
                      const Text(
                        'Türkçe Okunuşu:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.transliteration!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Meaning (Meal)
                    if (item.meaningTr != null &&
                        item.meaningTr!.isNotEmpty) ...[
                      const Text(
                        'Anlamı:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.meaningTr!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: dark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Action bar: Dhikr counter & Copy
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Copy text button
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          tooltip: 'Duayı Kopyala',
                          onPressed: () {
                            final textBuf = StringBuffer(title);
                            if (item.arabic != null) {
                              textBuf.write('\n\n${item.arabic}');
                            }
                            if (item.transliteration != null) {
                              textBuf.write(
                                '\n\nOkunuşu: ${item.transliteration}',
                              );
                            }
                            if (item.meaningTr != null) {
                              textBuf.write('\n\nAnlamı: ${item.meaningTr}');
                            }
                            Clipboard.setData(
                              ClipboardData(text: textBuf.toString()),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dua panoya kopyalandı.'),
                              ),
                            );
                          },
                        ),

                        // Interactive Dhikr Counter
                        Row(
                          children: [
                            if (count > 0)
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                tooltip: 'Sıfırla',
                                onPressed: () =>
                                    setState(() => _counters[item.id] = 0),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: () {
                                setState(() {
                                  _counters[item.id] = count + 1;
                                });
                              },
                              icon: const Icon(
                                Icons.touch_app_rounded,
                                size: 18,
                              ),
                              label: Text(
                                count == 0 ? 'Zikir Sayacı' : 'Okundu: $count',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
