import 'dart:convert';

enum GuideType { umrah, hajj }

extension GuideTypeLabel on GuideType {
  String get label => this == GuideType.umrah ? 'Umre' : 'Hac';
}

enum GuideMode { learning, journey }

extension GuideModeLabel on GuideMode {
  String get label =>
      this == GuideMode.learning ? 'Öğrenme' : 'Yolculukta rehber';
}

enum HajjProfile { temettu, ifrad, kiran }

extension HajjProfileLabel on HajjProfile {
  String get label => switch (this) {
    HajjProfile.temettu => 'Temettü',
    HajjProfile.ifrad => 'İfrad',
    HajjProfile.kiran => 'Kıran',
  };
}

enum ReviewStatus { draft, pendingReview, approved }

extension ReviewStatusLabel on ReviewStatus {
  String get label => switch (this) {
    ReviewStatus.draft => 'Taslak',
    ReviewStatus.pendingReview => 'İnceleme bekliyor',
    ReviewStatus.approved => 'Onaylı',
  };
}

enum AudioKind { turkishNarration, arabic, turkishMeaning }

extension AudioKindLabel on AudioKind {
  String get label => switch (this) {
    AudioKind.turkishNarration => 'Türkçe anlatım',
    AudioKind.arabic => 'Arapça okuma',
    AudioKind.turkishMeaning => 'Türkçe anlam',
  };
}

enum ProfileApplicability { unverified, applicable, notApplicable }

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Zorunlu alan eksik: $key');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Geçersiz alan: $key');
  return value.trim().isEmpty ? null : value.trim();
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field nesne olmalı.');
  try {
    return Map<String, Object?>.from(value);
  } catch (_) {
    throw FormatException('$field anahtarları metin olmalı.');
  }
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key liste olmalı.');
  return value;
}

List<String> _optionalIds(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('$key liste olmalı.');
  final ids = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw FormatException('$key kimliği metin olmalı.');
    }
    ids.add(item.trim());
  }
  if (ids.toSet().length != ids.length) {
    throw FormatException('$key tekrarlanan kimlik içeriyor.');
  }
  return List.unmodifiable(ids);
}

void _validateSourceAndReview({
  required ReviewStatus status,
  required String id,
  required String? textVersion,
  required String? sourceTitle,
  required String? sourceUrl,
  required String? sourceLocation,
  required String? sourceUsageRights,
  required String? reviewedBy,
  required String? reviewedAt,
}) {
  if (sourceUrl != null) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        sourceUrl.contains(RegExp(r'\s'))) {
      throw FormatException('Geçersiz kaynak bağlantısı: $id');
    }
  }
  if (reviewedAt != null &&
      (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(reviewedAt) ||
          DateTime.tryParse(reviewedAt) == null)) {
    throw FormatException('Geçersiz inceleme tarihi: $id');
  }
  if (status != ReviewStatus.draft &&
      [
        textVersion,
        sourceTitle,
        sourceUrl,
        sourceLocation,
        sourceUsageRights,
      ].any((value) => value == null)) {
    throw FormatException('İncelemeye hazır içerik için kaynak eksik: $id');
  }
  if (status == ReviewStatus.approved &&
      (reviewedBy == null || reviewedAt == null)) {
    throw FormatException('Onay için inceleyen ve tarih gerekli: $id');
  }
}

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('Geçersiz $field: $name');
}

