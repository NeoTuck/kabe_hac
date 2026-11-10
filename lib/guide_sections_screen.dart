import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'counter_screen.dart';
import 'guide_catalog.dart';
import 'guide_stage_animator.dart';
import 'narration_service.dart';
import 'progress_store.dart';

class GuideSectionItem {
  const GuideSectionItem({
    required this.title,
    required this.summary,
    this.audioAsset,
    this.audioTitle,
    this.counterKey,
    this.checklist = const [],
    this.substeps = const [],
  });

  final String title;
  final String summary;
  final String? audioAsset;
  final String? audioTitle;
  final String? counterKey;
  final List<String> checklist;
  final List<String> substeps;
}

class GuideSection {
  const GuideSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    this.stageType = GuideStageType.luggage,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<GuideSectionItem> items;
  final GuideStageType stageType;
}

class GuideSectionsScreen extends StatefulWidget {
  const GuideSectionsScreen({
    super.key,
    required this.type,
    required this.store,
    required this.narration,
    this.catalog,
  });

  final GuideType type;
  final ProgressStore store;
  final NarrationService narration;
  final GuideCatalog? catalog;

  @override
  State<GuideSectionsScreen> createState() => _GuideSectionsScreenState();
}

class _GuideSectionsScreenState extends State<GuideSectionsScreen> {
  final Set<String> _checkedItems = {};
  final Map<int, int> _activeItemBySection = {};
  int _activeSessionId = 1;

  late final List<GuideSection> _sections = widget.type == GuideType.umrah
      ? _buildUmrahSections()
      : _buildHajjSections();

  @override
  void initState() {
    super.initState();
    _loadSession();
    widget.narration.addListener(_onNarrationUpdate);
  }

  @override
  void dispose() {
    widget.narration.removeListener(_onNarrationUpdate);
    super.dispose();
  }

