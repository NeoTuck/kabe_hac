import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_repository.dart';
import 'group_sync.dart';
import 'progress_store.dart';

class LocationShareException implements Exception {
  const LocationShareException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecentSharedLocation {
  const RecentSharedLocation({
    required this.userId,
    required this.update,
    required this.endsAt,
  });

  final String userId;
  final SharedLocationUpdate update;
  final DateTime endsAt;

  bool isVisibleAt(DateTime now) =>
      now.isBefore(endsAt) &&
      !update.isStaleAt(now, maximumAge: const Duration(minutes: 5));
}

abstract class DeviceLocationReader {
  const DeviceLocationReader();
  Future<SharedLocationUpdate> measure();
}

class GeolocatorLocationReader extends DeviceLocationReader {
  const GeolocatorLocationReader();

  @override
  Future<SharedLocationUpdate> measure() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationShareException('Cihaz konum hizmeti kapalı.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationShareException(
        'Konum izni verilmedi. Cihaz ayarlarından değiştirebilirsin.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final update = SharedLocationUpdate(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      measuredAt: position.timestamp.toUtc(),
      sentAt: DateTime.now().toUtc(),
    );
    if (update.isStaleAt(
      update.sentAt,
      maximumAge: const Duration(minutes: 2),
    )) {
      throw const LocationShareException(
        'Güncel konum alınamadı. Tekrar dene.',
      );
    }
    return update;
  }
}

abstract class LocationShareRemote {
  const LocationShareRemote();
  Future<String> open(String groupId, String userId, DateTime endsAt);
  Future<void> send(String shareId, String userId, SharedLocationUpdate update);
  Future<DateTime?> activeUntil(String groupId, String userId);
  Future<List<RecentSharedLocation>> recentForGroup(
    String groupId,
    String userId,
  );
  Future<void> stop(String groupId, String userId);
}

class SupabaseLocationShareRemote extends LocationShareRemote {
  const SupabaseLocationShareRemote(this.client);
  final SupabaseClient client;

  void _check(String groupId, String userId) {
    if (!validGroupId(groupId) ||
        !validGroupId(userId) ||
        client.auth.currentUser?.id != userId) {
      throw const LocationShareException('Kafile oturumu değişti.');
    }
  }

  @override
  Future<String> open(String groupId, String userId, DateTime endsAt) async {
    _check(groupId, userId);
    final row = await client
        .from('location_shares')
        .insert({
          'group_id': groupId,
          'user_id': userId,
          'mode': 'one_time',
          'ends_at': endsAt.toUtc().toIso8601String(),
          'retention_until': endsAt
              .toUtc()
              .add(const Duration(days: 1))
              .toIso8601String(),
        })
        .select('id')
        .single();
    _check(groupId, userId);
    return row['id'] as String;
  }

