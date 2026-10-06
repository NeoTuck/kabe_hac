import 'dart:convert';

enum SafetyReviewStatus { draft, pendingReview, approved }

enum ContactKind { groupLeader, company, consulate, police, emergency, health }

enum LanguageCardCategory {
  directions,
  hotel,
  food,
  shopping,
  transport,
  lost,
  pharmacy,
  health,
  help,
}

enum FieldInformationState { planned, lastKnown, live }

enum InformationSourceKind { official, company, userReport }

class SafetyCatalogFormatException implements Exception {
  const SafetyCatalogFormatException(this.message);

  final String message;

  @override
  String toString() => 'SafetyCatalogFormatException: $message';
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw SafetyCatalogFormatException('Zorunlu alan eksik: $key');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw SafetyCatalogFormatException('Geçersiz alan: $key');
  }
  return value.trim().isEmpty ? null : value.trim();
}

T _enumValue<T extends Enum>(List<T> values, String raw, String field) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw SafetyCatalogFormatException('Geçersiz $field: $raw');
}

Uri _httpsUri(Map<String, Object?> json, String key) {
  final raw = _requiredString(json, key);
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw SafetyCatalogFormatException('Geçersiz bağlantı: $key');
  }
  return uri;
}

DateTime _utcDateTime(Map<String, Object?> json, String key) {
  final raw = _requiredString(json, key);
  final value = DateTime.tryParse(raw);
  if (value == null || !value.isUtc) {
    throw SafetyCatalogFormatException('$key UTC ISO-8601 olmalı.');
  }
  return value;
}

class SafetyContact {
  const SafetyContact({
    required this.id,
    required this.kind,
    required this.name,
    required this.region,
    required this.phone,
    required this.languages,
    required this.sourceTitle,
    required this.sourceUri,
    required this.verifiedAt,
    required this.status,
  });

  final String id;
  final ContactKind kind;
  final String name;
  final String region;
  final String? phone;
  final List<String> languages;
  final String sourceTitle;
  final Uri sourceUri;
  final DateTime verifiedAt;
  final SafetyReviewStatus status;

  factory SafetyContact.fromJson(Map<String, Object?> json) {
    final rawLanguages = json['languages'];
    if (rawLanguages is! List || rawLanguages.isEmpty) {
      throw const SafetyCatalogFormatException('İletişim dilleri gerekli.');
    }
    final languages = <String>[];
    for (final value in rawLanguages) {
      if (value is! String || value.trim().isEmpty) {
        throw const SafetyCatalogFormatException('Geçersiz iletişim dili.');
      }
      languages.add(value.trim());
    }
    final status = _enumValue(
      SafetyReviewStatus.values,
      _requiredString(json, 'status'),
      'inceleme durumu',
    );
    final phone = _optionalString(json, 'phone');
    if (status == SafetyReviewStatus.approved && phone == null) {
      throw const SafetyCatalogFormatException(
        'Onaylı iletişim kaydı doğrulanmış numara ister.',
      );
    }
    return SafetyContact(
      id: _requiredString(json, 'id'),
      kind: _enumValue(
        ContactKind.values,
        _requiredString(json, 'kind'),
        'iletişim türü',
      ),
      name: _requiredString(json, 'name'),
      region: _requiredString(json, 'region'),
      phone: phone,
      languages: List.unmodifiable(languages),
      sourceTitle: _requiredString(json, 'sourceTitle'),
      sourceUri: _httpsUri(json, 'sourceUrl'),
      verifiedAt: _utcDateTime(json, 'verifiedAt'),
      status: status,
    );
  }
}

class LanguageCard {
  const LanguageCard({
    required this.id,
    required this.category,
    required this.turkish,
    required this.arabic,
    required this.transliteration,
    required this.status,
    required this.sourceTitle,
    required this.sourceUri,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.audioId,
  });

  final String id;
  final LanguageCardCategory category;
  final String turkish;
  final String? arabic;
  final String? transliteration;
  final SafetyReviewStatus status;
  final String? sourceTitle;
  final Uri? sourceUri;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? audioId;

  bool get isApproved => status == SafetyReviewStatus.approved;

  factory LanguageCard.fromJson(Map<String, Object?> json) {
    final status = _enumValue(
      SafetyReviewStatus.values,
      _requiredString(json, 'status'),
      'inceleme durumu',
    );
    final sourceTitle = _optionalString(json, 'sourceTitle');
    final sourceUrl = _optionalString(json, 'sourceUrl');
    final reviewedBy = _optionalString(json, 'reviewedBy');
    final reviewedAtRaw = _optionalString(json, 'reviewedAt');
    final reviewedAt = reviewedAtRaw == null
        ? null
        : DateTime.tryParse(reviewedAtRaw);
    Uri? sourceUri;
    if (sourceUrl != null) {
      sourceUri = Uri.tryParse(sourceUrl);
      if (sourceUri == null ||
          sourceUri.scheme != 'https' ||
          sourceUri.host.isEmpty) {
        throw const SafetyCatalogFormatException(
          'Dil kartı kaynak bağlantısı geçersiz.',
        );
      }
    }
    final arabic = _optionalString(json, 'arabic');
    if (status == SafetyReviewStatus.approved &&
        (arabic == null ||
            sourceTitle == null ||
            sourceUri == null ||
            reviewedBy == null ||
            reviewedAt == null)) {
      throw const SafetyCatalogFormatException(
        'Onaylı dil kartı Arapça, kaynak ve insan incelemesi ister.',
      );
    }
    return LanguageCard(
      id: _requiredString(json, 'id'),
      category: _enumValue(
        LanguageCardCategory.values,
        _requiredString(json, 'category'),
        'dil kartı kategorisi',
      ),
      turkish: _requiredString(json, 'turkish'),
      arabic: arabic,
      transliteration: _optionalString(json, 'transliteration'),
      status: status,
      sourceTitle: sourceTitle,
      sourceUri: sourceUri,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      audioId: _optionalString(json, 'audioId'),
    );
  }
}

