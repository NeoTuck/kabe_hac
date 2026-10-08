import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_repository.dart';
import 'progress_store.dart';

class PushException implements Exception {
  const PushException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PushRuntimeConfig {
  const PushRuntimeConfig({
    required this.apiKey,
    required this.appId,
    required this.senderId,
    required this.projectId,
  });
  final String apiKey;
  final String appId;
  final String senderId;
  final String projectId;

  static PushRuntimeConfig? fromCompileTime() {
    const fields = [
      String.fromEnvironment('FIREBASE_API_KEY'),
      String.fromEnvironment('FIREBASE_APP_ID'),
      String.fromEnvironment('FIREBASE_SENDER_ID'),
      String.fromEnvironment('FIREBASE_PROJECT_ID'),
    ];
    if (fields.every((value) => value.isEmpty)) return null;
    if (fields.any((value) => value.trim().isEmpty)) {
      throw const FormatException('Bildirim projesi eksik yapılandırıldı.');
    }
    return PushRuntimeConfig(
      apiKey: fields[0],
      appId: fields[1],
      senderId: fields[2],
      projectId: fields[3],
    );
  }

  FirebaseOptions get firebaseOptions => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
  );
}

abstract class PushTokenSource {
  const PushTokenSource();
  Future<String?> requestToken();
  Future<String?> currentToken();
  Stream<String> get tokenRefreshes;
  Future<void> deleteToken();
}

class FirebasePushTokenSource extends PushTokenSource {
  const FirebasePushTokenSource();

  @override
  Future<String?> requestToken() async {
    final messaging = FirebaseMessaging.instance;
    final permission = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (permission.authorizationStatus != AuthorizationStatus.authorized) {
      return null;
    }
    if (Platform.isIOS && await messaging.getAPNSToken() == null) {
      throw const PushException('Apple bildirim kaydı henüz hazır değil.');
    }
    await messaging.setAutoInitEnabled(true);
    return messaging.getToken();
  }

  @override
  Future<String?> currentToken() => FirebaseMessaging.instance.getToken();

  @override
  Stream<String> get tokenRefreshes =>
      FirebaseMessaging.instance.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
    await FirebaseMessaging.instance.deleteToken();
  }
}

abstract class PushTokenRemote {
  const PushTokenRemote();
  Future<void> register(String userId, String platform, String token);
  Future<void> revoke(String userId, String token);
}

class SupabasePushTokenRemote extends PushTokenRemote {
  const SupabasePushTokenRemote(this.client);
  final SupabaseClient client;

  void _check(String userId) {
    if (!validGroupId(userId) || client.auth.currentUser?.id != userId) {
      throw const PushException('Bildirim hesabı değişti.');
    }
  }

