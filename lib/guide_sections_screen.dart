import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'counter_screen.dart';
import 'guide_catalog.dart';
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
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<GuideSectionItem> items;
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
        subtitle: 'Gitmeden önce yanınıza almanız gereken temel eşyalar',
        icon: Icons.luggage_outlined,
        items: [
          GuideSectionItem(
            title: 'Valiz Kontrol Listesi',
            summary: 'İhram, dikişsiz terlik ve kişisel hijyen malzemelerini eksiksiz hazırlayın.',
            audioAsset: 'assets/audio/review-male-v1/A-U01.1-TR-01.m4a',
            audioTitle: 'Valiz ve Hazırlık Rehberi',
            checklist: [
              '2 parça dikişsiz ihram kumaşı (erkekler için)',
              'Kokusuz sabun, şampuan ve pişik kremi',
              'Rahat ortopedik sandalet / tavaf patiği',
              'Düzenli kullanılan ilaçlar ve ilk yardım kiti',
              'Boyun askılı güvenli pasaport ve para cüzdanı',
              'Küçük boy dua kitabı ve dijital zikirmatik',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 2,
        title: 'Bölüm 2: Gitmeden Önce Bilinmesi Gerekenler',
        subtitle: 'Mîkāt sınırları, ihram kuralları ve yasaklar',
        icon: Icons.menu_book_rounded,
        items: [
          GuideSectionItem(
            title: 'İhrama Giriş ve Yasaklar',
            summary: 'Mîkāt sınırında boy abdesti alınır, niyet edilir ve telbiye getirilir.',
            audioAsset: 'assets/audio/review-male-v1/A-U01.2-TR-01.m4a',
            audioTitle: 'İhram Kuralları ve Telbiye Anlatımı',
            substeps: [
              'Mîkāt sınırını ihramsız geçmek caiz değildir.',
              'İhramlıyken koku sürünmek, tırnak veya kıl kesmek yasaktır.',
              'Erkekler başını ve ayağını kapatan dikişli giysi giyemez.',
              'Kavga, tartışma ve kırıcı sözlerden kesinlikle kaçınılır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 3,
        title: 'Bölüm 3: Kâbe’ye Varış ve Tavaf',
        subtitle: 'Mescid-i Harâm adabı, 7 şavt ve dualar',
        icon: Icons.mosque_outlined,
        items: [
          GuideSectionItem(
            title: 'Tavaf İbadeti',
            summary: 'Hacerü’l-Esved hizasından başlanarak Kâbe etrafında 7 şavt tamamlanır.',
            audioAsset: 'assets/audio/review-male-v1/A-U04.1-TR-01.m4a',
            audioTitle: 'Tavaf Duaları ve Şavt Rehberi',
            counterKey: 'tawaf',
            substeps: [
              'Hacerü’l-Esved selamlanır (Bismillahi Allahu Ekber).',
              'Kâbe sol tarafa alınarak saat yönünün tersine dönülür.',
              '7 şavt bitince Makam-ı İbrahim arkasında 2 rekat tavaf namazı kılınır.',
              'Kana kana zemzem içilir ve dua edilir.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 4,
        title: 'Bölüm 4: Sa‘y İbadeti (Safâ - Merve)',
        subtitle: 'Safâ tepesinden Merve’ye 7 tur yürüyüş',
        icon: Icons.directions_walk_rounded,
        items: [
          GuideSectionItem(
            title: 'Safâ ve Merve Arasında Sa‘y',
            summary:
                'Safâ’dan Merve’ye 4 gidiş, Merve’den Safâ’ya 3 dönüş yapılır.',
            audioAsset: 'assets/audio/review-male-v1/A-U06.1-TR-01.m4a',
            audioTitle: 'Sa‘y İbadeti ve Duaları',
            counterKey: 'say',
            substeps: [
              'Safâ tepesinde Kâbe’ye dönülüp niyet ve tekbir getirilir.',
              'Yeşil ışıklar arasında erkekler hafif koşar adımlarla (Hervele) yürür.',
              'Merve tepesine varıldığında 1 şavt tamamlanmış olur.',
              'Toplam 7 şavt Merve tepesinde son bulur.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 5,
        title: 'Bölüm 5: Tıraş ve İhramdan Çıkış',
        subtitle: 'Saç kesimi ile umrenin tamamlanması',
        icon: Icons.content_cut_rounded,
        items: [
          GuideSectionItem(
            title: 'Tahallül (İhramdan Çıkış)',
            summary: 'Erkekler saçlarını tamamen kazıtır veya kısaltır, kadınlar parmak ucu kadar keser.',
            audioAsset: 'assets/audio/review-male-v1/A-U09.1-TR-01.m4a',
            audioTitle: 'Tıraş ve Şükür Namazı',
            substeps: [
              'Saç kesimi yapılmadan ihram yasakları kalkmaz.',
              'Tıraş olduktan sonra normal elbiseler giyilir ve umre tamamlanır.',
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
        items: [
          GuideSectionItem(
            title: 'Hac Niyeti ve İhram',
            summary: '8 Zilhicce Terviye günü ihrama girilerek Mina’ya hareket edilir.',
            audioAsset: 'assets/audio/review-male-v1/A-H01.1-TR-01.m4a',
            audioTitle: 'Hac Hazırlığı ve Niyet',
            checklist: [
              'İhram örtüleri ve yedek ihram',
              'Güneşten korunmak için açık renk şemsiye',
              'Mina ve Arafat için hafif mat ve uyku tulumu',
              'Sıvı kaybını önlemek için elektrolit ve su kabı',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 2,
        title: 'Bölüm 2: Arafat Vakfesi',
        subtitle: 'Haccın en önemli farzı (Arefe Günü)',
        icon: Icons.landscape_rounded,
        items: [
          GuideSectionItem(
            title: 'Arafat Vakfesi ve Dualar',
            summary: 'Arefe günü öğleden gün batımına kadar Arafat sınırları içinde vakfe yapılır.',
            audioAsset: 'assets/audio/review-male-v1/A-H02.1-TR-01.m4a',
            audioTitle: 'Arafat Vakfesi ve Duaları',
            substeps: [
              'Öğle ve ikindi namazları cem-i takdim ile kılınır.',
              'Gün boyu tövbe, istiğfar ve yakarışla dua edilir.',
              'Güneş batınca akşam namazı kılınmadan Müzdelife’ye geçilir.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 3,
        title: 'Bölüm 3: Müzdelife & Taş Toplama',
        subtitle: 'Akşam ve yatsı cemi, şeytan taşlama için hazırlık',
        icon: Icons.nights_stay_outlined,
        items: [
          GuideSectionItem(
            title: 'Müzdelife Gecesi ve Vakfe',
            summary: 'Akşam ile yatsı namazı birleştirilir ve Cemarat için taş toplanır.',
            audioAsset: 'assets/audio/review-male-v1/A-H04.1-TR-01.m4a',
            audioTitle: 'Müzdelife Vakfesi',
            substeps: [
              'Nohut büyüklüğünde en az 49-70 adet taş toplanır.',
              'Sabah namazı sonrası Meş’ar-i Haram yanında vakfe yapılır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 4,
        title: 'Bölüm 4: Mina & Şeytan Taşlama',
        subtitle: 'Büyük Şeytan, Kurban ve Tıraş',
        icon: Icons.sports_volleyball_outlined,
        items: [
          GuideSectionItem(
            title: 'Cemarat Taşlaması',
            summary: 'Bayramın 1. günü yalnız Akabe Cemresi’ne (Büyük Şeytan) 7 taş atılır.',
            audioAsset: 'assets/audio/review-male-v1/A-H06.1-TR-01.m4a',
            audioTitle: 'Cemarat ve Kurban Rehberi',
            counterKey: 'cemarat',
            substeps: [
              'Her taş atılırken "Bismillahi Allahu Ekber" denir.',
              'Kurban kesilince saçlar tıraş edilip ihramdan ilk çıkış yapılır.',
            ],
          ),
        ],
      ),
      const GuideSection(
        number: 5,
        title: 'Bölüm 5: Ziyaret Tavafı & Veda',
        subtitle: 'Haccın farz tavafı ve veda',
        icon: Icons.mosque_outlined,
        items: [
          GuideSectionItem(
            title: 'Ziyaret Tavafı ve Sa‘y',
            summary: 'Mekke’ye inilip farz olan Ziyaret Tavafı ve hac sa‘yı yerine getirilir.',
            audioAsset: 'assets/audio/review-male-v1/A-H08.1-TR-01.m4a',
            audioTitle: 'Ziyaret Tavafı ve Veda',
            counterKey: 'tawaf',
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            '${_sections.length} ana bölüm · Görsel ve sesli anlatım',
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
                        'İlerleme: %$progressPercent',
                        style: const TextStyle(
                          color: RehberTheme.goldLight,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${_checkedItems.length} / $totalChecks adım tamamlandı',
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
          const SizedBox(height: 20),

          // Sections
          for (final section in _sections) ...[
            _buildSectionCard(section, dark),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard(GuideSection section, bool dark) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
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

            // Items
            for (final item in section.items) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              Text(
                item.summary,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: dark ? Colors.white70 : Colors.black87,
                ),
              ),

              // Checklist if any
              if (item.checklist.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF1B2B27)
                        : const Color(0xFFF2F6F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (final check in item.checklist)
                        InkWell(
                          onTap: () => _toggleCheck(check),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  _checkedItems.contains(check)
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked,
                                  color: _checkedItems.contains(check)
                                      ? RehberTheme.emerald
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    check,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: _checkedItems.contains(check)
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: _checkedItems.contains(check)
                                          ? Colors.grey
                                          : (dark
                                                ? Colors.white
                                                : Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Substeps if any
              if (item.substeps.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final step in item.substeps)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Text(
                            step,
                            style: TextStyle(
                              fontSize: 13,
                              color: dark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
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
                            ? 'Tavaf Sayacını Başlat'
                            : (item.counterKey == 'say'
                                  ? 'Sa‘y Sayacını Başlat'
                                  : 'Taş Sayacını Başlat'),
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