class AudioRecord {
  const AudioRecord({
    required this.id,
    required this.status,
    required this.kind,
    this.textId,
    this.textVersion,
    this.asset,
    this.recordingOwner,
    this.rights,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final ReviewStatus status;
  final AudioKind kind;
  final String? textId;
  final String? textVersion;
  final String? asset;
  final String? recordingOwner;
  final String? rights;
  final String? reviewedBy;
  final String? reviewedAt;

  factory AudioRecord.fromJson(Map<String, Object?> json) {
    final record = AudioRecord(
      id: _requiredString(json, 'id'),
      status: _enumByName(
        ReviewStatus.values,
        _requiredString(json, 'status'),
        'audio status',
      ),
      kind: _enumByName(
        AudioKind.values,
        _requiredString(json, 'kind'),
        'ses türü',
      ),
      textId: _optionalString(json, 'textId'),
      textVersion: _optionalString(json, 'textVersion'),
      asset: _optionalString(json, 'asset'),
      recordingOwner: _optionalString(json, 'recordingOwner'),
      rights: _optionalString(json, 'rights'),
      reviewedBy: _optionalString(json, 'reviewedBy'),
      reviewedAt: _optionalString(json, 'reviewedAt'),
    );
    if ((record.textId == null) != (record.textVersion == null)) {
      throw FormatException('Ses ${record.id} için metin bağlantısı eksik.');
    }
    if (record.reviewedAt != null &&
        (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(record.reviewedAt!) ||
            DateTime.tryParse(record.reviewedAt!) == null)) {
      throw FormatException('Ses ${record.id} inceleme tarihi geçersiz.');
    }
    if (record.status == ReviewStatus.approved &&
        [
          record.asset,
          record.recordingOwner,
          record.rights,
          record.textId,
          record.textVersion,
          record.reviewedBy,
          record.reviewedAt,
        ].any((value) => value == null)) {
      throw FormatException(
        'Onaylı ses ${record.id} dosya, metin, hak ve inceleme ister.',
      );
    }
    return record;
  }
}

class PrayerRecord {
  const PrayerRecord({
    required this.id,
    required this.status,
    this.arabic,
    this.transliteration,
    this.meaningTr,
    this.sourceReference,
    this.textVersion,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceLocation,
    this.sourceUsageRights,
    this.reviewedBy,
    this.reviewedAt,
    this.audioId,
    this.audioIds = const [],
  });

  final String id;
  final ReviewStatus status;
  final String? arabic;
  final String? transliteration;
  final String? meaningTr;
  final String? sourceReference;
  final String? textVersion;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceLocation;
  final String? sourceUsageRights;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? audioId;
  final List<String> audioIds;

  bool get isApproved => status == ReviewStatus.approved;
  List<String> get linkedAudioIds => [?audioId, ...audioIds];

  factory PrayerRecord.fromJson(Map<String, Object?> json) {
    final record = PrayerRecord(
      id: _requiredString(json, 'id'),
      status: _enumByName(
        ReviewStatus.values,
        _requiredString(json, 'status'),
        'dua status',
      ),
      arabic: _optionalString(json, 'arabic'),
      transliteration: _optionalString(json, 'transliteration'),
      meaningTr: _optionalString(json, 'meaningTr'),
      sourceReference: _optionalString(json, 'sourceReference'),
      textVersion: _optionalString(json, 'textVersion'),
      sourceTitle: _optionalString(json, 'sourceTitle'),
      sourceUrl: _optionalString(json, 'sourceUrl'),
      sourceLocation: _optionalString(json, 'sourceLocation'),
      sourceUsageRights: _optionalString(json, 'sourceUsageRights'),
      reviewedBy: _optionalString(json, 'reviewedBy'),
      reviewedAt: _optionalString(json, 'reviewedAt'),
      audioId: _optionalString(json, 'audioId'),
      audioIds: _optionalIds(json, 'audioIds'),
    );
    _validateSourceAndReview(
      status: record.status,
      id: record.id,
      textVersion: record.textVersion,
      sourceTitle: record.sourceTitle,
      sourceUrl: record.sourceUrl,
      sourceLocation: record.sourceLocation,
      sourceUsageRights: record.sourceUsageRights,
      reviewedBy: record.reviewedBy,
      reviewedAt: record.reviewedAt,
    );
    if (record.status == ReviewStatus.approved &&
        [record.arabic, record.meaningTr].any((value) => value == null)) {
      throw FormatException('Onaylı dua ${record.id} inceleme alanları ister.');
    }
    return record;
  }
}

class GuideStep {
  const GuideStep({
    required this.id,
    required this.order,
    required this.groupId,
    required this.title,
    required this.status,
    required this.profileApplicability,
    required this.prayerIds,
    this.summary,
    this.details,
    this.arabic,
    this.transliteration,
    this.meaningTr,
    this.sourceReference,
    this.textVersion,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceLocation,
    this.sourceUsageRights,
    this.reviewedBy,
    this.reviewedAt,
    this.audioId,
    this.audioIds = const [],
    this.counterKey,
    this.counterTarget,
  });

  final String id;
  final int order;
  final String groupId;
  final String title;
  final ReviewStatus status;
  final String? summary;
  final String? details;
  final String? arabic;
  final String? transliteration;
  final String? meaningTr;
  final String? sourceReference;
  final String? textVersion;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceLocation;
  final String? sourceUsageRights;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? audioId;
  final List<String> audioIds;
  final List<String> prayerIds;
  final String? counterKey;
  final int? counterTarget;
  final Map<HajjProfile, ProfileApplicability> profileApplicability;

  bool get isApproved => status == ReviewStatus.approved;
  List<String> get linkedAudioIds => [?audioId, ...audioIds];

  factory GuideStep.fromJson(Map<String, Object?> json, GuideType type) {
    final order = json['order'];
    if (order is! int || order < 1) {
      throw const FormatException('Adım sırası pozitif tam sayı olmalı.');
    }
    final rawPrayers = json['prayerIds'];
    if (rawPrayers != null && rawPrayers is! List) {
      throw const FormatException('prayerIds liste olmalı.');
    }
    final prayerIds = <String>[];
    for (final value in (rawPrayers as List? ?? const [])) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException('Dua kimliği metin olmalı.');
      }
      prayerIds.add(value.trim());
    }
    final profiles = <HajjProfile, ProfileApplicability>{};
    if (type == GuideType.hajj) {
      final raw = _object(json['profileApplicability'], 'profileApplicability');
      if (raw.length != HajjProfile.values.length) {
        throw const FormatException('Üç hac profilinin durumu belirtilmeli.');
      }
      for (final profile in HajjProfile.values) {
        profiles[profile] = _enumByName(
          ProfileApplicability.values,
          _requiredString(raw, profile.name),
          'profil uygulanabilirliği',
        );
      }
    } else if (json['profileApplicability'] != null) {
      throw const FormatException('Umre adımında hac profil kuralı olamaz.');
    }
    final rawCounterTarget = json['counterTarget'];
    if (rawCounterTarget != null &&
        (rawCounterTarget is! int ||
            rawCounterTarget < 1 ||
            rawCounterTarget > 100 ||
            json['counterKey'] == null)) {
      throw const FormatException('Geçersiz sayaç hedefi.');
    }
    final step = GuideStep(
      id: _requiredString(json, 'id'),
      order: order,
      groupId: _requiredString(json, 'groupId'),
      title: _requiredString(json, 'title'),
      status: _enumByName(
        ReviewStatus.values,
        _requiredString(json, 'status'),
        'adım status',
      ),
      summary: _optionalString(json, 'summary'),
      details: _optionalString(json, 'details'),
      arabic: _optionalString(json, 'arabic'),
      transliteration: _optionalString(json, 'transliteration'),
      meaningTr: _optionalString(json, 'meaningTr'),
      sourceReference: _optionalString(json, 'sourceReference'),
      textVersion: _optionalString(json, 'textVersion'),
      sourceTitle: _optionalString(json, 'sourceTitle'),
      sourceUrl: _optionalString(json, 'sourceUrl'),
      sourceLocation: _optionalString(json, 'sourceLocation'),
      sourceUsageRights: _optionalString(json, 'sourceUsageRights'),
      reviewedBy: _optionalString(json, 'reviewedBy'),
      reviewedAt: _optionalString(json, 'reviewedAt'),
      audioId: _optionalString(json, 'audioId'),
      audioIds: _optionalIds(json, 'audioIds'),
      prayerIds: List.unmodifiable(prayerIds),
      counterKey: _optionalString(json, 'counterKey'),
      counterTarget: rawCounterTarget as int?,
      profileApplicability: Map.unmodifiable(profiles),
    );
    _validateSourceAndReview(
      status: step.status,
      id: step.id,
      textVersion: step.textVersion,
      sourceTitle: step.sourceTitle,
      sourceUrl: step.sourceUrl,
      sourceLocation: step.sourceLocation,
      sourceUsageRights: step.sourceUsageRights,
      reviewedBy: step.reviewedBy,
      reviewedAt: step.reviewedAt,
    );
    if (step.isApproved &&
        [step.summary, step.details].any((value) => value == null)) {
      throw FormatException('Onaylı adım ${step.id} kaynak ve metin ister.');
    }
    if (type == GuideType.hajj &&
        step.isApproved &&
        profiles.values.contains(ProfileApplicability.unverified)) {
      throw FormatException('Onaylı adım ${step.id} belirsiz profil içerir.');
    }
    return step;
  }
}

