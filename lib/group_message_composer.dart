import 'package:flutter/material.dart';

import 'group_repository.dart';

/// An editor above the keyboard. Draft text belongs to the group screen.
class GroupMessageComposer extends StatefulWidget {
  const GroupMessageComposer({
    super.key,
    required this.repository,
    required this.controller,
    required this.guides,
    required this.onSend,
    this.recipient,
  });
  final GroupRepository repository;
  final TextEditingController controller;
  final List<Map<String, dynamic>> guides;
  final String? recipient;
  final Future<bool> Function(String? recipient) onSend;
  @override
  State<GroupMessageComposer> createState() => _GroupMessageComposerState();
}

class _GroupMessageComposerState extends State<GroupMessageComposer> {
  late final String? _owner;
  String? _recipient;
  bool _busy = false;
  bool _needsRecipientChoice = false;
  String? _error;
  bool get _sameAccount => _owner != null && _owner == widget.repository.userId;
  @override
  void initState() {
    super.initState();
    _owner = widget.repository.userId;
    _recipient = widget.recipient;
    if (_recipient != null &&
        !widget.guides.any((guide) => guide['user_id'] == _recipient)) {
      _recipient = null;
      _needsRecipientChoice = true;
      _error = 'Önceki rehber artık listede yok. Mesaj alıcısını yeniden seç.';
    }
    widget.repository.addListener(_authChanged);
  }

  void _authChanged() {
    if (mounted && !_sameAccount) {
      widget.controller.clear();
      setState(() => _error = 'Oturum değişti. Bu pencereyi kapat.');
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_authChanged);
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy ||
        _needsRecipientChoice ||
        !_sameAccount ||
        widget.controller.text.trim().isEmpty)
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.onSend(_recipient);
      if (!mounted || !_sameAccount) return;
      if (saved) {
        Navigator.of(context).pop(_recipient);
      } else {
        setState(
          () => _error =
              'Mesaj kaydedilemedi. Bağlantı ve kafile erişimini kontrol et.',
        );
      }
    } catch (_) {
      if (mounted && _sameAccount) {
        setState(() => _error = 'Mesaj kaydedilemedi. Tekrar deneyebilirsin.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: available * 0.9),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mesaj yaz',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _recipient,
                  isExpanded: true,
                  itemHeight: null,
                  decoration: const InputDecoration(labelText: 'Mesaj alıcısı'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Kafile sohbeti'),
                    ),
                    for (final guide in widget.guides)
                      DropdownMenuItem(
                        value: guide['user_id'] as String,
                        child: Text(
                          'Rehber · ${(guide['user_id'] as String).substring(0, 8)}',
                        ),
                      ),
                  ],
                  onChanged: _busy || !_sameAccount
                      ? null
                      : (value) => setState(() {
                          _recipient = value;
                          if (_needsRecipientChoice) _error = null;
                          _needsRecipientChoice = false;
                        }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: widget.controller,
                  enabled: !_busy && _sameAccount,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Mesajın'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy || _needsRecipientChoice || !_sameAccount
                      ? null
                      : _send,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_busy ? 'Kaydediliyor' : 'Mesajı gönder'),
                ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).pop(_recipient),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
