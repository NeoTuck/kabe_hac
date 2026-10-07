import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'group_sync.dart';
import 'progress_store.dart';

bool validGroupId(String id) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(id);

class GroupRuntimeConfig {
  const GroupRuntimeConfig(this.url, this.publishableKey);
  final String url;
  final String publishableKey;
  static GroupRuntimeConfig? parse(String url, String key) {
    if (url.isEmpty && key.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !RegExp(r'^sb_publishable_[A-Za-z0-9_-]{16,}$').hasMatch(key)) {
      throw const FormatException('Kafile bağlantısı yapılandırılmadı.');
    }
    return GroupRuntimeConfig(uri.toString(), key);
  }

  static GroupRuntimeConfig? fromCompileTime() => parse(
    const String.fromEnvironment('SUPABASE_URL'),
    const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );
}

class GroupRecord {
  const GroupRecord(this.id, this.name);
  final String id;
  final String name;
}

class GroupAccessError extends StateError {
  GroupAccessError() : super('Grup erişimi kapandı.');
}

class MessageCursor {
  MessageCursor({required DateTime createdAt, required String id})
    : createdAt = createdAt.toUtc(),
      id = id.toLowerCase() {
    if (!validGroupId(id)) {
      throw const FormatException('Mesaj kimliği geçersiz.');
    }
  }
  final DateTime createdAt;
  final String id;

  factory MessageCursor.fromRow(Map<String, dynamic> row) {
    final time = DateTime.tryParse(row['created_at'].toString());
    final id = row['id'];
    if (time == null || id is! String) {
      throw const FormatException('Mesaj sayfalama bilgisi geçersiz.');
    }
    return MessageCursor(createdAt: time, id: id);
  }
}

class GroupMessagePage {
  const GroupMessagePage({required this.messages, required this.hasMore});
  final List<Map<String, dynamic>> messages;
  final bool hasMore;
}

class GroupSnapshot {
  const GroupSnapshot({
    required this.members,
    required this.messages,
    required this.announcements,
    required this.programs,
    required this.routes,
  });
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> announcements;
  final List<Map<String, dynamic>> programs;
  final List<Map<String, dynamic>> routes;
}

abstract class GroupRepository extends ChangeNotifier {
  bool get configured;
  String? get userId;
  Future<void> requestCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
  Future<List<GroupRecord>> groups();
  Future<String> acceptInvitation(String token);
  Future<GroupRecord> createGroup(String name);
  Future<String> createInvitation(String groupId);
  Future<GroupSnapshot> snapshot(String groupId);
  Future<GroupMessagePage> olderMessages(
    String groupId, {
    required MessageCursor before,
  });
  Future<void> send(GroupOutboxMessage message);
  Future<void> publish(String groupId, String kind, String title, String body);
  Future<void> Function() watch(
    String groupId,
    void Function(bool connected) refresh,
  );
}

class UnconfiguredGroupRepository extends GroupRepository {
  @override
  bool get configured => false;
  @override
  String? get userId => null;
  Never _unavailable() => throw StateError('Kafile hizmeti henüz açılmadı.');
  @override
  Future<void> requestCode(String email) async => _unavailable();
  @override
  Future<void> verifyCode(String email, String code) async => _unavailable();
  @override
  Future<void> signOut() async {}
  @override
  Future<List<GroupRecord>> groups() async => _unavailable();
  @override
  Future<String> acceptInvitation(String token) async => _unavailable();
  @override
  Future<GroupRecord> createGroup(String name) async => _unavailable();
  @override
  Future<String> createInvitation(String groupId) async => _unavailable();
  @override
  Future<GroupSnapshot> snapshot(String groupId) async => _unavailable();
  @override
  Future<GroupMessagePage> olderMessages(
    String groupId, {
    required MessageCursor before,
  }) async => _unavailable();
  @override
  Future<void> send(GroupOutboxMessage message) async => _unavailable();
  @override
  Future<void> publish(
    String groupId,
    String kind,
    String title,
    String body,
  ) async => _unavailable();
  @override
  Future<void> Function() watch(String groupId, void Function(bool) refresh) =>
      () async {};
}

