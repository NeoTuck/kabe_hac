import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';

class PrayerItem {
  const PrayerItem({
    required this.id,
    required this.title,
    required this.category,
    required this.arabic,
    required this.transliteration,
    required this.meaning,
    this.recommendedCount = 1,
  });

  final String id;
  final String title;
  final String category;
  final String arabic;
  final String transliteration;
  final String meaning;
  final int recommendedCount;
}

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> {
  String _selectedCategory = 'Tümü';
  final Map<String, int> _counters = {};

  static const List<PrayerItem> _allPrayers = [
    PrayerItem(
      id: 'p1',
      title: 'İhram ve Umre Niyeti',
      category: 'İhram & Niyet',
      arabic: 'اللَّهُمَّ إِنِّي أُرِيدُ الْعُمْرَةَ فَيَسِّرْهَا لِي وَتَقَبَّلْهَا مِنِّي',
      transliteration:
          'Allahümme innî ürîdü\'l-umrate feyessirhâ lî ve tekabbelhâ minnî.',
      meaning: 'Allah\'ım! Senin rızan için Umre yapmak istiyorum. Onu bana kolaylaştır ve benden kabul buyur.',
      recommendedCount: 1,
    ),
    PrayerItem(
      id: 'p2',
      title: 'Telbiye Duası',
      category: 'İhram & Niyet',
      arabic: 'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لاَ شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لاَ شَرِيكَ لَكَ',
      transliteration: 'Lebbeyk Allāhümme lebbeyk. Lebbeyke lâ şerîke leke lebbeyk. İnne\'l-hamde ve\'n-ni\'mete leke ve\'l-mülk, lâ şerîke lek.',
      meaning: 'Buyur Allah\'ım buyur! Davetine icabet ettim. Senin hiçbir ortağın yoktur. Hamd ve nimet sana aittir, mülk de senindir. Senin ortağın yoktur.',
      recommendedCount: 3,
    ),
    PrayerItem(
      id: 'p3',
      title: 'Kâbe\'yi İlk Görünce Okunacak Dua',
      category: 'Kâbe & Tavaf',
      arabic: 'اللَّهُمَّ زِدْ هَذَا الْبَيْتَ تَشْرِيفاً وَتَعْظِيماً وَتَكْرِيماً وَمَهَابَةً، وَزِدْ مَنْ شَرَّفَهُ وَعَظَّمَهُ مِمَّنْ حَجَّهُ أَوِ اعْتَمَرَهُ تَشْرِيفاً وَتَكْرِيماً وَتَعْظِيماً وَبِرّاً',
      transliteration: 'Allāhümme zid hâze\'l-beyte teşrîfen ve ta\'zîmen ve tekrîmen ve mehâbeten. Ve zid men şerrefekû ve azzamehû mimmen haccehû evi\'temerahû teşrîfen ve tekrîmen ve ta\'zîmen ve birrâ.',
      meaning: 'Allah\'ım! Bu Beyt\'in şerefini, azametini, hürmetini ve heybetini artır. Onu hac ve umre ile yüceltenlerin de şeref ve mükâfatını artır.',
      recommendedCount: 1,
    ),
    PrayerItem(
      id: 'p4',
      title: 'Hacerü\'l-Esved Selamı (İstislâm)',
      category: 'Kâbe & Tavaf',
      arabic: 'بِسْمِ اللَّهِ وَاللَّهُ أَكْبَرُ',
      transliteration: 'Bismillâhi va\'llâhu ekber.',
      meaning: 'Allah\'ın adıyla başlarım, Allah en büyüktür.',
      recommendedCount: 7,
    ),
    PrayerItem(
      id: 'p5',
      title: 'Rükün-i Yemânî ile Hacerü\'l-Esved Arası (Rabbenâ)',
      category: 'Kâbe & Tavaf',
      arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      transliteration: 'Rabbenâ âtinâ fi\'d-dünyâ haseneten ve fi\'l-âhirati haseneten ve kınâ azâbe\'n-nâr.',
      meaning: 'Rabbimiz! Bize dünyada da iyilik ve güzellik ver, ahirette de iyilik ver ve bizi cehennem ateşinden koru.',
      recommendedCount: 7,
    ),
    PrayerItem(
      id: 'p6',
      title: 'Safa ve Merve Tepesi Başlangıç Duası',
      category: 'Sa\'y İbadeti',
      arabic: 'إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ ۖ فَمَنْ حَجَّ الْبَيْتَ أَوِ اعْتَمَرَ فَلَا جُنَاحَ عَلَيْهِ أَنْ يَطَّوَّفَ بِهِمَا',
      transliteration: 'İnne\'s-Safâ ve\'l-Mervete min şe\'â\'irillâh. Femen hacce\'l-beyte evi\'temera felâ cünâha aleyhi en yettavvefe bihimâ.',
      meaning: 'Şüphesiz Safa ile Merve Allah\'ın ibadet nişanelerindendir. Kim hac veya umre yaparsa o ikisini tavaf etmesinde bir sakınca yoktur.',
      recommendedCount: 7,
    ),
    PrayerItem(
      id: 'p7',
      title: 'Arafat Vakfe Zikri',
      category: 'Arafat & Hac',
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
      transliteration: 'Lâ ilâhe illallāhu vahdehû lâ şerîke leh, lehü\'l-mülkü ve lehü\'l-hamdü ve hüve alâ külli şey\'in kadîr.',
      meaning: 'Allah\'tan başka ilah yoktur; O tektir, ortağı yoktur. Mülk O\'nundur, hamd O\'na mahsustur. O her şeye kadirdir.',
      recommendedCount: 100,
    ),
    PrayerItem(
      id: 'p8',
      title: 'Mültezem ve Kâbe Kapısı Yanı Duası',
      category: 'Kâbe & Tavaf',
      arabic: 'اللَّهُمَّ لَكَ الْحَمْدُ حَمْداً يُوَافِي نِعَمَكَ وَيُكَافِئُ مَزِيدَكَ، أَحْمَدُكَ بِجَمِيعِ مَحَامِدِكَ',
      transliteration: 'Allāhümme leke\'l-hamdü hamden yüvâfî ni\'ameke ve yükâfiü mezîdek. Ahmedüke bi-cemî\'i mehâmidik.',
      meaning: 'Allah\'ım! Nimetlerine denk ve lütfunu karşılayacak şekilde sana hamdolsun. Bütün övgülerimle sana şükrederim.',
      recommendedCount: 3,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final categories = [
      'Tümü',
      'İhram & Niyet',
      'Kâbe & Tavaf',
      'Sa\'y İbadeti',
      'Arafat & Hac',
    ];

    final filteredPrayers = _selectedCategory == 'Tümü'
        ? _allPrayers
        : _allPrayers.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Hac ve Umre Duaları')),
      body: SafeArea(
        child: Column(
          children: [
            // Category filter pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  for (final cat in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat),
                      ),
                    ),
                ],
              ),
            ),

            // Prayer List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                itemCount: filteredPrayers.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, i) {
                  final item = filteredPrayers[i];
                  final count = _counters[item.id] ?? 0;

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
                          // Header: Title & Category badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: RehberTheme.gold.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.category,
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

                          // Arabic Text Box
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
                              item.arabic,
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

                          // Transliteration (Okunuş)
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
                            item.transliteration,
                            style: const TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Meaning (Meal)
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
                            item.meaning,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: dark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Action bar: Dhikr counter & Copy
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Copy text button
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                tooltip: 'Duayı Kopyala',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                          '${item.title}\n\n${item.arabic}\n\nOkunuşu: ${item.transliteration}\n\nAnlamı: ${item.meaning}',
                                    ),
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
                                      onPressed: () => setState(
                                        () => _counters[item.id] = 0,
                                      ),
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
                                      count == 0
                                          ? 'Zikir Sayacı (${item.recommendedCount}x)'
                                          : 'Okundu: $count / ${item.recommendedCount}',
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
          ],
        ),
      ),
    );
  }
}
