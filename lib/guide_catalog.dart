import 'dart:convert';

import 'package:flutter/services.dart';

enum GuideMode { learning, journey }

extension GuideModeLabel on GuideMode {
  String get label =>
      this == GuideMode.learning ? 'Öğrenme' : 'Yolculukta rehber';
  String get databaseValue => name;
}

enum ReviewStatus { inventory, reviewed, published }

class GuideStep {
  const GuideStep({
    required this.id,
    required this.order,
    required this.group,
    required this.title,
    required this.status,
    this.summary,
    this.fullText,
    this.sourceReference,
    this.reviewedBy,
    this.audioAsset,
    this.audioRights,
    this.counterKey,
  });

  final String id;
  final int order;
  final String group;
  final String title;
  final ReviewStatus status;
  final String? summary;
  final String? fullText;
  final String? sourceReference;
  final String? reviewedBy;
  final String? audioAsset;
  final String? audioRights;
  final String? counterKey;

  bool get isPublished => status == ReviewStatus.published;

  factory GuideStep.fromJson(Map<String, Object?> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Step field "$key" is required.');
      }
      return value.trim();
    }

    String? optionalString(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw FormatException('Invalid "$key" field.');
      return value.trim().isEmpty ? null : value.trim();
    }

    final order = json['order'];
    if (order is! int || order < 1) {
      throw const FormatException('Step order must be a positive integer.');
    }
    final statusName = requiredString('status');
    final status = ReviewStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => throw FormatException('Unknown status: $statusName'),
    );
    final step = GuideStep(
      id: requiredString('id'),
      order: order,
      group: requiredString('group'),
      title: requiredString('title'),
      status: status,
      summary: optionalString('summary'),
      fullText: optionalString('fullText'),
      sourceReference: optionalString('sourceReference'),
      reviewedBy: optionalString('reviewedBy'),
      audioAsset: optionalString('audioAsset'),
      audioRights: optionalString('audioRights'),
      counterKey: optionalString('counterKey'),
    );
    if (status == ReviewStatus.published &&
        [
          step.summary,
          step.fullText,
          step.sourceReference,
          step.reviewedBy,
          step.audioAsset,
          step.audioRights,
        ].any((value) => value == null)) {
      throw FormatException(
        'Published step ${step.id} has missing approval data.',
      );
    }
    if (step.counterKey != null &&
        !const {'tawaf', 'say'}.contains(step.counterKey)) {
      throw FormatException('Unknown counter for ${step.id}.');
    }
    return step;
  }
}

class GuideCatalog {
  GuideCatalog._({
    required this.contentVersion,
    required this.guideType,
    required this.steps,
  });

  static const _umrahGroupCounts = {
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
  };

  final String contentVersion;
  final String guideType;
  final List<GuideStep> steps;

  GuideStep? stepById(String id) {
    for (final step in steps) {
      if (step.id == id) return step;
    }
    return null;
  }

  GuideStep? nextStep(GuideStep step) =>
      step.order < steps.length ? steps[step.order] : null;

  factory GuideCatalog.fromJsonText(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Catalog must be a JSON object.');
    }
    if (decoded['schemaVersion'] != 1 || decoded['guideType'] != 'umrah') {
      throw const FormatException('Unsupported catalog schema or guide type.');
    }
    final contentVersion = decoded['contentVersion'];
    if (contentVersion is! String || contentVersion.trim().isEmpty) {
      throw const FormatException('Catalog contentVersion is required.');
    }
    final rawSteps = decoded['steps'];
    if (rawSteps is! List) {
      throw const FormatException('Catalog steps must be a list.');
    }
    final steps = rawSteps.map((entry) {
      if (entry is! Map<String, Object?>) {
        throw const FormatException('Catalog step must be an object.');
      }
      return GuideStep.fromJson(entry);
    }).toList()..sort((a, b) => a.order.compareTo(b.order));
    if (steps.length != 18 ||
        steps.map((step) => step.id).toSet().length != 18) {
      throw const FormatException('Umrah catalog needs 18 unique steps.');
    }
    for (var index = 0; index < steps.length; index++) {
      if (steps[index].order != index + 1) {
        throw const FormatException('Catalog order must be contiguous.');
      }
    }
    for (final group in _umrahGroupCounts.entries) {
      if (steps.where((step) => step.group == group.key).length !=
          group.value) {
        throw FormatException('Wrong count for ${group.key}.');
      }
    }
    if (steps.any((step) => !_umrahGroupCounts.containsKey(step.group))) {
      throw const FormatException('Unknown Umrah group.');
    }
    final counters = {
      for (final step in steps)
        if (step.counterKey != null) step.counterKey!: step,
    };
    if (counters['tawaf']?.group != 'U06' ||
        counters['say']?.group != 'U09' ||
        steps.where((step) => step.counterKey != null).length != 2 ||
        counters.length != 2) {
      throw const FormatException('Umrah counters are not mapped correctly.');
    }
    return GuideCatalog._(
      contentVersion: contentVersion,
      guideType: 'umrah',
      steps: List.unmodifiable(steps),
    );
  }

  static Future<GuideCatalog> loadAsset() async {
    final text = await rootBundle.loadString(
      'assets/content/umre_inventory.v1.json',
    );
    return GuideCatalog.fromJsonText(text);
  }
}