class GuideCatalog {
  GuideCatalog._({
    required this.schemaVersion,
    required this.contentVersion,
    required this.type,
    required this.steps,
    required this.audioRecords,
    required this.prayerRecords,
  });

  static const expectedGroups = <GuideType, Map<String, int>>{
    GuideType.umrah: {
      'U01': 2,
      'U02': 3,
      'U03': 1,
      'U04': 1,
      'U05': 1,
      'U06': 3,
      'U07': 2,
      'U08': 1,
      'U09': 2,
      'U10': 2,
    },
    GuideType.hajj: {
      'H01': 3,
      'H02': 5,
      'H03': 3,
      'H04': 4,
      'H05': 3,
      'H06': 4,
      'H07': 3,
      'H08': 4,
      'H09': 3,
      'H10': 3,
    },
  };

  final int schemaVersion;
  final String contentVersion;
  final GuideType type;
  final List<GuideStep> steps;
  final Map<String, AudioRecord> audioRecords;
  final Map<String, PrayerRecord> prayerRecords;

  GuideStep? stepById(String id) {
    for (final step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  bool isProfileFlowVerified(HajjProfile profile) =>
      type == GuideType.hajj &&
      steps.every(
        (step) =>
            step.isApproved &&
            step.profileApplicability[profile] !=
                ProfileApplicability.unverified,
      );

  List<GuideStep> stepsForProfile(HajjProfile? profile) {
    if (type == GuideType.umrah) return steps;
    if (profile == null) {
      throw ArgumentError('Hac akışı için profil seçilmeli.');
    }
    if (!isProfileFlowVerified(profile)) return steps;
    return List.unmodifiable(
      steps.where(
        (step) =>
            step.profileApplicability[profile] ==
            ProfileApplicability.applicable,
      ),
    );
  }

  GuideStep? nextStep(GuideStep step, {HajjProfile? profile}) {
    final flow = stepsForProfile(profile);
    final index = flow.indexWhere((candidate) => candidate.id == step.id);
    return index >= 0 && index + 1 < flow.length ? flow[index + 1] : null;
  }

  GuideStep? previousStep(GuideStep step, {HajjProfile? profile}) {
    final flow = stepsForProfile(profile);
    final index = flow.indexWhere((candidate) => candidate.id == step.id);
    return index > 0 ? flow[index - 1] : null;
  }

  bool get isPreview => steps.any(
    (step) =>
        !step.isApproved ||
        (type == GuideType.hajj &&
            step.profileApplicability.values.contains(
              ProfileApplicability.unverified,
            )) ||
        step.prayerIds.any((id) => !prayerRecords[id]!.isApproved),
  );

  factory GuideCatalog.fromJsonText(String text) {
    final decoded = _object(jsonDecode(text), 'Katalog');
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Desteklenmeyen içerik şeması.');
    }
    final type = _enumByName(
      GuideType.values,
      _requiredString(decoded, 'guideType'),
      'guideType',
    );
    final contentVersion = _requiredString(decoded, 'contentVersion');
    final audioRecords = <String, AudioRecord>{};
    for (final item in _list(decoded, 'audioRecords')) {
      final record = AudioRecord.fromJson(_object(item, 'audioRecord'));
      if (audioRecords.containsKey(record.id)) {
        throw FormatException('Tekrarlanan ses kimliği: ${record.id}');
      }
      audioRecords[record.id] = record;
    }
    final prayerRecords = <String, PrayerRecord>{};
    for (final item in _list(decoded, 'prayerRecords')) {
      final record = PrayerRecord.fromJson(_object(item, 'prayerRecord'));
      if (prayerRecords.containsKey(record.id)) {
        throw FormatException('Tekrarlanan dua kimliği: ${record.id}');
      }
      prayerRecords[record.id] = record;
    }
    final steps =
        _list(decoded, 'steps')
            .map((item) => GuideStep.fromJson(_object(item, 'step'), type))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final groups = expectedGroups[type]!;
    final expectedIds = <String>[
      for (final group in groups.entries)
        for (var number = 1; number <= group.value; number++)
          '${group.key}.$number',
    ];
    if (steps.length != expectedIds.length ||
        steps.map((s) => s.id).toSet().length != expectedIds.length) {
      throw FormatException('${type.label} kimlik sayısı yanlış.');
    }
    final stepIds = steps.map((step) => step.id).toSet();
    if (audioRecords.keys.any(stepIds.contains) ||
        prayerRecords.keys.any(stepIds.contains) ||
        audioRecords.keys.any(prayerRecords.containsKey)) {
      throw const FormatException('Adım, ses ve dua kimlikleri ayrı olmalı.');
    }
    for (var index = 0; index < steps.length; index++) {
      final step = steps[index];
      if (step.order != index + 1 ||
          step.id != expectedIds[index] ||
          step.groupId != step.id.split('.').first) {
        throw FormatException('Geçersiz adım sırası/kimliği: ${step.id}');
      }
      if (step.linkedAudioIds.toSet().length != step.linkedAudioIds.length) {
        throw FormatException('Tekrarlanan ses bağlantısı: ${step.id}');
      }
      for (final audioId in step.linkedAudioIds) {
        if (!audioRecords.containsKey(audioId)) {
          throw FormatException('Kırık ses bağlantısı: ${step.id}');
        }
      }
      for (final prayerId in step.prayerIds) {
        if (!prayerRecords.containsKey(prayerId)) {
          throw FormatException('Kırık dua bağlantısı: ${step.id}');
        }
      }
    }
    for (final prayer in prayerRecords.values) {
      if (prayer.linkedAudioIds.toSet().length !=
          prayer.linkedAudioIds.length) {
        throw FormatException('Tekrarlanan dua sesi: ${prayer.id}');
      }
      for (final audioId in prayer.linkedAudioIds) {
        if (!audioRecords.containsKey(audioId)) {
          throw FormatException('Kırık dua sesi: ${prayer.id}');
        }
      }
    }
    for (final audio in audioRecords.values) {
      final targetStep = steps
          .where((step) => step.id == audio.textId)
          .firstOrNull;
      final targetPrayer = prayerRecords[audio.textId];
      if (audio.textId != null && targetStep == null && targetPrayer == null) {
        throw FormatException('Ses ${audio.id} bilinmeyen metne bağlı.');
      }
      final targetVersion =
          targetStep?.textVersion ?? targetPrayer?.textVersion;
      if (audio.textId != null &&
          (targetVersion == null || audio.textVersion != targetVersion)) {
        throw FormatException('Ses ${audio.id} metin sürümü uyuşmuyor.');
      }
      if (audio.status == ReviewStatus.approved &&
          targetStep?.status != ReviewStatus.approved &&
          targetPrayer?.status != ReviewStatus.approved) {
        throw FormatException('Ses ${audio.id} onaysız metne bağlı.');
      }
      if (targetStep != null && !targetStep.linkedAudioIds.contains(audio.id) ||
          targetPrayer != null &&
              !targetPrayer.linkedAudioIds.contains(audio.id)) {
        throw FormatException('Ses ${audio.id} metinden geri bağlantı ister.');
      }
    }
    for (final step in steps) {
      for (final audioId in step.linkedAudioIds) {
        if (audioRecords[audioId]!.textId != step.id) {
          throw FormatException('Ses $audioId yanlış adıma bağlı.');
        }
      }
    }
    for (final prayer in prayerRecords.values) {
      for (final audioId in prayer.linkedAudioIds) {
        if (audioRecords[audioId]!.textId != prayer.id) {
          throw FormatException('Ses $audioId yanlış duaya bağlı.');
        }
      }
    }
    if (type == GuideType.umrah) {
      final counters = {
        for (final step in steps)
          if (step.counterKey != null) step.counterKey!: step.id,
      };
      if (counters.length != 2 ||
          counters['tawaf'] != 'U06.2' ||
          counters['say'] != 'U09.2' ||
          steps.where((s) => s.counterKey != null).length != 2) {
        throw const FormatException('Umre sayaç bağlantıları geçersiz.');
      }
    } else {
      final counters = {
        for (final step in steps)
          if (step.counterKey != null) step.id: step.counterKey,
      };
      if (counters.length != 2 ||
          counters['H06.3'] != 'jamarat' ||
          counters['H09.2'] != 'jamarat') {
        throw const FormatException('Hac sayaç bağlantıları geçersiz.');
      }
    }
    return GuideCatalog._(
      schemaVersion: 1,
      contentVersion: contentVersion,
      type: type,
      steps: List.unmodifiable(steps),
      audioRecords: Map.unmodifiable(audioRecords),
      prayerRecords: Map.unmodifiable(prayerRecords),
    );
  }
}