  @override
  Future<void> send(
    String shareId,
    String userId,
    SharedLocationUpdate update,
  ) async {
    if (!validGroupId(shareId) || client.auth.currentUser?.id != userId) {
      throw const LocationShareException('Konum paylaşım oturumu değişti.');
    }
    await client.from('location_updates').insert({
      'share_id': shareId,
      'user_id': userId,
      'latitude': update.latitude,
      'longitude': update.longitude,
      'accuracy_meters': update.accuracyMeters,
      'measured_at': update.measuredAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<DateTime?> activeUntil(String groupId, String userId) async {
    _check(groupId, userId);
    final row = await client
        .from('location_shares')
        .select('ends_at')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('status', 'active')
        .gt('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    _check(groupId, userId);
    return row == null
        ? null
        : DateTime.tryParse(row['ends_at'].toString())?.toUtc();
  }

  @override
  Future<List<RecentSharedLocation>> recentForGroup(
    String groupId,
    String userId,
  ) async {
    _check(groupId, userId);
    final now = DateTime.now().toUtc();
    // RLS returns only the caller's own shares or active shares visible to a
    // current group manager. The UI additionally checks the current role.
    final shares = await client
        .from('location_shares')
        .select('id,user_id,ends_at')
        .eq('group_id', groupId)
        .eq('status', 'active')
        .gt('ends_at', now.toIso8601String())
        .order('created_at', ascending: false)
        .limit(30);
    final result = <RecentSharedLocation>[];
    for (final share in shares) {
      _check(groupId, userId);
      final shareId = share['id'];
      final ownerId = share['user_id'];
      final endsAt = DateTime.tryParse(share['ends_at'].toString())?.toUtc();
      if (shareId is! String ||
          ownerId is! String ||
          ownerId == userId ||
          endsAt == null) {
        continue;
      }
      final row = await client
          .from('location_updates')
          .select('latitude,longitude,accuracy_meters,measured_at,sent_at')
          .eq('share_id', shareId)
          .order('measured_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null ||
          row['latitude'] is! num ||
          row['longitude'] is! num ||
          row['accuracy_meters'] is! num) {
        continue;
      }
      final measuredAt = DateTime.tryParse(row['measured_at'].toString())
          ?.toUtc();
      final sentAt = DateTime.tryParse(row['sent_at'].toString())?.toUtc();
      if (measuredAt == null || sentAt == null) continue;
      final latitude = (row['latitude'] as num).toDouble();
      final longitude = (row['longitude'] as num).toDouble();
      final accuracy = (row['accuracy_meters'] as num).toDouble();
      if (!latitude.isFinite ||
          latitude < -90 ||
          latitude > 90 ||
          !longitude.isFinite ||
          longitude < -180 ||
          longitude > 180 ||
          !accuracy.isFinite ||
          accuracy < 0) {
        continue;
      }
      final location = RecentSharedLocation(
        userId: ownerId,
        endsAt: endsAt,
        update: SharedLocationUpdate(
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracy,
          measuredAt: measuredAt,
          sentAt: sentAt,
        ),
      );
      if (location.isVisibleAt(now)) result.add(location);
    }
    _check(groupId, userId);
    return result;
  }

  @override
  Future<void> stop(String groupId, String userId) async {
    _check(groupId, userId);
    await client
        .from('location_shares')
        .update({
          'status': 'stopped',
          'stopped_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .eq('status', 'active');
  }
}

class LocationShareCoordinator {
  LocationShareCoordinator({
    required this.store,
    required this.reader,
    required this.remote,
    required this.currentUserId,
  });

  final ProgressStore store;
  final DeviceLocationReader reader;
  final LocationShareRemote remote;
  final String? Function() currentUserId;
  static const duration = Duration(minutes: 15);
  int _generation = 0;

  void cancelPending() => _generation++;

  Future<DateTime?> activeUntil(String groupId) async {
    final userId = currentUserId();
    if (userId == null) return null;
    return remote.activeUntil(groupId, userId);
  }

  Future<List<RecentSharedLocation>> recentForGroup(String groupId) async {
    final userId = currentUserId();
    if (userId == null || !validGroupId(groupId)) {
      throw const LocationShareException('Kafile oturumu gerekli.');
    }
    final locations = await remote.recentForGroup(groupId, userId);
    if (currentUserId() != userId) {
      throw const LocationShareException('Kafile oturumu değişti.');
    }
    final now = DateTime.now().toUtc();
    return locations
        .where(
          (location) => location.userId != userId && location.isVisibleAt(now),
        )
        .toList();
  }

  Future<SharedLocationUpdate> shareOnce(String groupId) async {
    final generation = ++_generation;
    final userId = currentUserId();
    if (userId == null || !validGroupId(groupId)) {
      throw const LocationShareException('Kafile oturumu gerekli.');
    }
    // Permission and GPS are requested only after the user taps the explicit
    // confirmation button. Nothing is sent before both are available.
    final update = await reader.measure();
    if (generation != _generation ||
        currentUserId() != userId ||
        update.isStaleAt(DateTime.now().toUtc())) {
      throw const LocationShareException('Konum veya oturum güncel değil.');
    }
    final endsAt = DateTime.now().toUtc().add(duration);
    final shareId = await remote.open(groupId, userId, endsAt);
    try {
      if (generation != _generation || currentUserId() != userId) {
        throw const LocationShareException('Kafile oturumu değişti.');
      }
      await store.startLocationShare(
        groupId: groupId,
        mode: LocationShareMode.oneTime,
        duration: duration,
      );
      final consent = await store.readLocationShare(groupId);
      if (generation != _generation ||
          currentUserId() != userId ||
          consent == null ||
          !consent.isActiveAt(DateTime.now())) {
        throw const LocationShareException('Konum paylaşım izni kapandı.');
      }
      await remote.send(shareId, userId, update);
      return update;
    } catch (_) {
      await store.stopLocationShare(groupId);
      if (currentUserId() == userId) {
        try {
          await remote.stop(groupId, userId);
        } catch (_) {
          // The UI reports the original send failure; server expiry is bounded.
        }
      }
      rethrow;
    }
  }

  Future<void> stop(String groupId) async {
    cancelPending();
    final userId = currentUserId();
    await store.stopLocationShare(groupId);
    if (userId == null) {
      throw const LocationShareException(
        'Yerel paylaşım durdu; sunucu iptali için oturum gerekli.',
      );
    }
    await remote.stop(groupId, userId);
  }
}