  @override
  Future<void> register(String userId, String platform, String token) async {
    _check(userId);
    if (!['android', 'ios'].contains(platform) ||
        token.isEmpty ||
        token.length > 4096) {
      throw const PushException('Geçersiz bildirim kaydı.');
    }
    await client.from('device_push_tokens').upsert({
      'user_id': userId,
      'platform': platform,
      'token': token,
      'enabled': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
    _check(userId);
  }

  @override
  Future<void> revoke(String userId, String token) async {
    _check(userId);
    await client
        .from('device_push_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('token', token);
  }
}

class PushRouteTarget {
  const PushRouteTarget(this.groupId, this.kind);
  final String groupId;
  final String kind;

  static PushRouteTarget? parse(Map<String, dynamic> data) {
    final id = data['group_id'];
    final kind = data['kind'];
    if (id is! String ||
        !validGroupId(id) ||
        kind is! String ||
        !['message', 'announcement', 'program'].contains(kind)) {
      return null;
    }
    return PushRouteTarget(id, kind);
  }
}

class PushTokenCoordinator extends ChangeNotifier {
  PushTokenCoordinator({
    required this.source,
    required this.remote,
    required this.currentUserId,
    required this.platform,
    required this.store,
  });
  final PushTokenSource source;
  final PushTokenRemote remote;
  final String? Function() currentUserId;
  final String platform;
  final ProgressStore store;
  static const _optInKey = 'push_opt_in_user';
  StreamSubscription<String>? _refreshSubscription;
  Future<void> _refreshTail = Future<void>.value();
  String? _registeredUser;
  String? _registeredToken;
  Future<void> _actions = Future<void>.value();
  bool _disposed = false;
  String? error;
  bool get enabled => _registeredUser != null;

  Future<void> _serial(Future<void> Function() action) {
    final run = _actions.then((_) async {
      if (_disposed) return;
      await action();
    });
    _actions = run.catchError((Object _) {});
    return run;
  }

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> resumeIfEnabled() => _serial(_resumeIfEnabled);
  Future<void> _resumeIfEnabled() async {
    final savedUser = await store.readAppValue(_optInKey);
    if (savedUser == null || savedUser.isEmpty) return;
    final userId = currentUserId();
    if (userId == null) return;
    if (userId != savedUser) {
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
      await source.deleteToken();
      await store.saveAppValue(_optInKey, '');
      _registeredUser = null;
      _registeredToken = null;
      _publish();
      return;
    }
    if (_registeredUser == userId) return;
    final token = await source.currentToken();
    if (token == null) {
      error = 'Bildirim kaydı yenilenemedi. Tekrar açmayı dene.';
      _publish();
      return;
    }
    await _registerAndListen(userId, token);
  }

  Future<void> enable() => _serial(_enable);
  Future<void> _enable() async {
    final userId = currentUserId();
    if (userId == null || !['android', 'ios'].contains(platform)) {
      throw const PushException('Kafile oturumu ve desteklenen cihaz gerekli.');
    }
    if (_registeredUser == userId) return;
    final token = await source.requestToken();
    if (token == null || currentUserId() != userId) {
      throw const PushException('Bildirim izni verilmedi veya oturum değişti.');
    }
    await _registerAndListen(userId, token);
    try {
      await store.saveAppValue(_optInKey, userId);
    } catch (_) {
      await _disable();
      rethrow;
    }
  }

  Future<void> _registerAndListen(String userId, String token) async {
    await remote.register(userId, platform, token);
    if (_disposed || currentUserId() != userId) {
      throw const PushException('Bildirim hesabı değişti.');
    }
    _registeredUser = userId;
    _registeredToken = token;
    error = null;
    await _refreshSubscription?.cancel();
    if (_disposed) return;
    _refreshSubscription = source.tokenRefreshes.listen((newToken) {
      if (_disposed || currentUserId() != userId || _registeredUser != userId) {
        return;
      }
      _refreshTail = _refreshTail.then((_) => _replaceToken(userId, newToken));
      unawaited(_refreshTail);
    });
    _publish();
  }

  Future<void> _replaceToken(String userId, String newToken) async {
    final oldToken = _registeredToken;
    if (_disposed || currentUserId() != userId || _registeredUser != userId) {
      return;
    }
    if (oldToken == null || oldToken == newToken) return;
    try {
      await remote.register(userId, platform, newToken);
      if (_disposed || currentUserId() != userId || _registeredUser != userId) {
        return;
      }
      await remote.revoke(userId, oldToken);
      _registeredToken = newToken;
      error = null;
      _publish();
    } catch (_) {
      error = 'Yeni bildirim kaydı sunucuya iletilemedi.';
      _publish();
    }
  }

  Future<void> disable() => _serial(_disable);
  Future<void> _disable() async {
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    await _refreshTail;
    final userId = _registeredUser;
    final token = _registeredToken;
    if (userId == null) {
      final savedUser = await store.readAppValue(_optInKey);
      if (savedUser == null || savedUser.isEmpty) return;
      final current = currentUserId();
      if (current == savedUser) {
        final existing = await source.currentToken();
        if (existing != null) await remote.revoke(savedUser, existing);
      }
      await source.deleteToken();
      await store.saveAppValue(_optInKey, '');
      _publish();
      return;
    }
    if (currentUserId() != userId) {
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
      _registeredUser = null;
      _registeredToken = null;
      await source.deleteToken();
      await store.saveAppValue(_optInKey, '');
      _publish();
      return;
    }
    if (token != null) await remote.revoke(userId, token);
    await source.deleteToken();
    await store.saveAppValue(_optInKey, '');
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _registeredUser = null;
    _registeredToken = null;
    error = null;
    _publish();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_refreshSubscription?.cancel());
    super.dispose();
  }
}
