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
    this.stepId,
    this.audioAsset,
    this.audioTitle,
    this.counterKey,
    this.checklist = const [],
    this.substeps = const [],
  });

  final String title;
  final String summary;
  final String? stepId;
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
    this.profile,
  });

  final GuideType type;
  final ProgressStore store;
  final NarrationService narration;
  final GuideCatalog? catalog;
  final HajjProfile? profile;

  @override
  State<GuideSectionsScreen> createState() => _GuideSectionsScreenState();
}

class _GuideSectionsScreenState extends State<GuideSectionsScreen> {
  final Set<String> _checkedItems = {};
  final Map<int, int> _activeItemBySection = {};
  int? _activeSessionId;
  bool _sessionLoading = true;
  String? _sessionError;
  late HajjProfile? _activeProfile = widget.type == GuideType.hajj
      ? (widget.profile ?? HajjProfile.temettu)
      : null;

  late final List<GuideSection> _sections = _buildSections();

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
    setState(() {
      _sessionLoading = true;
      _sessionError = null;
    });
    try {
      final existing = await widget.store.readMostRecentSession();
      final targetProfile = widget.type == GuideType.hajj
          ? (_activeProfile ?? existing?.profile ?? HajjProfile.temettu)
          : null;
      final session =
          (existing != null &&
              existing.type == widget.type &&
              (widget.type == GuideType.umrah ||
                  existing.profile == targetProfile))
          ? existing
          : await widget.store.openOrCreateSession(
              type: widget.type,
              mode: GuideMode.learning,
              profile: targetProfile,
              firstStepId: widget.type == GuideType.umrah ? 'U01.1' : 'H01.1',
              contentVersion: widget.catalog?.contentVersion ?? 'v1',
            );
      if (mounted) {
        final marked = await widget.store.readMarkedStepIds(session.id);
        setState(() {
          _activeProfile = session.profile ?? _activeProfile;
          _activeSessionId = session.id;
          _checkedItems.addAll(marked);
          _sessionLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionLoading = false;
          _sessionError = 'Rehber oturumu açılamadı.';
        });
      }
    }
  }

  Future<void> _switchProfile(HajjProfile profile) async {
    if (_activeProfile == profile) return;
    setState(() {
      _activeProfile = profile;
      _sessionLoading = true;
    });
    try {
      final session = await widget.store.openOrCreateSession(
        type: widget.type,
        mode: GuideMode.learning,
        profile: profile,
        firstStepId: 'H01.1',
        contentVersion: widget.catalog?.contentVersion ?? 'v1',
      );
      if (mounted) {
        final marked = await widget.store.readMarkedStepIds(session.id);
        setState(() {
          _activeSessionId = session.id;
          _checkedItems.clear();
          _checkedItems.addAll(marked);
          _sessionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sessionLoading = false);
    }
  }

  Future<void> _toggleCheck(String checkKey, {String? stepId}) async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturum henüz hazır değil.')),
      );
      return;
    }

    final isChecked = !_checkedItems.contains(checkKey);
    setState(() {
      if (isChecked) {
        _checkedItems.add(checkKey);
        if (stepId != null) _checkedItems.add(stepId);
      } else {
        _checkedItems.remove(checkKey);
      }
    });

    try {
      await widget.store.setStepMarked(sessionId, checkKey, isChecked);
      if (stepId != null && isChecked) {
        await widget.store.setStepMarked(sessionId, stepId, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isChecked) {
            _checkedItems.remove(checkKey);
            if (stepId != null) _checkedItems.remove(stepId);
          } else {
            _checkedItems.add(checkKey);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İlerleme kaydedilemedi.')),
        );
      }
    }
  }

  /// Ses kaydının gerçekten doğrulanmış ve oynatılabilir olup olmadığını denetler.
  /// Normal sürümde yalnız approved sesler; review sürümünde synthetic draft preview sesler.
  String? _resolvePlayableAudio(
    String? audioId, {
    required bool isStepApproved,
  }) {
    if (audioId == null) return null;
    final cat = widget.catalog;
    if (cat == null) return null;
    final record = cat.audioRecords[audioId];
    if (record == null || record.asset == null) return null;

    final isPlayable =
        (isStepApproved && record.status == ReviewStatus.approved) ||
        (cat.isPreview && record.isSyntheticDraftPreview);
    return isPlayable ? record.asset : null;
  }

  List<GuideSection> _buildSections() {
    final cat = widget.catalog;
    if (cat == null || cat.steps.isEmpty) {
      return const [];
    }

    // Normal uygulamada onaylanmamış adımlar listelenmez.
    // İnceleme sürümünde (cat.isPreview) taslak adımlar görünür.
    final availableSteps = cat.isPreview
        ? cat.steps
        : cat.steps.where((s) => s.isApproved).toList();

    if (availableSteps.isEmpty) {
      return const [];
    }

    if (widget.type == GuideType.umrah) {
      return _buildUmrahSectionsFromCatalog(availableSteps);
    } else {
      return _buildHajjSectionsFromCatalog(availableSteps);
    }
  }

  List<GuideSection> _buildUmrahSectionsFromCatalog(List<GuideStep> steps) {
    GuideStep? findStep(String id) {
      for (final s in steps) {
        if (s.id == id) return s;
      }
      return null;
    }

    final s1_1 = findStep('U01.1');
    final s1_2 = findStep('U01.2');
    final s4_1 = findStep('U04.1');
    final s6_1 = findStep('U06.1');
    final s9_1 = findStep('U09.1');

    return [
      GuideSection(
        number: 1,
        title: 'Bölüm 1: Valiz & Hazırlık Eşyaları',
        subtitle: 'Diyanet ve fıkıh standartlarında eksiksiz eşya listesi',
        icon: Icons.luggage_outlined,
        stageType: GuideStageType.luggage,
        items: [
          GuideSectionItem(
            stepId: 'U01.1',
            title: s1_1?.title ?? 'Valiz Kontrol Listesi',
            summary: s1_1?.summary ?? 'Eşyalar üstteki sahnede valize yerleşir; alttaki listeden kontrol edip işaretleyebilirsiniz.',
            audioAsset: _resolvePlayableAudio(
              s1_1?.linkedAudioIds.isNotEmpty == true
                  ? s1_1!.linkedAudioIds.first
                  : 'A-U01.1-TR-01',
              isStepApproved: s1_1?.isApproved ?? false,
            ),
            audioTitle: 'Valiz ve Hazırlık Rehberi',
            checklist: const [
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
      GuideSection(
        number: 2,
        title: 'Bölüm 2: Mîkāt & İhram Kuralları',
        subtitle: 'Mîkāt sınırları, ihram kuralları ve yasaklar',
        icon: Icons.menu_book_rounded,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            stepId: 'U01.2',
            title: s1_2?.title ?? 'İhrama Giriş ve Yasaklar',
            summary: s1_2?.summary ?? 'Mîkāt sınırında boy abdesti alınır, niyet edilir ve telbiye getirilir.',
            audioAsset: _resolvePlayableAudio(
              s1_2?.linkedAudioIds.isNotEmpty == true
                  ? s1_2!.linkedAudioIds.first
                  : 'A-U01.2-TR-01',
              isStepApproved: s1_2?.isApproved ?? false,
            ),
            audioTitle: 'İhram Kuralları ve Telbiye Anlatımı',
            substeps: const [
              'Boy abdesti (gusül) alınıp 2 rekat ihram namazı kılınır.',
              'Mîkāt sınırını ihramsız geçmek caiz değildir (kurban cezası gerekir).',
              'Niyet: "Allah\'ım senin rızan için Umre yapmak istiyorum..."',
              'Telbiye: "Lebbeyk Allahümme lebbeyk, lebbeyke lâ şerîke leke lebbeyk..."',
              'İhramlıyken koku sürünmek, dikişli giysi/çorap giymek (erkekler) ve kıl kesmek yasaktır.',
            ],
          ),
        ],
      ),
      GuideSection(
        number: 3,
        title: 'Bölüm 3: Kâbe’ye Varış & Canlı Tavaf',
        subtitle: 'Mescid-i Harâm adabı, 7 şavt ve dualar',
        icon: Icons.mosque_outlined,
        stageType: GuideStageType.tawaf,
        items: [
          GuideSectionItem(
            stepId: 'U04.1',
            title: s4_1?.title ?? 'Tavaf İbadeti',
            summary: s4_1?.summary ?? 'Hacerü’l-Esved hizasından başlanarak Kâbe etrafında 7 şavt tamamlanır.',
            audioAsset: _resolvePlayableAudio(
              s4_1?.linkedAudioIds.isNotEmpty == true
                  ? s4_1!.linkedAudioIds.first
                  : 'A-U04.1-TR-01',
              isStepApproved: s4_1?.isApproved ?? false,
            ),
            audioTitle: 'Tavaf Duaları ve Şavt Rehberi',
            counterKey: 'tawaf',
            substeps: const [
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
      GuideSection(
        number: 4,
        title: 'Bölüm 4: Safâ ve Merve Sa‘y Yolu',
        subtitle: 'Safâ tepesinden Merve’ye 7 tur yürüyüş',
        icon: Icons.directions_walk_rounded,
        stageType: GuideStageType.say,
        items: [
          GuideSectionItem(
            stepId: 'U06.1',
            title: s6_1?.title ?? 'Safâ ve Merve Arasında Sa‘y',
            summary:
                s6_1?.summary ??
                'Safâ’dan Merve’ye 4 gidiş, Merve’den Safâ’ya 3 dönüş yapılır.',
            audioAsset: _resolvePlayableAudio(
              s6_1?.linkedAudioIds.isNotEmpty == true
                  ? s6_1!.linkedAudioIds.first
                  : 'A-U06.1-TR-01',
              isStepApproved: s6_1?.isApproved ?? false,
            ),
            audioTitle: 'Sa‘y İbadeti ve Duaları',
            counterKey: 'say',
            substeps: const [
              '1. Tur: Safâ tepesinde Kâbe’ye dönülüp niyet ve tekbir getirilir.',
              'Hervele Sünneti: İki yeşil floresan ışık arasında erkekler hızlı adımlarla yürür.',
              '2. Tur: Merve tepesinde dua edilip Safâ’ya doğru dönülür.',
              '3. – 6. Tur: Safâ ve Merve arasında dualarla yürüyüş sürdürülür.',
              '7. Tur (Bitiş): Merve tepesinde 7. tur ile Sa‘y ibadeti tamamlanır.',
            ],
          ),
        ],
      ),
      GuideSection(
        number: 5,
        title: 'Bölüm 5: Tıraş ve İhramdan Çıkış (Tahallül)',
        subtitle: 'Saç kesimi ile umrenin tamamlanması',
        icon: Icons.content_cut_rounded,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            stepId: 'U09.1',
            title: s9_1?.title ?? 'Tahallül (İhramdan Çıkış)',
            summary: s9_1?.summary ?? 'Erkekler saçlarını kazıtır veya kısaltır, kadınlar parmak ucu kadar keser.',
            audioAsset: _resolvePlayableAudio(
              s9_1?.linkedAudioIds.isNotEmpty == true
                  ? s9_1!.linkedAudioIds.first
                  : 'A-U09.1-TR-01',
              isStepApproved: s9_1?.isApproved ?? false,
            ),
            audioTitle: 'Tıraş ve Şükür Namazı',
            substeps: const [
              'Erkekler saçlarını tamamen kazıtır veya eşit şekilde kısaltır (halk veya taksîr).',
              'Kadınlar saçlarının ucundan parmak ucu kadar (1-2 cm) bir tutam keser.',
              'Saç kesimi ile birlikte ihram yasakları kalkar ve umre tamamlanmış olur.',
            ],
          ),
        ],
      ),
    ];
  }

  List<GuideSection> _buildHajjSectionsFromCatalog(List<GuideStep> steps) {
    GuideStep? findStep(String id) {
      for (final s in steps) {
        if (s.id == id) return s;
      }
      return null;
    }

    final s1_1 = findStep('H01.1');
    final s3_1 = findStep('H03.1');
    final s4_1 = findStep('H04.1');
    final s6_1 = findStep('H06.1');
    final s8_1 = findStep('H08.1');

    return [
      GuideSection(
        number: 1,
        title: 'Bölüm 1: Hac Hazırlığı & Mîkāt',
        subtitle: 'Terviye gününe hazırlık ve niyet',
        icon: Icons.luggage_outlined,
        stageType: GuideStageType.luggage,
        items: [
          GuideSectionItem(
            stepId: 'H01.1',
            title: s1_1?.title ?? 'Hac Niyeti ve İhram',
            summary: s1_1?.summary ?? '8 Zilhicce Terviye günü ihrama girilerek Mina’ya hareket edilir.',
            audioAsset: _resolvePlayableAudio(
              s1_1?.linkedAudioIds.isNotEmpty == true
                  ? s1_1!.linkedAudioIds.first
                  : 'A-H01.1-TR-01',
              isStepApproved: s1_1?.isApproved ?? false,
            ),
            audioTitle: 'Hac Hazırlığı ve Niyet',
            checklist: const [
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
      GuideSection(
        number: 2,
        title: 'Bölüm 2: Mîkāt & Terviye Günü (Mina)',
        subtitle: 'Mina çadırlar kenti ve hazırlık',
        icon: Icons.holiday_village_outlined,
        stageType: GuideStageType.ihram,
        items: [
          GuideSectionItem(
            stepId: 'H03.1',
            title: s3_1?.title ?? 'Mina’da Konaklama',
            summary: s3_1?.summary ?? 'Terviye günü öğle, ikindi, akşam, yatsı ve sabah namazları Mina’da kılınır.',
            audioAsset: _resolvePlayableAudio(
              s3_1?.linkedAudioIds.isNotEmpty == true
                  ? s3_1!.linkedAudioIds.first
                  : 'A-H03.1-TR-01',
              isStepApproved: s3_1?.isApproved ?? false,
            ),
            audioTitle: 'Mina ve İntikal Rehberi',
            substeps: const [
              '8 Zilhicce sabahı Mina’ya hareket edilir.',
              'Namazlar kendi vakitlerinde kısaltılarak (kasr) eda edilir.',
              'Arefe sabahı güneş doğduktan sonra Arafat’a intikal başlar.',
            ],
          ),
        ],
      ),
      GuideSection(
        number: 3,
        title: 'Bölüm 3: Arafat & Müzdelife Vakfesi',
        subtitle: 'Haccın en büyük farzı ve vakfe duaları',
        icon: Icons.wb_sunny_outlined,
        stageType: GuideStageType.arafat,
        items: [
          GuideSectionItem(
            stepId: 'H04.1',
            title: s4_1?.title ?? 'Arafat Vakfesi',
            summary: s4_1?.summary ?? 'Arefe günü öğle ile akşam arası Arafat sınırları içinde vakfe yapılır.',
            audioAsset: _resolvePlayableAudio(
              s4_1?.linkedAudioIds.isNotEmpty == true
                  ? s4_1!.linkedAudioIds.first
                  : 'A-H04.1-TR-01',
              isStepApproved: s4_1?.isApproved ?? false,
            ),
            audioTitle: 'Arafat ve Dua Rehberi',
            substeps: const [
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
      GuideSection(
        number: 4,
        title: 'Bölüm 4: Mina & Cemarat (Şeytan Taşlama)',
        subtitle: 'Büyük şeytan taşlama, kurban ve tahallül',
        icon: Icons.scatter_plot_rounded,
        stageType: GuideStageType.cemarat,
        items: [
          GuideSectionItem(
            stepId: 'H06.1',
            title: s6_1?.title ?? 'Cemarat Taşlaması',
            summary: s6_1?.summary ?? 'Bayramın 1. günü yalnız Akabe Cemresi’ne (Büyük Şeytan) 7 taş atılır.',
            audioAsset: _resolvePlayableAudio(
              s6_1?.linkedAudioIds.isNotEmpty == true
                  ? s6_1!.linkedAudioIds.first
                  : 'A-H06.1-TR-01',
              isStepApproved: s6_1?.isApproved ?? false,
            ),
            audioTitle: 'Cemarat ve Kurban Rehberi',
            counterKey: 'jamarat',
            substeps: const [
              'Akabe Cemresi’ne 7 taş atılır; her atışta "Bismillahi Allahu Ekber" denir.',
              'Kurban kesim teyidi geldikten sonra saçlar tıraş edilip ihramdan çıkılır.',
              'Bayramın 2. ve 3. günleri Küçük, Orta ve Büyük cemrelere 7’şer taş (toplam 21) atılır.',
            ],
          ),
        ],
      ),
      GuideSection(
        number: 5,
        title: 'Bölüm 5: Ziyaret Tavafı & Veda Tavafı',
        subtitle: 'Haccın farz tavafı ve veda',
        icon: Icons.mosque_outlined,
        stageType: GuideStageType.tawaf,
        items: [
          GuideSectionItem(
            stepId: 'H08.1',
            title: s8_1?.title ?? 'Ziyaret Tavafı ve Sa‘y',
            summary: s8_1?.summary ?? 'Mekke’ye inilip farz olan Ziyaret Tavafı ve hac sa‘yı yerine getirilir.',
            audioAsset: _resolvePlayableAudio(
              s8_1?.linkedAudioIds.isNotEmpty == true
                  ? s8_1!.linkedAudioIds.first
                  : 'A-H08.1-TR-01',
              isStepApproved: s8_1?.isApproved ?? false,
            ),
            audioTitle: 'Ziyaret Tavafı ve Veda',
            counterKey: 'tawaf',
            substeps: const [
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
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rehber oturumu henüz hazır değil.')),
      );
      return;
    }

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => (key == 'jamarat' || key == 'cemarat')
            ? JamaratCounterHubScreen(store: widget.store, sessionId: sessionId)
            : CounterScreen(
                store: widget.store,
                sessionId: sessionId,
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

    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title), elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 64,
                  color: dark ? Colors.white38 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  'Onaylı rehber içeriği henüz bulunmuyor',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : RehberTheme.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Rehber ve dinî adımlar uzman incelemesi tamamlandığında sunulacak. Önceki kişisel kayıtların cihazda korunur.',
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

    final totalChecks = _sections
        .expand((s) => s.items)
        .expand((i) => i.checklist)
        .length;
    final progressPercent = totalChecks > 0
        ? ((_checkedItems.length / totalChecks) * 100).round()
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        actions: [
          if (_sessionLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          if (_sessionError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _sessionError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadSession,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),

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
                            '${_sections.length} ana bölüm · Canlı görsel simülasyon',
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
                if (totalChecks > 0) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _checkedItems.length / totalChecks,
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
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (widget.type == GuideType.hajj) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF14241F) : const Color(0xFFE8F3EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: RehberTheme.emerald.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: RehberTheme.emerald,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hac Türü:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  DropdownButton<HajjProfile>(
                    value: _activeProfile,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [
                      for (final p in HajjProfile.values)
                        DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (p) {
                      if (p != null) _switchProfile(p);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

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
                          checkKey: '${item.stepId ?? 'item'}:check_$cIdx',
                          stepId: item.stepId,
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

              // Audio Bar (only shown if verified playable audio exists or disclaims unavailability)
              const SizedBox(height: 12),
              _buildAudioBar(item, dark),

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
                                  : 'Cemarat / Taş Sayacını Başlat'),
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
    required String checkKey,
    String? stepId,
    required int index,
    required bool isFocused,
    required bool dark,
    required bool isLuggage,
  }) {
    // Hem yeni deterministik key, hem eski check metni, hem de stepId ile uyumluluk
    final isChecked =
        _checkedItems.contains(checkKey) ||
        _checkedItems.contains(check) ||
        (stepId != null && _checkedItems.contains(stepId));

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
            onTap: () => _toggleCheck(checkKey, stepId: stepId),
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
    if (item.audioAsset == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.volume_off_rounded,
              size: 20,
              color: dark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bu başlık için onaylı ses kaydı henüz yok',
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