  void _onNarrationUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSession() async {
    try {
      final existing = await widget.store.readMostRecentSession();
      final session = (existing != null && existing.type == widget.type)
          ? existing
          : await widget.store.openOrCreateSession(
              type: widget.type,
              mode: GuideMode.learning,
              profile: null,
              firstStepId: widget.type == GuideType.umrah ? 'U01.1' : 'H01.1',
              contentVersion: widget.catalog?.contentVersion ?? 'v1',
            );
      if (mounted) {
        setState(() => _activeSessionId = session.id);
        final marked = await widget.store.readMarkedStepIds(session.id);
        if (mounted) {
          setState(() {
            _checkedItems.addAll(marked);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleCheck(String check) async {
    final isChecked = !_checkedItems.contains(check);
    setState(() {
      if (isChecked) {
        _checkedItems.add(check);
      } else {
        _checkedItems.remove(check);
      }
    });
    try {
      await widget.store.setStepMarked(_activeSessionId, check, isChecked);
    } catch (_) {}
  }

  List<GuideSection> _buildUmrahSections() {
    return [
      const GuideSection(
        number: 1,
        title: 'Bölüm 1: Valiz & Hazırlık Eşyaları',
        subtitle: 'Diyanet ve fıkıh standartlarında eksiksiz eşya listesi',
        icon: Icons.luggage_outlined,
        stageType: GuideStageType.luggage,
        items: [
          GuideSectionItem(
            title: 'Valiz Kontrol Listesi',
            summary: 'Eşyalar üstteki sahnede valize yerleşir; alttaki listeden kontrol edip işaretleyebilirsiniz.',
            audioAsset: 'assets/audio/review-male-v1/A-U01.1-TR-01.m4a',
            audioTitle: 'Valiz ve Hazırlık Rehberi',
            checklist: [
              '2 parça dikişsiz ihram kumaşı ve cepli emniyetli kemer',
              'Kokusuz sabun, şampuan ve pişik kremi (İhram fıkhı şartı)',
              'Rahat ortopedik sandalet ve kaymaz tabanlı tavaf patiği',
              'Mescid-i Harâm ve Nebevî için bez ayakkabı torbası',
              'Düzenli kullanılan reçeteli ilaçlar ve ilk yardım kiti',
              'Boyun askılı güvenli pasaport ve para cüzdanı',
              'Küçük boy dua kitabı ve dijital yüzük zikirmatik',
              'İhramdan çıkış tıraşı için küçük makas ve tırnak makası',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 2,
        title: 'Bölüm 2: Mîkāt & İhram Kuralları',
        subtitle: 'Mîkāt sınırları, ihram kuralları ve yasaklar',
        icon: Icons.menu_book_rounded,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            title: 'İhrama Giriş ve Yasaklar',
            summary: 'Mîkāt sınırında boy abdesti alınır, niyet edilir ve telbiye getirilir.',
            audioAsset: 'assets/audio/review-male-v1/A-U01.2-TR-01.m4a',
            audioTitle: 'İhram Kuralları ve Telbiye Anlatımı',
            substeps: [
              'Boy abdesti (gusül) alınıp 2 rekat ihram namazı kılınır.',
              'Mîkāt sınırını ihramsız geçmek caiz değildir (kurban cezası gerekir).',
              'Niyet: "Allah\'ım senin rızan için Umre yapmak istiyorum..."',
              'Telbiye: "Lebbeyk Allahümme lebbeyk, lebbeyke lâ şerîke leke lebbeyk..."',
              'İhramlıyken koku sürünmek, dikişli giysi/çorap giymek (erkekler) ve kıl kesmek yasaktır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 3,
        title: 'Bölüm 3: Kâbe’ye Varış & Canlı Tavaf',
        subtitle: 'Mescid-i Harâm adabı, 7 şavt ve dualar',
        icon: Icons.mosque_outlined,
        stageType: GuideStageType.tawaf,
        items: [
          GuideSectionItem(
            title: 'Tavaf İbadeti',
            summary: 'Hacerü’l-Esved hizasından başlanarak Kâbe etrafında 7 şavt tamamlanır.',
            audioAsset: 'assets/audio/review-male-v1/A-U04.1-TR-01.m4a',
            audioTitle: 'Tavaf Duaları ve Şavt Rehberi',
            counterKey: 'tawaf',
            substeps: [
              '1. Şavt: Hacerü’l-Esved yeşil ışık hizasından niyet ve istimlâm ile başlanır.',
              '2. Şavt: Kâbe sol omuzda kalacak şekilde saat yönünün tersine vakarla dönülür.',
              '3. Şavt: Hatîm’in (Hicr-i İsmail) dışından geçilir; içinden geçilmez.',
              '4. Şavt: Rükn-i Yemânî ile Hacerü’l-Esved arasında Rabbenâ âtinâ duası okunur.',
              '5. – 7. Şavt: İstiğfar, zikir ve dualarla 7 şavt tamamlanır.',
              'Tavaf Namazı: Makam-ı İbrahim arkasında veya uygun bir yerde 2 rekat namaz kılınır.',
              'Zemzem İkramı: Kana kana zemzem içilir ve dua edilir.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 4,
        title: 'Bölüm 4: Safâ ve Merve Sa‘y Yolu',
        subtitle: 'Safâ tepesinden Merve’ye 7 tur yürüyüş',
        icon: Icons.directions_walk_rounded,
        stageType: GuideStageType.say,
        items: [
          GuideSectionItem(
            title: 'Safâ ve Merve Arasında Sa‘y',
            summary:
                'Safâ’dan Merve’ye 4 gidiş, Merve’den Safâ’ya 3 dönüş yapılır.',
            audioAsset: 'assets/audio/review-male-v1/A-U06.1-TR-01.m4a',
            audioTitle: 'Sa‘y İbadeti ve Duaları',
            counterKey: 'say',
            substeps: [
              '1. Tur: Safâ tepesinde Kâbe’ye dönülüp niyet ve tekbir getirilir.',
              'Hervele Sünneti: İki yeşil floresan ışık arasında erkekler hızlı adımlarla yürür.',
              '2. Tur: Merve tepesinde dua edilip Safâ’ya doğru dönülür.',
              '3. – 6. Tur: Safâ ve Merve arasında dualarla yürüyüş sürdürülür.',
              '7. Tur (Bitiş): Merve tepesinde 7. tur ile Sa‘y ibadeti tamamlanır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 5,
        title: 'Bölüm 5: Tıraş ve İhramdan Çıkış (Tahallül)',
        subtitle: 'Saç kesimi ile umrenin tamamlanması',
        icon: Icons.content_cut_rounded,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            title: 'Tahallül (İhramdan Çıkış)',
            summary: 'Erkekler saçlarını kazıtır veya kısaltır, kadınlar parmak ucu kadar keser.',
            audioAsset: 'assets/audio/review-male-v1/A-U09.1-TR-01.m4a',
            audioTitle: 'Tıraş ve Şükür Namazı',
            substeps: [
              'Erkekler saçlarını tamamen kazıtır veya eşit şekilde kısaltır (halk veya taksîr).',
              'Kadınlar saçlarının ucundan parmak ucu kadar (1-2 cm) bir tutam keser.',
              'Saç kesimi ile birlikte ihram yasakları kalkar ve umre tamamlanmış olur.',
            ],
          ),
        ],
      ),
    ];
  }

  List<GuideSection> _buildHajjSections() {
    return [
      const GuideSection(
        number: 1,
        title: 'Bölüm 1: Hac Hazırlığı & Mîkāt',
        subtitle: 'Terviye gününe hazırlık ve niyet',
        icon: Icons.luggage_outlined,
        stageType: GuideStageType.luggage,
        items: [
          GuideSectionItem(
            title: 'Hac Niyeti ve İhram',
            summary: '8 Zilhicce Terviye günü ihrama girilerek Mina’ya hareket edilir.',
            audioAsset: 'assets/audio/review-male-v1/A-H01.1-TR-01.m4a',
            audioTitle: 'Hac Hazırlığı ve Niyet',
            checklist: [
              'İhram örtüleri ve cepli emniyetli kemer',
              'Güneşten korunmak için açık renk şemsiye',
              'Mina ve Arafat için hafif mat ve uyku tulumu',
              'Kokusuz sabun ve kişisel bakım ürünleri',
              'Düzenli ilaçlar ve güneş kremi',
              'Taş toplama ve taşıma kesesi',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 2,
        title: 'Bölüm 2: Mîkāt & Terviye Günü (Mina)',
        subtitle: 'Mina çadırlar kenti ve hazırlık',
        icon: Icons.holiday_village_outlined,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            title: 'Mina’da Konaklama',
            summary: 'Terviye günü öğle, ikindi, akşam, yatsı ve sabah namazları Mina’da kılınır.',
            audioAsset: 'assets/audio/review-male-v1/A-H03.1-TR-01.m4a',
            audioTitle: 'Mina ve İntikal Rehberi',
            substeps: [
              '8 Zilhicce sabahı Mina’ya hareket edilir.',
              'Namazlar kendi vakitlerinde kısaltılarak (kasr) eda edilir.',
              'Arefe sabahı güneş doğduktan sonra Arafat’a intikal başlar.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 3,
        title: 'Bölüm 3: Arafat & Müzdelife Vakfesi',
        subtitle: 'Haccın en büyük farzı ve vakfe duaları',
        icon: Icons.wb_sunny_outlined,
        stageType: GuideStageType.arafat,
        items: [
          GuideSectionItem(
            title: 'Arafat Vakfesi',
            summary: 'Arefe günü öğle ile akşam arası Arafat sınırları içinde vakfe yapılır.',
            audioAsset: 'assets/audio/review-male-v1/A-H04.1-TR-01.m4a',
            audioTitle: 'Arafat ve Dua Rehberi',
            substeps: [
              'Arafat sınırları tabelalarla belirtilmiştir; sınır içinde kalınmalıdır.',
              'Öğle ve İkindi namazları cem-i takdim ile birleştirilerek kılınır.',
              'Güneş batana kadar telbiye, zikir ve vakfe duaları yapılır.',
              'Akşam namazı kılınmadan Müzdelife’ye intikal edilir.',
              'Müzdelife’de Akşam ve Yatsı namazları birleştirilir (cem-i tehir).',
              'Şeytan taşlama için 70 adet küçük taş toplanır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 4,
        title: 'Bölüm 4: Mina & Cemarat (Şeytan Taşlama)',
        subtitle: 'Büyük şeytan taşlama, kurban ve tahallül',
        icon: Icons.scatter_plot_rounded,
        stageType: GuideStageType.cemarat,
        items: [
          GuideSectionItem(
            title: 'Cemarat Taşlaması',
            summary: 'Bayramın 1. günü yalnız Akabe Cemresi’ne (Büyük Şeytan) 7 taş atılır.',
            audioAsset: 'assets/audio/review-male-v1/A-H06.1-TR-01.m4a',
            audioTitle: 'Cemarat ve Kurban Rehberi',
            counterKey: 'cemarat',
            substeps: [
              'Akabe Cemresi’ne 7 taş atılır; her atışta "Bismillahi Allahu Ekber" denir.',
              'Kurban kesim teyidi geldikten sonra saçlar tıraş edilip ihramdan çıkılır.',
              'Bayramın 2. ve 3. günleri Küçük, Orta ve Büyük cemrelere 7’şer taş (toplam 21) atılır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 5,
        title: 'Bölüm 5: Ziyaret Tavafı & Veda Tavafı',
        subtitle: 'Haccın farz tavafı ve veda',
        icon: Icons.mosque_outlined,
        stageType: GuideStageType.tawaf,
        items: [
          GuideSectionItem(
            title: 'Ziyaret Tavafı ve Sa‘y',
            summary: 'Mekke’ye inilip farz olan Ziyaret Tavafı ve hac sa‘yı yerine getirilir.',
            audioAsset: 'assets/audio/review-male-v1/A-H08.1-TR-01.m4a',
            audioTitle: 'Ziyaret Tavafı ve Veda',
            counterKey: 'tawaf',
            substeps: [
              'Farz olan Ziyaret Tavafı 7 şavt olarak eda edilir.',
              'Hac sa‘yı yerine getirilir.',
              'Mekke’den ayrılmadan önce Veda Tavafı yapılır.',
            ],
          ),
        ],
      ),
    ];
  }

  void _openCounter(String key, String title) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CounterScreen(
          store: widget.store,
          sessionId: _activeSessionId,
          counterKey: key,
          title: title,
        ),
      ),
    );
  }

  Future<void> _toggleAudio(String asset, String title) async {
    final current = widget.narration.state;
    if (current.asset == asset && current.status == NarrationStatus.playing) {
      await widget.narration.pause();
    } else if (current.asset == asset &&
        current.status == NarrationStatus.paused) {
      await widget.narration.resume();
    } else {
      await widget.narration.playAsset(asset, title: title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.type == GuideType.umrah
        ? 'Umre Rehberim'
        : 'Hac Rehberim';
    final totalChecks = _sections
        .expand((s) => s.items)
        .expand((i) => i.checklist)
        .length;
    final progressPercent = totalChecks > 0
        ? ((_checkedItems.length / totalChecks) * 100).round()
        : 0;

    return Scaffold(
      appBar: AppBar(title: Text(title), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: widget.type == GuideType.umrah
                  ? RehberTheme.umrahCardGradient
                  : RehberTheme.hajjCardGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RehberTheme.gold.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_stories_rounded,
                        color: RehberTheme.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_sections.length} ana bölüm · Canlı görsel ve sesli simülasyon',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalChecks > 0
                        ? (_checkedItems.length / totalChecks)
                        : 0,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      RehberTheme.goldLight,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hazırlık: %$progressPercent',
                        style: const TextStyle(
                          color: RehberTheme.goldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${_checkedItems.length} / $totalChecks madde tamamlandı',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Sections with Embedded Live Stage and Persistent Checklists
          for (final section in _sections) ...[
            _buildSectionCard(section, dark),
            const SizedBox(height: 18),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard(GuideSection section, bool dark) {
    final firstItem = section.items.first;
    final stageItems = firstItem.checklist.isNotEmpty
        ? firstItem.checklist
        : (firstItem.substeps.isNotEmpty
              ? firstItem.substeps
              : [firstItem.title, firstItem.summary]);
    final activeIndex = _activeItemBySection[section.number] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: RehberTheme.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    section.icon,
                    color: RehberTheme.emerald,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: dark ? Colors.white : RehberTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        section.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: dark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Interactive Animated Stage
            GuideStageAnimator(
              key: ValueKey('stage_${section.number}'),
              stageType: section.stageType,
              items: stageItems,
              initialIndex: activeIndex,
              onItemChanged: (newIdx) {
                setState(() {
                  _activeItemBySection[section.number] = newIdx;
                });
              },
              audioAsset: firstItem.audioAsset,
              audioTitle: firstItem.audioTitle,
              narration: widget.narration,
            ),
            const SizedBox(height: 14),

            // Items
            for (final item in section.items) ...[
              Text(
                item.summary,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Checklist (Persistent: Never disappears!)
              if (item.checklist.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF14221F)
                        : const Color(0xFFF4F7F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (
                        int cIdx = 0;
                        cIdx < item.checklist.length;
                        cIdx++
                      ) ...[
                        _buildChecklistRow(
                          sectionNumber: section.number,
                          check: item.checklist[cIdx],
                          index: cIdx,
                          isFocused: activeIndex == cIdx,
                          dark: dark,
                          isLuggage: section.number == 1,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Substeps (Persistent: Never disappears!)
              if (item.substeps.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF14221F)
                        : const Color(0xFFF4F7F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (
                        int sIdx = 0;
                        sIdx < item.substeps.length;
                        sIdx++
                      ) ...[
                        _buildSubstepRow(
                          sectionNumber: section.number,
                          step: item.substeps[sIdx],
                          index: sIdx,
                          isFocused: activeIndex == sIdx,
                          dark: dark,
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // Embedded Audio Bar
              if (item.audioAsset != null) ...[
                const SizedBox(height: 12),
                _buildAudioBar(item, dark),
              ],

              // Counter Action Button
              if (item.counterKey != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCounter(
                      item.counterKey!,
                      item.counterKey == 'tawaf'
                          ? 'Tavaf Sayacı'
                          : (item.counterKey == 'say'
                                ? 'Sa‘y Sayacı'
                                : 'Cemarat Sayacı'),
                    ),
                    icon: const Icon(Icons.touch_app_rounded, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.counterKey == 'tawaf'
                            ? 'Tavaf Sayacını Başlat (7 Şavt)'
                            : (item.counterKey == 'say'
                                  ? 'Sa‘y Sayacını Başlat (7 Tur)'
                                  : 'Taş Sayacını Başlat (7 Taş)'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistRow({
    required int sectionNumber,
    required String check,
    required int index,
    required bool isFocused,
    required bool dark,
    required bool isLuggage,
  }) {
    final isChecked = _checkedItems.contains(check);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isFocused
            ? RehberTheme.emerald.withValues(alpha: dark ? 0.22 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? RehberTheme.emerald : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox (tap to check)
          InkWell(
            onTap: () => _toggleCheck(check),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 6),
              child: Icon(
                isChecked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: isChecked ? RehberTheme.emerald : Colors.grey,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Content (tap to jump animation stage to this item)
          Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeItemBySection[sectionNumber] = index;
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    check,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? Colors.grey
                          : (dark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (isFocused) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.visibility_rounded,
                          size: 11,
                          color: RehberTheme.goldLight,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            isLuggage
                                ? 'Valize yerleştirildi · İncelemek için dokunun'
                                : 'Sahnede gösteriliyor · Dokunarak odaklanın',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: RehberTheme.goldLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubstepRow({
    required int sectionNumber,
    required String step,
    required int index,
    required bool isFocused,
    required bool dark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isFocused
            ? RehberTheme.emerald.withValues(alpha: dark ? 0.22 : 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? RehberTheme.emerald : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeItemBySection[sectionNumber] = index;
          });
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isFocused
                    ? RehberTheme.emerald
                    : (dark ? Colors.white12 : Colors.black12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isFocused ? Colors.white : Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFocused
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (isFocused) ...[
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 11,
                          color: RehberTheme.goldLight,
                        ),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Sahnede simüle ediliyor',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: RehberTheme.goldLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBar(GuideSectionItem item, bool dark) {
    final narration = widget.narration;
    final isCurrent = narration.state.asset == item.audioAsset;
    final isPlaying =
        isCurrent && narration.state.status == NarrationStatus.playing;
    final isLoading =
        isCurrent && narration.state.status == NarrationStatus.loading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isPlaying
            ? RehberTheme.emerald.withValues(alpha: 0.15)
            : (dark ? const Color(0xFF1B2824) : const Color(0xFFEBF3F0)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlaying ? RehberTheme.emerald : Colors.transparent,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                _toggleAudio(item.audioAsset!, item.audioTitle ?? item.title),
            icon: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: RehberTheme.emerald,
                    size: 34,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.audioTitle ?? item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isPlaying
                      ? 'Oynatılıyor · Sesli Anlatım'
                      : 'Sesli anlatımı dinle',
                  style: TextStyle(
                    fontSize: 11,
                    color: isPlaying
                        ? RehberTheme.emerald
                        : (dark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          if (isPlaying)
            const Icon(
              Icons.graphic_eq_rounded,
              color: RehberTheme.emerald,
              size: 22,
            ),
        ],
      ),
    );
  }
}