class FieldInformation {
  const FieldInformation({
    required this.id,
    required this.title,
    required this.value,
    required this.state,
    required this.sourceKind,
    required this.sourceTitle,
    required this.sourceUri,
    required this.observedAt,
    required this.validUntil,
  });

  final String id;
  final String title;
  final String value;
  final FieldInformationState state;
  final InformationSourceKind sourceKind;
  final String sourceTitle;
  final Uri sourceUri;
  final DateTime observedAt;
  final DateTime validUntil;

  bool isFreshAt(DateTime now) => !now.toUtc().isAfter(validUntil);

  String displayStateAt(DateTime now) {
    if (!isFreshAt(now)) return 'Süresi dolmuş bilgi';
    return switch (state) {
      FieldInformationState.planned => 'Planlanmış bilgi',
      FieldInformationState.lastKnown => 'Son bilinen bilgi',
      FieldInformationState.live => 'Güncel kaynak bilgisi',
    };
  }

  factory FieldInformation.fromJson(Map<String, Object?> json) {
    final observedAt = _utcDateTime(json, 'observedAt');
    final validUntil = _utcDateTime(json, 'validUntil');
    if (validUntil.isBefore(observedAt)) {
      throw const SafetyCatalogFormatException(
        'Bilgi geçerlilik aralığı ters.',
      );
    }
    final state = _enumValue(
      FieldInformationState.values,
      _requiredString(json, 'state'),
      'saha bilgisi durumu',
    );
    final sourceKind = _enumValue(
      InformationSourceKind.values,
      _requiredString(json, 'sourceKind'),
      'bilgi kaynağı',
    );
    if (state == FieldInformationState.live &&
        sourceKind == InformationSourceKind.userReport) {
      throw const SafetyCatalogFormatException(
        'Kullanıcı bildirimi canlı resmî durum olarak işaretlenemez.',
      );
    }
    return FieldInformation(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      value: _requiredString(json, 'value'),
      state: state,
      sourceKind: sourceKind,
      sourceTitle: _requiredString(json, 'sourceTitle'),
      sourceUri: _httpsUri(json, 'sourceUrl'),
      observedAt: observedAt,
      validUntil: validUntil,
    );
  }
}

class SafetyCatalog {
  const SafetyCatalog({
    required this.dataVersion,
    required this.contacts,
    required this.languageCards,
    required this.fieldInformation,
  });

  final String dataVersion;
  final List<SafetyContact> contacts;
  final List<LanguageCard> languageCards;
  final List<FieldInformation> fieldInformation;

  factory SafetyCatalog.fromJsonText(String text) {
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const SafetyCatalogFormatException(
        'Güvenli gezi verisi JSON değil.',
      );
    }
    if (decoded is! Map) {
      throw const SafetyCatalogFormatException(
        'Güvenli gezi verisi nesne olmalı.',
      );
    }
    final json = Map<String, Object?>.from(decoded);
    if (json['schemaVersion'] != 1) {
      throw const SafetyCatalogFormatException('Desteklenmeyen veri şeması.');
    }
    List<T> parseList<T>(String key, T Function(Map<String, Object?>) parser) {
      final values = json[key];
      if (values is! List) {
        throw SafetyCatalogFormatException('$key liste olmalı.');
      }
      return [
        for (final value in values)
          if (value is Map)
            parser(Map<String, Object?>.from(value))
          else
            throw SafetyCatalogFormatException('$key kaydı nesne olmalı.'),
      ];
    }

    final contacts = parseList('contacts', SafetyContact.fromJson);
    final languageCards = parseList('languageCards', LanguageCard.fromJson);
    final fieldInformation = parseList(
      'fieldInformation',
      FieldInformation.fromJson,
    );
    final ids = <String>{};
    for (final id in [
      ...contacts.map((item) => item.id),
      ...languageCards.map((item) => item.id),
      ...fieldInformation.map((item) => item.id),
    ]) {
      if (!ids.add(id)) {
        throw SafetyCatalogFormatException('Tekrarlanan kayıt kimliği: $id');
      }
    }
    return SafetyCatalog(
      dataVersion: _requiredString(json, 'dataVersion'),
      contacts: List.unmodifiable(contacts),
      languageCards: List.unmodifiable(languageCards),
      fieldInformation: List.unmodifiable(fieldInformation),
    );
  }
}
