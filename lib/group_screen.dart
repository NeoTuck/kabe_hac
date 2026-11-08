import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'group_repository.dart';
import 'group_message_composer.dart';
import 'group_sync.dart';
import 'location_share_service.dart';
import 'push_service.dart';
import 'progress_store.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({
    super.key,
    required this.repository,
    required this.store,
    this.push,
  });
  final GroupRepository repository;
  final ProgressStore store;
  final PushTokenCoordinator? push;
  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _invite = TextEditingController();
  final _chatMsgController = TextEditingController();
  final _privateMsgController = TextEditingController();
  int _classroomTab = 0;

  final List<Map<String, dynamic>> _announcements = [
    {
      'type': 'pinned',
      'author': 'Mustafa Hoca (Kafile Rehberi)',
      'time': 'Bugün 21:30',
      'title': '📌 Önemli Toplanma Duyurusu',
      'content': 'Kıymetli hacılarımız, yarın sabah saat 05:30’da otel lobisinde toplanıyoruz. İhramlar eksiksiz giyilmiş ve niyetler edilmiş olsun.',
    },
    {
      'type': 'route',
      'author': 'Mustafa Hoca (Kafile Rehberi)',
      'time': 'Bugün 18:00',
      'title': '🗺️ Hoca Rota Paylaştı',
      'content': 'Otelden Mescid-i Harâm Babü’l-Melik (Kral Kapısı) Yürüyüş Yolu (1.4 km · 18 dk)',
    },
    {
      'type': 'material',
      'author': 'Mustafa Hoca (Kafile Rehberi)',
      'time': 'Dün 16:45',
      'title': '📄 Tavaf ve Sa‘y Duaları Rehberi.pdf',
      'content': 'Harem-i Şerif’te yanınızda bulundurmanız gereken dualar ve Türkçe anlamları.',
    },
  ];

  final List<Map<String, String>> _groupChatMessages = [
    {
      'sender': 'Mustafa Hoca',
      'text': 'Esselamu aleyküm kafilemiz, herkes otele ulaştı mı?',
      'time': '20:15',
      'isHoca': 'true',
    },
    {
      'sender': 'Ahmet Yılmaz',
      'text': 'Aleyküm selam hocam, biz 4. kattayız dinleniyoruz.',
      'time': '20:18',
      'isHoca': 'false',
    },
    {
      'sender': 'Mehmet Demir',
      'text': 'Hocam sabah lobide görüşürüz inşallah.',
      'time': '20:25',
      'isHoca': 'false',
    },
  ];

  final List<Map<String, String>> _privateChatMessages = [
    {
      'sender': 'Ben',
      'text': 'Hocam, mikat yerini uçakta geçtikten sonra niyet getirsek geçerli olur mu?',
      'time': '19:40',
    },
    {
      'sender': 'Mustafa Hoca',
      'text': 'Kardeşim, uçak mikat hizasını geçmeden önce ihramı giyip niyet etmek esastır. Eğer gecikme olduysa indiğinizde hemen ihram niyetini ve telbiyeyi getirin.',
      'time': '19:50',
    },
  ];
  String? _emailSent;
  String? _error;
  bool _busy = false;
  List<GroupRecord>? _groups;
  bool? _accountDeletionRequested;
  String? _lastUser;
  ServiceTerms? _terms;
  @override
  void initState() {
    super.initState();
    _lastUser = widget.repository.userId;
    widget.repository.addListener(_authChanged);
    widget.push?.addListener(_pushChanged);
    if (_lastUser != null && widget.push != null) {
      unawaited(widget.push!.resumeIfEnabled().catchError((Object _) {}));
    }
    if (_lastUser != null) _load();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final savedAnnouncements = await widget.store.readAppValue(
        'local_announcements',
      );
      if (savedAnnouncements != null && savedAnnouncements.isNotEmpty) {
        final list = (jsonDecode(savedAnnouncements) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _announcements
              ..clear()
              ..addAll(list);
          });
        }
      }
      final savedGroup = await widget.store.readAppValue('local_group_chat');
      if (savedGroup != null && savedGroup.isNotEmpty) {
        final list = (jsonDecode(savedGroup) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _groupChatMessages
              ..clear()
              ..addAll(list);
          });
        }
      }
      final savedPrivate = await widget.store.readAppValue(
        'local_private_chat',
      );
      if (savedPrivate != null && savedPrivate.isNotEmpty) {
        final list = (jsonDecode(savedPrivate) as List)
            .map((e) => Map<String, String>.from(e as Map))
            .toList();
        if (mounted && list.isNotEmpty) {
          setState(() {
            _privateChatMessages
              ..clear()
              ..addAll(list);
          });
        }
      }
    } catch (_) {}
  }

  void _saveGroupChat() {
    try {
      widget.store.saveAppValue(
        'local_group_chat',
        jsonEncode(_groupChatMessages),
      );
    } catch (_) {}
  }

  void _savePrivateChat() {
    try {
      widget.store.saveAppValue(
        'local_private_chat',
        jsonEncode(_privateChatMessages),
      );
    } catch (_) {}
  }

  void _saveAnnouncements() {
    try {
      widget.store.saveAppValue(
        'local_announcements',
        jsonEncode(_announcements),
      );
    } catch (_) {}
  }

  Future<void> _replyFromHoca(String question) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _privateChatMessages.add({
        'sender': 'Mustafa Hoca',
        'text': 'Kardeşim sorunuzu aldım. Hac ve Umre ibadetinde esas olan ihlas ve niyetinizdir. İçiniz rahat olsun; adımları rehberdeki sıraya göre takip edin.',
        'time': 'Şimdi',
      });
    });
    _savePrivateChat();
  }

  void _authChanged() {
    if (!mounted) return;
    if (_lastUser != widget.repository.userId) {
      _lastUser = widget.repository.userId;
      setState(() {
        _groups = null;
        _terms = null;
        _accountDeletionRequested = null;
        _error = null;
        _emailSent = null;
      });
      if (_lastUser != null) unawaited(_load());
      if (_lastUser != null && widget.push != null) {
        unawaited(widget.push!.resumeIfEnabled().catchError((Object _) {}));
      } else if (widget.push != null) {
        unawaited(widget.push!.disable().catchError((Object _) {}));
      }
    } else {
      setState(() {});
    }
  }

  void _pushChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repository.removeListener(_authChanged);
    widget.push?.removeListener(_pushChanged);
    _email.dispose();
    _code.dispose();
    _invite.dispose();
    _chatMsgController.dispose();
    _privateMsgController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = widget.repository.userId;
    if (uid == null) return;
    try {
      final terms = await widget.repository.currentTerms();
      final groups = await widget.repository.groups();
      final deletionRequested = await widget.repository
          .accountDeletionRequested();
      if (mounted && uid == widget.repository.userId) {
        setState(() {
          _groups = groups;
          _terms = terms;
          _accountDeletionRequested = deletionRequested;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && uid == widget.repository.userId) {
        setState(() {
          _groups = null;
          _terms = null;
          _error = 'Kafileler alınamadı. Bağlantını kontrol edip tekrar dene.';
        });
      }
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    final user = widget.repository.userId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted || user != widget.repository.userId) return;
      if (isServiceTermsError(error)) {
        setState(() => _terms = null);
        await _load();
        if (mounted && user == widget.repository.userId) {
          setState(
            () => _error = _terms == null
                ? 'Güncel koşullar alınamadı. Bağlantını kontrol edip Kafileleri yenile; işlemin gönderilmedi.'
                : 'Kullanım koşulları değişti. Güncel sürümü okuyup kabul et, sonra işlemini yeniden dene.',
          );
        }
      } else {
        setState(
          () => _error = 'İşlem tamamlanamadı. Kod, bağlantı veya erişim iznini kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCode() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email.length > 254) {
      setState(() => _error = 'Geçerli bir e-posta adresi yaz.');
      return;
    }
    await _action(() async {
      await widget.repository.requestCode(email);
      if (mounted) setState(() => _emailSent = email);
    });
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kafile oluştur'),
        content: TextField(
          controller: controller,
          maxLength: 120,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kafile adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 2) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    // Wait until the dialog exit animation no longer uses its controller.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (name == null || !mounted) return;
    await _action(() async {
      await widget.repository.createGroup(name);
      await _load();
    });
  }

  Future<void> _requestAccountDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hesap silme isteği'),
        content: const Text(
          'İsteği göndermek hesabını hemen silmez. Açık konum paylaşımı ve bildirim kaydı durdurulur. Yetkili ekip isteği işleyip sonucu ayrıca bildirmelidir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İsteği gönder'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _action(() async {
      await widget.repository.requestAccountDeletion();
      if (mounted) setState(() => _accountDeletionRequested = true);
      try {
        await widget.push?.disable();
      } catch (_) {
        // The database trigger has already removed this user's token.
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesap silme isteği kaydedildi.')),
        );
      }
    });
  }

  Widget _buildClassroomSection(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Google Classroom Kafile Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: RehberTheme.hajjCardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: RehberTheme.gold.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 12,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: RehberTheme.gold.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: RehberTheme.gold,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Haremeyn 2026 Kafile No: 14',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mustafa Hoca · Kafile Başkanı & Din Görevlisi',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.vpn_key_rounded,
                          size: 14,
                          color: RehberTheme.goldLight,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width > 140
                                ? MediaQuery.of(context).size.width - 140
                                : 160,
                          ),
                          child: const Text(
                            'Katılım Kodu: KAF-2026',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Kafile hizmeti',
                    style: TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Push Notification Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 16,
                      color: RehberTheme.goldLight,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hocanın paylaştığı her şey uygulama kapalı olsa bile bildirim olarak düşer.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Subtabs
        Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E2F2A) : const Color(0xFFE8EFEA),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTabButton(
                0,
                'Duyurular (${_announcements.length})',
                Icons.campaign_rounded,
              ),
              _buildTabButton(1, 'Genel Sohbet', Icons.chat_rounded),
              _buildTabButton(2, 'Hocaya Özel 🔒', Icons.lock_person_rounded),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Selected Tab Content
        if (_classroomTab == 0) _buildAnnouncementsTab(dark),
        if (_classroomTab == 1) _buildGroupChatTab(dark),
        if (_classroomTab == 2) _buildPrivateChatTab(dark),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _classroomTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _classroomTab = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? RehberTheme.emerald : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementsTab(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in _announcements) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: item['type'] == 'pinned'
                    ? RehberTheme.emerald
                    : (dark ? Colors.white12 : Colors.black12),
                width: item['type'] == 'pinned' ? 1.5 : 1.0,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: item['type'] == 'route'
                            ? const Color(0xFF2E7D32)
                            : (item['type'] == 'material'
                                  ? const Color(0xFF1565C0)
                                  : RehberTheme.emerald),
                        child: Icon(
                          item['type'] == 'route'
                              ? Icons.alt_route_rounded
                              : (item['type'] == 'material'
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.push_pin_rounded),
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['author'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        item['time'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : RehberTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['content'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: dark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (item['type'] == 'route') ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hocanın rotası harita ekranında açılıyor…',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text('Rotayı Haritada Aç'),
                    ),
                  ],
                  if (item['type'] == 'material') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tavaf ve Sa‘y Duaları PDF’i açılıyor…',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Materyali İncele'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showAddAnnouncementDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Hocaya Duyuru veya Rota Öner'),
        ),
      ],
    );
  }

  void _showAddAnnouncementDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Duyuru / Not Paylaş'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Başlık (Örn: Lobi Buluşması)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açıklama / Mesajınız',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  _announcements.insert(0, {
                    'type': 'pinned',
                    'author': 'Mustafa Hoca',
                    'time': 'Şimdi',
                    'title': titleCtrl.text,
                    'content': contentCtrl.text,
                  });
                });
                _saveAnnouncements();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Duyuru kafile akışına eklendi.'),
                  ),
                );
              }
            },
            child: const Text('Yayınla'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatTab(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final msg in _groupChatMessages) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: msg['isHoca'] == 'true'
                              ? RehberTheme.emerald
                              : Colors.grey.shade400,
                          child: Icon(
                            msg['isHoca'] == 'true'
                                ? Icons.school_rounded
                                : Icons.person_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    msg['sender']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: msg['isHoca'] == 'true'
                                          ? RehberTheme.emerald
                                          : (dark
                                                ? Colors.white
                                                : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    msg['time']!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                msg['text']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: dark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 8),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatMsgController,
                        decoration: InputDecoration(
                          hintText: 'Kafileye bir şey yazın…',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final text = _chatMsgController.text.trim();
                        if (text.isNotEmpty) {
                          setState(() {
                            _groupChatMessages.add({
                              'sender': 'Ben',
                              'text': text,
                              'time': 'Şimdi',
                              'isHoca': 'false',
                            });
                            _chatMsgController.clear();
                          });
                          _saveGroupChat();
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivateChatTab(bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF2C2214) : const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RehberTheme.gold.withValues(alpha: 0.5)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_rounded, color: RehberTheme.goldDark, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu sohbetteki soruları ve cevapları yalnızca siz ve Mustafa Hoca görebilir. Özel fıkhî veya kişisel sorularınızı sorabilirsiniz.',
                  style: TextStyle(fontSize: 12, color: RehberTheme.goldDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final msg in _privateChatMessages) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Align(
                      alignment: msg['sender'] == 'Ben'
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: msg['sender'] == 'Ben'
                              ? RehberTheme.emerald
                              : (dark
                                    ? const Color(0xFF243632)
                                    : const Color(0xFFE8EFEA)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: msg['sender'] == 'Ben'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['sender']!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: msg['sender'] == 'Ben'
                                    ? Colors.white70
                                    : RehberTheme.emerald,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              msg['text']!,
                              style: TextStyle(
                                fontSize: 13,
                                color: msg['sender'] == 'Ben'
                                    ? Colors.white
                                    : (dark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _privateMsgController,
                        decoration: InputDecoration(
                          hintText: 'Hocaya özel sorunuzu yazın…',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        final text = _privateMsgController.text.trim();
                        if (text.isNotEmpty) {
                          setState(() {
                            _privateChatMessages.add({
                              'sender': 'Ben',
                              'text': text,
                              'time': 'Şimdi',
                            });
                            _privateMsgController.clear();
                          });
                          _savePrivateChat();
                          _replyFromHoca(text);
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    final terms = _terms;
    return Scaffold(
      appBar: AppBar(title: const Text('Kafilem')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!repository.configured)
              _buildClassroomSection(context)
            else if (repository.userId == null) ...[
              const FeatureStatusCard(
                icon: Icons.lock_outline,
                title: 'Kafilene bağlan',
                description: 'Yalnız kafile özellikleri için giriş gerekiyor. E-posta adresine gelen kodla devam et.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                enabled: !_busy && _emailSent == null,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              const SizedBox(height: 12),
              if (_emailSent == null)
                FilledButton(
                  onPressed: _busy ? null : _requestCode,
                  child: const Text('Giriş kodu gönder'),
                )
              else ...[
                Text(
                  'Kod gönderildi. Gelen kutunu ve spam klasörünü kontrol et.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'E-postadaki kod',
                  ),
                ),
                FilledButton(
                  onPressed: _busy
                      ? null
                      : () {
                          final code = _code.text.trim();
                          if (code.length < 6) {
                            setState(
                              () => _error = 'E-postadaki kodu eksiksiz yaz.',
                            );
                            return;
                          }
                          _action(
                            () => repository.verifyCode(_emailSent!, code),
                          );
                        },
                  child: const Text('Giriş yap'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _emailSent = null;
                          _code.clear();
                        }),
                  child: const Text('E-postayı değiştir'),
                ),
              ],
            ] else ...[
              const FeatureStatusCard(
                icon: Icons.groups,
                title: 'Birlikte, adım adım',
                description: 'Kafile programını takip et, rehberine ulaş ve mesajlarını buradan yönet. Mesajların gönderilmesi internet gerektirir.',
              ),
              const SizedBox(height: 24),
              if (terms == null)
                const Text(
                  'Güncel kullanım koşulları alınamadı. Bağlantını kontrol edip Kafileleri yenile. Kabul doğrulanmadan hizmet yazmaları kapalıdır.',
                )
              else ...[
                Text('Kullanım koşulları · ${_terms!.version}'),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Kullanım koşulları · ${terms.version}'),
                      content: SingleChildScrollView(
                        child: SelectableText(
                          '${terms.body}\n\n${terms.documentUrl}',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Kapat'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Koşulları oku'),
                ),
                if (_terms!.accepted)
                  const Text('Bu sürüm için kabulün sunucuda kayıtlı.')
                else
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _action(() async {
                            final version = _terms!.version;
                            await repository.acceptTerms(version);
                            await _load();
                          }),
                    child: const Text('Okudum, bu sürümü kabul ediyorum'),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _invite,
                enabled: !_busy && _terms?.accepted == true,
                decoration: const InputDecoration(
                  labelText: 'Kafile davet kodu',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy || _terms?.accepted != true
                    ? null
                    : () => _action(() async {
                        await repository.acceptInvitation(_invite.text.trim());
                        _invite.clear();
                        await _load();
                      }),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('Davetle katıl'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || _terms?.accepted != true ? null : _create,
                icon: const Icon(Icons.add),
                label: const Text('Kafile oluştur'),
              ),
              const SizedBox(height: 24),
              if (widget.push != null) ...[
                SwitchListTile.adaptive(
                  value: widget.push!.enabled,
                  onChanged:
                      _busy ||
                          _accountDeletionRequested == true ||
                          _terms?.accepted != true
                      ? null
                      : (enabled) => _action(() async {
                          if (enabled) {
                            await widget.push!.enable();
                          } else {
                            await widget.push!.disable();
                          }
                        }),
                  title: const Text('Kafile bildirimleri'),
                  subtitle: Text(
                    widget.push!.error ?? 'İzin verirsen bildirim kaydı açılır. Kilit ekranındaki içerik için sunucu şablonu ayrıca denetlenmelidir.',
                  ),
                ),
              ],
              if (_groups == null && _error == null)
                const Center(child: CircularProgressIndicator())
              else if (_groups?.isEmpty == true)
                const Text(
                  'Henüz bir kafileye katılmadın. Kafile sorumlundan davet kodu iste ve yukarıdaki Davetle katıl alanına yaz.',
                )
              else
                for (final group in _groups ?? <GroupRecord>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card.outlined(
                      child: ListTile(
                        title: Text(group.name),
                        leading: const Icon(Icons.groups_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => GroupDetailScreen(
                              group: group,
                              repository: repository,
                              store: widget.store,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              TextButton.icon(
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Kafileleri yenile'),
              ),
              TextButton(
                onPressed: _busy || _accountDeletionRequested == true
                    ? null
                    : _requestAccountDeletion,
                child: Text(
                  _accountDeletionRequested == true
                      ? 'Hesap silme isteği alındı'
                      : 'Hesap silme isteği gönder',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _action(() async {
                        final uid = repository.userId!;
                        await widget.push?.disable();
                        await repository.signOut();
                        await widget.store.clearAccountOutbox(uid);
                      }),
                child: const Text('Hesaptan çıkış yap'),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (repository.userId != null)
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    super.key,
    required this.group,
    required this.repository,
    required this.store,
  });
  final GroupRecord group;
  final GroupRepository repository;
  final ProgressStore store;
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with WidgetsBindingObserver {
  GroupSnapshot? _snapshot;
  List<GroupOutboxMessage> _outbox = [];
  final _body = TextEditingController();
  String? _recipient;
  String? _error;
  bool _sending = false;
  bool _managementBusy = false;
  bool _composerOpen = false;
  bool _connected = false;
  bool _refreshing = false;
  bool _reloadPending = false;
  bool _foreground = true;
  LocationShareCoordinator? _location;
  DateTime? _locationActiveUntil;
  bool _locationBusy = false;
  bool _locationRevocationPending = false;
  String? _locationError;
  List<RecentSharedLocation> _recentLocations = [];
  String? _recentLocationError;
  static const _maxHistoryPages = 8;
  List<Map<String, dynamic>> _historyRows = [];
  Set<String> _blockedUserIds = {};
  String? _unblockingUserId;
  int _historyPages = 0;
  int _historyEpoch = 0;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  String? _historyError;
  Future<void> Function()? _unsubscribe;
  Timer? _debounce;
  Timer? _membershipTimer;
  late final GroupOutboxSynchronizer _sync;
  late final String? _owner;
  @override
  void initState() {
    super.initState();
    _owner = widget.repository.userId;
    _sync = GroupOutboxSynchronizer(widget.store, widget.repository);
    final repository = widget.repository;
    if (repository is SupabaseGroupRepository) {
      _location = LocationShareCoordinator(
        store: widget.store,
        reader: const GeolocatorLocationReader(),
        remote: SupabaseLocationShareRemote(repository.client),
        currentUserId: () => widget.repository.userId,
      );
      unawaited(_refreshLocation());
    }
    widget.repository.addListener(_authChanged);
    WidgetsBinding.instance.addObserver(this);
    _unsubscribe = widget.repository.watch(widget.group.id, (connected) {
      if (!mounted || !_foreground || _owner != widget.repository.userId) {
        return;
      }
      setState(() => _connected = connected);
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _reload);
    });
    _membershipTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reload(),
    );
    _reload();
  }

  void _authChanged() {
    if (_owner != widget.repository.userId && mounted) {
      _location?.cancelPending();
      _historyEpoch++;
      _membershipTimer?.cancel();
      _debounce?.cancel();
      final unsubscribe = _unsubscribe;
      _unsubscribe = null;
      if (unsubscribe != null) unawaited(unsubscribe());
      _body.clear();
      setState(() {
        _snapshot = null;
        _outbox = [];
        _historyRows = [];
        _blockedUserIds = {};
        _unblockingUserId = null;
        _historyPages = 0;
        _loadingOlder = false;
        _hasOlder = false;
        _historyError = null;
        _connected = false;
        _recipient = null;
        _locationActiveUntil = null;
        _locationError = null;
        _recentLocations = [];
        _recentLocationError = null;
        _error = 'Oturum değişti. Kafile ekranından geri dön.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _membershipTimer?.cancel();
    _debounce?.cancel();
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshLocation());
      _reload();
      _membershipTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _reload(),
      );
    }
    if (!_foreground) _location?.cancelPending();
  }

  Future<void> _refreshLocation() async {
    final service = _location;
    if (service == null ||
        _owner == null ||
        _owner != widget.repository.userId) {
      return;
    }
    try {
      final until = await service.activeUntil(widget.group.id);
      if (mounted && _owner == widget.repository.userId) {
        setState(() {
          _locationActiveUntil = until;
          if (until == null) _locationRevocationPending = false;
        });
      }
    } catch (_) {
      if (mounted && _owner == widget.repository.userId) {
        setState(() => _locationError = 'Konum paylaşım durumu alınamadı.');
      }
    }
  }

  Future<void> _refreshRecentLocations() async {
    final service = _location;
    if (service == null || !_managementAllowed) {
      if (mounted) setState(() => _recentLocations = []);
      return;
    }
    try {
      final locations = await service.recentForGroup(widget.group.id);
      if (mounted && _managementAllowed) {
        setState(() {
          _recentLocations = locations;
          _recentLocationError = null;
        });
      }
    } catch (_) {
      if (mounted && _managementAllowed) {
        setState(() {
          _recentLocations = [];
          _recentLocationError =
              'Son konumlar alınamadı. Bağlantıyı kontrol edip yenile.';
        });
      }
    }
  }

  Future<void> _shareLocation() async {
    final service = _location;
    if (service == null ||
        _locationBusy ||
        _owner != widget.repository.userId) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konumunu paylaş?'),
        content: const Text(
          'Konumun yalnız bu kafilenin rehberi/yöneticisiyle paylaşılır. '
          'Bir kez ölçülür; 15 dakika görünür, sonra otomatik sona erer. '
          'Konum izni bu onaydan sonra istenir. İstediğin an durdurabilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Konumumu paylaş'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _owner != widget.repository.userId) {
      return;
    }
    setState(() {
      _locationBusy = true;
      _locationError = null;
    });
    try {
      await service.shareOnce(widget.group.id);
      if (mounted && _owner == widget.repository.userId) {
        await _refreshLocation();
      }
    } on LocationShareException catch (error) {
      if (mounted && _owner == widget.repository.userId) {
        setState(() => _locationError = error.message);
      }
    } catch (_) {
      if (mounted && _owner == widget.repository.userId) {
        setState(
          () => _locationError =
              'Konum gönderilemedi. Bağlantı ve kafile erişimini kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _stopLocation() async {
    final service = _location;
    if (service == null || _locationBusy) return;
    setState(() {
      _locationBusy = true;
      _locationError = null;
    });
    try {
      await service.stop(widget.group.id);
      if (mounted) {
        setState(() {
          _locationActiveUntil = null;
          _locationRevocationPending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locationRevocationPending = true;
          _locationError = 'Cihazda durdu, sunucuda iptal doğrulanamadı. Bağlanıp yeniden dene; kayıt en geç 15 dakikada biter.';
        });
      }
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  Future<void> _reload() async {
    if (!_foreground || _owner == null || _owner != widget.repository.userId) {
      return;
    }
    if (_refreshing) {
      _reloadPending = true;
      return;
    }
    _refreshing = true;
    final epoch = ++_historyEpoch;
    setState(() {
      _loadingOlder = false;
      _historyError = null;
      _recentLocations = [];
    });
    try {
      final blocked = await widget.repository.blockedUserIds();
      final pending = await widget.store.readGroupOutbox();
      if (mounted && _owner == widget.repository.userId) {
        setState(
          () => _outbox = pending
              .where(
                (m) =>
                    m.groupId == widget.group.id &&
                    m.ownerUserId == _owner &&
                    m.status != MessageOutboxStatus.sent,
              )
              .toList(),
        );
      }
      if (!mounted || _owner != widget.repository.userId) return;
      await _sync.sync(widget.group.id);
      if (!mounted || _owner != widget.repository.userId) return;
      // Read after delivery so confirmed messages remain visible even when
      // Realtime is disconnected or its notification has not arrived yet.
      final snapshot = await widget.repository.snapshot(widget.group.id);
      // Re-read previously loaded pages: edits/deletions and access changes
      // must not leave an indefinitely stale local message history.
      var history = <Map<String, dynamic>>[];
      var hasOlder = snapshot.messages.length == 100;
      var loadedPages = 0;
      for (var i = 0; i < _historyPages && hasOlder; i++) {
        if (!mounted || _owner != widget.repository.userId) return;
        final rows = _mergeMessages(history, snapshot.messages);
        final page = await widget.repository.olderMessages(
          widget.group.id,
          before: MessageCursor.fromRow(rows.first),
        );
        history = _mergeMessages(page.messages, history);
        hasOlder = page.hasMore;
        if (page.messages.isNotEmpty) loadedPages++;
      }
      final outbox = await widget.store.readGroupOutbox();
      if (mounted &&
          _owner == widget.repository.userId &&
          epoch == _historyEpoch) {
        setState(() {
          _snapshot = snapshot;
          _blockedUserIds = blocked;
          _historyRows = history;
          _historyPages = loadedPages;
          _hasOlder = hasOlder;
          if (_recipient != null &&
              !snapshot.members.any(
                (m) =>
                    m['user_id'] == _recipient &&
                    ['guide', 'group_admin'].contains(m['role']),
              )) {
            _recipient = null;
          }
          _error = null;
          _outbox = outbox
              .where(
                (m) =>
                    m.groupId == widget.group.id &&
                    m.ownerUserId == _owner &&
                    m.status != MessageOutboxStatus.sent,
              )
              .toList();
        });
        unawaited(_refreshRecentLocations());
      }
    } catch (_) {
      // Do not retain group data after revoked membership or failed revalidation.
      if (mounted && _owner == widget.repository.userId) {
        setState(() {
          _snapshot = null;
          _historyRows = [];
          _blockedUserIds = {};
          _historyPages = 0;
          _hasOlder = false;
          _connected = false;
          _recentLocations = [];
          _recentLocationError = null;
          _error = 'Kafileye erişilemedi. Bağlantı ve üyeliğini kontrol et.';
        });
      }
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
      if (_reloadPending && mounted) {
        _reloadPending = false;
        unawaited(_reload());
      }
    }
  }

  List<Map<String, dynamic>> _mergeMessages(
    List<Map<String, dynamic>> older,
    List<Map<String, dynamic>> newer,
  ) {
    final seen = <String>{};
    return [...older, ...newer].reversed
        .where((row) {
          final id = row['id'];
          return id is! String || seen.add(id);
        })
        .toList()
        .reversed
        .toList();
  }

  Future<void> _loadOlder() async {
    final snapshot = _snapshot;
    if (snapshot == null ||
        !_foreground ||
        _loadingOlder ||
        _refreshing ||
        !_hasOlder ||
        _historyPages >= _maxHistoryPages ||
        _owner != widget.repository.userId) {
      return;
    }
    final epoch = _historyEpoch;
    setState(() {
      _loadingOlder = true;
      _historyError = null;
    });
    try {
      final rows = _mergeMessages(_historyRows, snapshot.messages);
      final page = await widget.repository.olderMessages(
        widget.group.id,
        before: MessageCursor.fromRow(rows.first),
      );
      if (!mounted ||
          _owner != widget.repository.userId ||
          epoch != _historyEpoch) {
        return;
      }
      final history = _mergeMessages(page.messages, _historyRows);
      if (page.messages.isNotEmpty && history.length == _historyRows.length) {
        throw StateError('Mesaj geçmişi ilerlemedi.');
      }
      setState(() {
        _historyRows = history;
        _hasOlder = page.hasMore;
        if (page.messages.isNotEmpty) _historyPages++;
      });
    } catch (error) {
      if (!mounted ||
          _owner != widget.repository.userId ||
          epoch != _historyEpoch) {
        return;
      }
      setState(() {
        _connected = false;
        if (error is GroupAccessError) {
          _snapshot = null;
          _historyRows = [];
          _historyPages = 0;
          _hasOlder = false;
          _error = 'Kafileye erişilemedi. Bağlantı ve üyeliğini kontrol et.';
        } else {
          _historyError = 'Eski mesajlar alınamadı. Tekrar deneyebilirsin.';
        }
      });
    } finally {
      if (mounted && epoch == _historyEpoch) {
        setState(() => _loadingOlder = false);
      }
    }
  }

  @override
  void dispose() {
    _historyEpoch++;
    _location?.cancelPending();
    _membershipTimer?.cancel();
    _debounce?.cancel();
    widget.repository.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    final unsubscribe = _unsubscribe;
    if (unsubscribe != null) unawaited(unsubscribe());
    _body.dispose();
    super.dispose();
  }

  String _clientId() {
    final bytes = List.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  String _messageTime(Object? value) {
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return 'Tarih bilgisi yok';
    final local = parsed.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} · ${two(local.hour)}:${two(local.minute)}';
  }

  Future<bool> _send() async {
    final rawBody = _body.text;
    final body = rawBody.trim();
    if (_snapshot == null ||
        _sending ||
        body.isEmpty ||
        body.length > 4000 ||
        _owner != widget.repository.userId) {
      return false;
    }
    setState(() => _sending = true);
    try {
      await widget.store.enqueueGroupMessage(
        clientId: _clientId(),
        groupId: widget.group.id,
        ownerUserId: _owner,
        recipientId: _recipient,
        body: body,
      );
      if (!mounted || _owner != widget.repository.userId) return false;
      if (_body.text == rawBody) _body.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mesaj cihazda kaydedildi. Gönderim durumunu sohbetten takip edebilirsin.',
            ),
          ),
        );
      }
      await _reload();
      return true;
    } catch (_) {
      if (mounted && _owner == widget.repository.userId) {
        setState(() => _error = 'Mesaj kaydedilemedi. Tekrar dene.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _compose(List<Map<String, dynamic>> guides) async {
    if (_composerOpen ||
        _snapshot == null ||
        _owner != widget.repository.userId) {
      return;
    }
    setState(() => _composerOpen = true);
    try {
      final recipient = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => GroupMessageComposer(
          repository: widget.repository,
          controller: _body,
          guides: guides,
          recipient: _recipient,
          onSend: (recipient) async {
            if (_owner != widget.repository.userId || _snapshot == null) {
              return false;
            }
            if (recipient != null &&
                !_snapshot!.members.any(
                  (m) =>
                      m['user_id'] == recipient &&
                      ['guide', 'group_admin'].contains(m['role']),
                )) {
              return false;
            }
            _recipient = recipient;
            return _send();
          },
        ),
      );
      if (mounted && _owner == widget.repository.userId) _recipient = recipient;
    } finally {
      if (mounted) setState(() => _composerOpen = false);
    }
  }

  Future<void> _reportMessage(Map<String, dynamic> message) async {
    final owner = _owner;
    final messageId = message['id'];
    if (owner == null ||
        owner != widget.repository.userId ||
        messageId is! String) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mesajı şikâyet et'),
        children: [
          for (final entry in const {
            'harassment': 'Taciz veya tehdit',
            'spam': 'İstenmeyen içerik',
            'misinformation': 'Yanıltıcı bilgi',
            'other': 'Diğer',
          }.entries)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, entry.key),
              child: Text(entry.value),
            ),
        ],
      ),
    );
    if (reason == null || !mounted || owner != widget.repository.userId) return;
    try {
      await widget.repository.reportMessage(widget.group.id, messageId, reason);
      if (mounted && owner == widget.repository.userId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Şikâyet kaydedildi.')));
      }
    } catch (_) {
      if (mounted && owner == widget.repository.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Şikâyet kaydedilemedi. Tekrar dene.')),
        );
      }
    }
  }

  Future<void> _blockSender(Map<String, dynamic> message) async {
    final owner = _owner;
    final sender = message['sender_id'];
    if (owner == null ||
        owner != widget.repository.userId ||
        sender is! String ||
        sender == owner) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcı engellensin mi?'),
        content: const Text(
          'Bu kullanıcının mesajları sana gösterilmez ve aranızda özel mesaj gönderilemez. '
          'Kafiledeki diğer üyeler için genel sohbet açık kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || owner != widget.repository.userId) {
      return;
    }
    try {
      await widget.repository.blockUser(sender);
      if (!mounted || owner != widget.repository.userId) return;
      setState(() {
        _blockedUserIds = {..._blockedUserIds, sender};
        if (_recipient == sender) _recipient = null;
      });
      await _reload();
    } catch (_) {
      if (mounted && owner == widget.repository.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kullanıcı engellenemedi. Tekrar dene.'),
          ),
        );
      }
    }
  }

  Future<void> _unblockUser(String blockedId) async {
    final owner = _owner;
    if (owner == null ||
        owner != widget.repository.userId ||
        !_blockedUserIds.contains(blockedId) ||
        _unblockingUserId != null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Engel kaldırılsın mı?'),
        content: const Text(
          'Bu kullanıcının kafile mesajları yeniden görünür. '
          'Aranızda özel mesaj gönderimi de yeniden mümkün olur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Engeli kaldır'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || owner != widget.repository.userId) {
      return;
    }
    setState(() => _unblockingUserId = blockedId);
    try {
      await widget.repository.unblockUser(blockedId);
      if (!mounted || owner != widget.repository.userId) return;
      setState(() => _blockedUserIds = {..._blockedUserIds}..remove(blockedId));
      await _reload();
      if (mounted && owner == widget.repository.userId) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Engel kaldırıldı.')));
      }
    } catch (_) {
      if (mounted && owner == widget.repository.userId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Engel kaldırılamadı. Tekrar dene.')),
        );
      }
    } finally {
      if (mounted && owner == widget.repository.userId) {
        setState(() => _unblockingUserId = null);
      }
    }
  }

  bool get _canManage =>
      _snapshot?.members.any(
        (m) =>
            m['user_id'] == _owner &&
            ['guide', 'group_admin'].contains(m['role']),
      ) ==
      true;
  bool get _managementAllowed =>
      _owner != null && _owner == widget.repository.userId && _canManage;

  Future<void> _publish(String kind) async {
    if (_managementBusy || !_managementAllowed) return;
    setState(() => _managementBusy = true);
    final title = TextEditingController();
    final body = TextEditingController();
    try {
      final values = await showDialog<(String, String)>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(kind == 'program' ? 'Program ekle' : 'Duyuru ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Başlık'),
                ),
                TextField(
                  controller: body,
                  maxLength: 4000,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Açıklama'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty &&
                    body.text.trim().isNotEmpty) {
                  Navigator.pop(context, (title.text.trim(), body.text.trim()));
                }
              },
              child: const Text('Yayınla'),
            ),
          ],
        ),
      );
      if (values == null || !mounted || !_managementAllowed) return;
      await widget.repository.publish(
        widget.group.id,
        kind,
        values.$1,
        values.$2,
      );
      if (mounted && _managementAllowed) await _reload();
    } catch (_) {
      if (mounted && _managementAllowed) {
        setState(
          () => _error =
              'Yayınlanamadı. Kafile yetkini ve bağlantını kontrol et.',
        );
      }
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      title.dispose();
      body.dispose();
      if (mounted) setState(() => _managementBusy = false);
    }
  }

  Future<void> _invite() async {
    if (_managementBusy || !_managementAllowed) return;
    setState(() => _managementBusy = true);
    try {
      final token = await widget.repository.createInvitation(widget.group.id);
      if (!mounted || !_managementAllowed) return;
      await showDialog<void>(
        context: context,
        builder: (context) => ListenableBuilder(
          listenable: widget.repository,
          builder: (context, _) => AlertDialog(
            title: const Text('Tek kullanımlık davet'),
            content: _managementAllowed
                ? SelectableText('24 saat geçerli davet kodu:\n$token')
                : const Text('Oturum değişti. Davet kodu gizlendi.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
              TextButton(
                onPressed: !_managementAllowed
                    ? null
                    : () async {
                        try {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (context.mounted) Navigator.pop(context);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Davet kodu kopyalanamadı.'),
                              ),
                            );
                          }
                        }
                      },
                child: const Text('Kodu kopyala'),
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      if (mounted && _managementAllowed) {
        setState(
          () => _error =
              'Davet oluşturulamadı. Yetkini ve bağlantını kontrol et.',
        );
      }
    } finally {
      if (mounted) setState(() => _managementBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final visibleLocations = _canManage
        ? _recentLocations
              .where((location) => location.isVisibleAt(DateTime.now().toUtc()))
              .toList()
        : <RecentSharedLocation>[];
    final messages = _mergeMessages(
      _historyRows,
      snapshot?.messages ?? [],
    ).where((m) => !_blockedUserIds.contains(m['sender_id'])).toList();
    final guides =
        snapshot?.members
            .where(
              (m) =>
                  ['guide', 'group_admin'].contains(m['role']) &&
                  m['user_id'] != _owner &&
                  !_blockedUserIds.contains(m['user_id']),
            )
            .toList() ??
        [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      bottomNavigationBar: snapshot == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: _composerOpen || _sending
                      ? null
                      : () => _compose(guides),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Mesaj yaz'),
                ),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                _connected
                    ? 'Canlı bağlantı açık · internet gerekir'
                    : 'Canlı bağlantı kapalı · yenileyebilirsin',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('Kafileyi yenile'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_outbox.any(
              (m) => m.lastError?.contains('koşullarını') == true,
            ))
              TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => GroupScreen(
                      repository: widget.repository,
                      store: widget.store,
                    ),
                  ),
                ),
                child: const Text('Kafile koşullarını kontrol et'),
              ),
            if (snapshot == null && _error == null)
              const Center(child: CircularProgressIndicator())
            else if (snapshot != null) ...[
              if (_blockedUserIds.isNotEmpty) ...[
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engellenen kullanıcılar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text(
                          'Engeli kaldırınca bu kullanıcının mesajları yeniden görünür.',
                        ),
                        for (final id in (_blockedUserIds.toList()..sort()))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Kullanıcı ${id.length > 8 ? id.substring(0, 8) : id}',
                            ),
                            subtitle: Text(id),
                            trailing: TextButton(
                              onPressed: _unblockingUserId == null
                                  ? () => _unblockUser(id)
                                  : null,
                              child: const Text('Engeli kaldır'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_location != null) ...[
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Konum paylaşımı',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text(
                          'Yalnız seçersen tek konum gönderilir. Arka planda takip yapılmaz.',
                        ),
                        if (_locationActiveUntil != null)
                          Text(
                            'Tek seferlik konum kaydı ${_locationActiveUntil!.toLocal().hour.toString().padLeft(2, '0')}:${_locationActiveUntil!.toLocal().minute.toString().padLeft(2, '0')} saatine kadar geçerlidir.',
                          ),
                        if (_locationError != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _locationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (_locationActiveUntil != null ||
                            _locationRevocationPending)
                          OutlinedButton.icon(
                            onPressed: _locationBusy ? null : _stopLocation,
                            icon: const Icon(Icons.location_off_outlined),
                            label: Text(
                              _locationRevocationPending
                                  ? 'İptali yeniden dene'
                                  : 'Konum paylaşımını durdur',
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: _locationBusy ? null : _shareLocation,
                            icon: const Icon(Icons.my_location_outlined),
                            label: Text(
                              _locationBusy
                                  ? 'Konum alınıyor'
                                  : 'Konumumu bir kez paylaş',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_canManage && _location != null) ...[
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paylaşılan son konumlar',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Text(
                          'Yalnız son 5 dakikada ölçülen, hâlen izinli kayıtlar görünür. Bu canlı takip değildir.',
                        ),
                        if (_recentLocationError != null)
                          Text(
                            _recentLocationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        else if (visibleLocations.isEmpty)
                          const Text('Güncel paylaşım yok.')
                        else
                          for (final location in visibleLocations)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Üye ${location.userId.substring(0, 8)} · son bilinen konum',
                              ),
                              subtitle: Text(
                                '${location.update.latitude.toStringAsFixed(5)}, ${location.update.longitude.toStringAsFixed(5)} · ±${location.update.accuracyMeters.round()} m\n'
                                'Ölçüm: ${location.update.measuredAt.toLocal().hour.toString().padLeft(2, '0')}:${location.update.measuredAt.toLocal().minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_canManage)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _managementBusy ? null : _invite,
                      child: const Text('Davet oluştur'),
                    ),
                    OutlinedButton(
                      onPressed: _managementBusy
                          ? null
                          : () => _publish('announcement'),
                      child: const Text('Duyuru ekle'),
                    ),
                    OutlinedButton(
                      onPressed: _managementBusy
                          ? null
                          : () => _publish('program'),
                      child: const Text('Program ekle'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              Text(
                'Duyurular ve program',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (snapshot.announcements.isEmpty && snapshot.programs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Henüz duyuru veya program yok.'),
                ),
              for (final a in snapshot.announcements.where(
                (a) =>
                    a['expires_at'] == null ||
                    (DateTime.tryParse(a['expires_at'].toString())
                            ?.isAfter(DateTime.now()) ??
                        false),
              ))
                Card.outlined(
                  child: ListTile(
                    title: Text(a['title'].toString()),
                    subtitle: Text(a['body'].toString()),
                  ),
                ),
              for (final p in snapshot.programs)
                Card.outlined(
                  child: ListTile(
                    title: Text(p['title'].toString()),
                    subtitle: Text(
                      '${p['program_date']}\n${(p['document'] as Map?)?['notes'] ?? 'Program ayrıntıları kafile rehberinde.'}',
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text('Rotalar', style: Theme.of(context).textTheme.titleLarge),
              if (snapshot.routes.isEmpty)
                const Text('Kafile rotası henüz eklenmedi.'),
              for (final r in snapshot.routes)
                Card.outlined(
                  child: ListTile(
                    title: Text(r['title'].toString()),
                    subtitle: Text(
                      'Sürüm ${r['version']} · kafile rehberi tarafından paylaşıldı',
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Sohbet · ${messages.length} mesaj',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_hasOlder && _historyPages < _maxHistoryPages)
                OutlinedButton.icon(
                  onPressed: _loadingOlder || _refreshing ? null : _loadOlder,
                  icon: const Icon(Icons.history),
                  label: Text(
                    _loadingOlder
                        ? 'Eski mesajlar yükleniyor'
                        : 'Eski mesajları yükle',
                  ),
                )
              else if (_hasOlder)
                const Text('Bu ekranda en fazla 500 mesaj gösterilir.'),
              if (_historyError != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _historyError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Henüz sohbet mesajı yok.'),
                ),
              for (final m in messages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['sender_id'] == _owner ? 'Sen' : 'Kafile üyesi',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          if (m['recipient_id'] != null)
                            const Text('Rehberle özel mesaj'),
                          Text(
                            m['deleted_at'] == null
                                ? m['body'].toString()
                                : 'Mesaj silindi.',
                          ),
                          Text(
                            _messageTime(m['created_at']),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          if (m['sender_id'] != _owner &&
                              m['deleted_at'] == null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                tooltip: 'Mesaj işlemleri',
                                onSelected: (action) {
                                  if (action == 'report') {
                                    unawaited(_reportMessage(m));
                                  } else if (action == 'block') {
                                    unawaited(_blockSender(m));
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'report',
                                    child: Text('Şikâyet et'),
                                  ),
                                  PopupMenuItem(
                                    value: 'block',
                                    child: Text('Kullanıcıyı engelle'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text('${snapshot.members.length} aktif üye'),
            ],
            for (final m in _outbox)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.body),
                        Text(
                          m.status == MessageOutboxStatus.rejected
                              ? 'Gönderilmedi · bu mesaj tekrar gönderilmeyecek'
                              : m.status == MessageOutboxStatus.failed
                              ? 'Gönderilemedi · yeniden denemek için yenile'
                              : 'Gönderim bekliyor · henüz teslim edilmedi',
                        ),
                        if (m.lastError != null) Text(m.lastError!),
                        if (m.status == MessageOutboxStatus.rejected)
                          TextButton(
                            onPressed: () async {
                              final owner = _owner;
                              if (owner == null ||
                                  widget.repository.userId != owner) {
                                return;
                              }
                              try {
                                await widget.store.discardRejectedGroupMessage(
                                  clientId: m.clientId,
                                  ownerUserId: owner,
                                );
                                if (mounted &&
                                    widget.repository.userId == owner) {
                                  setState(
                                    () => _outbox.removeWhere(
                                      (row) => row.clientId == m.clientId,
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (mounted &&
                                    widget.repository.userId == owner) {
                                  setState(
                                    () => _error = 'Yerel mesaj kaldırılamadı. Yeniden dene.',
                                  );
                                }
                              }
                            },
                            child: const Text('Yerel mesajı kaldır'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
