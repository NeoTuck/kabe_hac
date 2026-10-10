enum MessageOutboxStatus { pending, sent, failed }

class GroupOutboxMessage {
  const GroupOutboxMessage({
    required this.clientId,
    required this.groupId,
    required this.body,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.ownerUserId,
    this.recipientId,
    this.lastError,
  });

  final String? ownerUserId;
  final String clientId;
  final String groupId;
  final String? recipientId;
  final String body;
  final MessageOutboxStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastError;
}

enum LocationShareMode { oneTime, trip }

class LocalLocationShare {
  const LocalLocationShare({
    required this.groupId,
    required this.mode,
    required this.enabled,
    required this.startedAt,
    required this.endsAt,
    this.stoppedAt,
  });

  final String groupId;
  final LocationShareMode mode;
  final bool enabled;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? stoppedAt;

  bool isActiveAt(DateTime now) =>
      enabled &&
      stoppedAt == null &&
      !now.isBefore(startedAt) &&
      now.isBefore(endsAt);
}

class SharedLocationUpdate {
  const SharedLocationUpdate({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.measuredAt,
    required this.sentAt,
  }) : assert(latitude >= -90 && latitude <= 90),
       assert(longitude >= -180 && longitude <= 180),
       assert(accuracyMeters >= 0);

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime measuredAt;
  final DateTime sentAt;

  bool isStaleAt(
    DateTime now, {
    Duration maximumAge = const Duration(minutes: 5),
  }) {
    return measuredAt.isAfter(now) ||
        sentAt.isAfter(now) ||
        sentAt.isBefore(measuredAt) ||
        now.difference(measuredAt) > maximumAge ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        !accuracyMeters.isFinite;
  }
}