class SupabaseGroupRepository extends GroupRepository {
  SupabaseGroupRepository(this.client) {
    _auth = client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
  final SupabaseClient client;
  late final StreamSubscription<AuthState> _auth;
  @override
  bool get configured => true;
  @override
  String? get userId => client.auth.currentUser?.id;
  String _user() => userId ?? (throw StateError('Oturum gerekli.'));
  void _id(String id) {
    if (!validGroupId(id)) {
      throw const FormatException('Grup kimliği geçersiz.');
    }
  }

  @override
  Future<void> requestCode(String email) =>
      client.auth.signInWithOtp(email: email);
  @override
  Future<void> verifyCode(String email, String code) async {
    await client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  @override
  Future<void> signOut() => client.auth.signOut();
  @override
  Future<List<GroupRecord>> groups() async {
    final uid = _user();
    final memberships = await client
        .from('group_members')
        .select('group_id')
        .eq('user_id', uid)
        .eq('status', 'active');
    final ids = memberships.map((m) => m['group_id'] as String).toList();
    if (ids.isEmpty) return [];
    final rows = await client
        .from('groups')
        .select('id,name')
        .inFilter('id', ids)
        .isFilter('archived_at', null)
        .order('created_at');
    if (userId != uid) throw StateError('Oturum değişti.');
    return rows
        .map((row) => GroupRecord(row['id'] as String, row['name'] as String))
        .toList();
  }

  @override
  Future<String> acceptInvitation(String token) async {
    _user();
    if (token.length < 24 || token.length > 256) {
      throw const FormatException('Davet kodu geçersiz.');
    }
    return await client.rpc(
      'accept_group_invitation',
      params: {'raw_token': token},
    ) as String;
  }

  @override
  Future<GroupRecord> createGroup(String name) async {
    _user();
    final id = await client.rpc(
      'create_personal_group',
      params: {'group_name': name.trim()},
    ) as String;
    return GroupRecord(id, name.trim());
  }

  @override
  Future<String> createInvitation(String groupId) async {
    _id(groupId);
    final token = base64Url
        .encode(List.generate(32, (_) => Random.secure().nextInt(256)))
        .replaceAll('=', '');
    await client.from('group_invitations').insert({
      'group_id': groupId,
      'token_digest': sha256.convert(utf8.encode(token)).toString(),
      'invited_role': 'member',
      'created_by': _user(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
      'max_uses': 1,
    });
    return token;
  }

  Future<void> _membership(String groupId, String uid) async {
    final membership = await client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId)
        .eq('user_id', uid)
        .eq('status', 'active')
        .maybeSingle();
    if (membership == null || uid != userId) {
      throw GroupAccessError();
    }
  }

  @override
  Future<GroupMessagePage> olderMessages(
    String groupId, {
    required MessageCursor before,
  }) async {
    _id(groupId);
    final uid = _user();
    await _membership(groupId, uid);
    final time = before.createdAt.toIso8601String();
    // UUID and canonical UTC timestamp are validated before raw filters.
    // Tie-break by ID: messages sharing a timestamp must not be skipped.
    final rows = await client
        .from('messages')
        .select()
        .eq('group_id', groupId)
        .or('created_at.lt.$time,and(created_at.eq.$time,id.lt.${before.id})')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(51);
    await _membership(groupId, uid);
    return GroupMessagePage(
      messages: rows.take(50).toList().reversed.toList(),
      hasMore: rows.length > 50,
    );
  }

  @override
  Future<GroupSnapshot> snapshot(String groupId) async {
    _id(groupId);
    final uid = _user();
    await _membership(groupId, uid);
    final results = await Future.wait([
      client
          .from('group_members')
          .select('user_id,role,status')
          .eq('group_id', groupId)
          .eq('status', 'active'),
      client
          .from('messages')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(100),
      client
          .from('announcements')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(50),
      client
          .from('group_programs')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(50),
      client
          .from('group_routes')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false)
          .limit(50),
    ]);
    // Recheck on resync; old UI data is cleared if membership/session is revoked.
    await _membership(groupId, uid);
    return GroupSnapshot(
      members: results[0],
      messages: results[1].reversed.toList(),
      announcements: results[2],
      programs: results[3],
      routes: results[4],
    );
  }

  @override
  Future<void> send(GroupOutboxMessage message) async {
    final uid = _user();
    _id(message.groupId);
    if (message.ownerUserId != uid) throw StateError('Mesaj başka hesaba ait.');
    await _membership(message.groupId, uid);
    final row = {
      'group_id': message.groupId,
      'sender_id': uid,
      'client_id': message.clientId,
      'body': message.body,
      'recipient_id': message.recipientId,
      'message_type': message.recipientId == null ? 'chat' : 'guide_private',
    };
    // Retry with INSERT ... ON CONFLICT DO NOTHING, never a broad UPDATE.
    await client
        .from('messages')
        .upsert(row, onConflict: 'sender_id,client_id', ignoreDuplicates: true);
    final confirmed = await client
        .from('messages')
        .select('group_id,body,recipient_id')
        .eq('sender_id', uid)
        .eq('client_id', message.clientId)
        .single();
    if (confirmed['group_id'] != message.groupId ||
        confirmed['body'] != message.body ||
        confirmed['recipient_id'] != message.recipientId) {
      throw StateError('Mesaj istemci kimliği uyuşmuyor.');
    }
    if (userId != uid) throw StateError('Oturum değişti.');
  }

  @override
  Future<void> publish(
    String groupId,
    String kind,
    String title,
    String body,
  ) async {
    _id(groupId);
    final uid = _user();
    final now = DateTime.now().toUtc();
    if (kind == 'announcement') {
      await client.from('announcements').insert({
        'group_id': groupId,
        'author_id': uid,
        'title': title,
        'body': body,
      });
    } else if (kind == 'program') {
      await client.from('group_programs').insert({
        'group_id': groupId,
        'created_by': uid,
        'version': 1,
        'title': title,
        'program_date': now.toIso8601String().split('T').first,
        'document': {'notes': body},
      });
    } else {
      throw ArgumentError.value(kind, 'kind');
    }
  }

  @override
  Future<void> Function() watch(
    String groupId,
    void Function(bool connected) refresh,
  ) {
    _id(groupId);
    final channel = client.channel(
      'group:$groupId',
      opts: const RealtimeChannelConfig(private: true),
    );
    for (final table in [
      'messages',
      'announcements',
      'group_programs',
      'group_routes',
      'group_members',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'group_id',
          value: groupId,
        ),
        callback: (_) => refresh(true),
      );
    }
    channel.subscribe(
      (status, _) => refresh(status == RealtimeSubscribeStatus.subscribed),
    );
    return () async {
      await client.removeChannel(channel);
    };
  }

  @override
  void dispose() {
    unawaited(_auth.cancel());
    super.dispose();
  }
}

class GroupOutboxSynchronizer {
  GroupOutboxSynchronizer(this.store, this.repository);
  final ProgressStore store;
  final GroupRepository repository;
  Future<void>? _running;
  Future<void> sync(String groupId) {
    final current = _running;
    if (current != null) return current;
    final run = _sync(groupId);
    _running = run;
    return run.whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
  }

  Future<void> _sync(String groupId) async {
    final uid = repository.userId;
    if (!repository.configured || uid == null) return;
    for (final message in await store.readGroupOutbox()) {
      if (message.ownerUserId != uid ||
          message.groupId != groupId ||
          message.status == MessageOutboxStatus.sent) {
        continue;
      }
      if (repository.userId != uid) return;
      try {
        await repository.send(message);
        if (repository.userId != uid) return;
        await store.markGroupMessageAttempt(
          clientId: message.clientId,
          status: MessageOutboxStatus.sent,
        );
      } catch (_) {
        if (repository.userId != uid) return;
        await store.markGroupMessageAttempt(
          clientId: message.clientId,
          status: MessageOutboxStatus.failed,
          error: 'Gönderilemedi; bağlantı ve grup erişimini kontrol et.',
        );
      }
    }
  }
}
