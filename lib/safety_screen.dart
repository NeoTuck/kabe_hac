import 'dart:async';

import 'package:flutter/material.dart';

import 'safety_catalog.dart';
import 'source_details.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key, required this.catalog, this.clock});

  final SafetyCatalog catalog;
  final DateTime Function()? clock;
  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen>
    with WidgetsBindingObserver {
  Timer? _expiry;
  DateTime get _now => (widget.clock?.call() ?? DateTime.now()).toUtc();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didUpdateWidget(SafetyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    _expiry?.cancel();
    final now = _now;
    final boundaries =
        widget.catalog.fieldInformation
            .expand((item) => [item.observedAt, item.validUntil])
            .where((time) => time.isAfter(now))
            .toList()
          ..sort();
    if (boundaries.isEmpty) return;
    _expiry = Timer(
      boundaries.first.difference(now) + const Duration(milliseconds: 1),
      () {
        if (mounted) {
          setState(() {});
          _schedule();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _expiry?.cancel();
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    final catalog = widget.catalog;
    final approvedContacts = catalog.contacts
        .where((c) => c.status == SafetyReviewStatus.approved)
        .toList();
    final approvedCards = catalog.languageCards
        .where((card) => card.isApproved)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Güvenli gezi ve dil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Card.filled(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Numaralar, Arapça yardım ifadeleri ve saha bilgileri yalnız kaynak ve insan incelemesiyle yayınlanır. Bağlantı yokken eski veri canlı durum olarak gösterilmez.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'İletişim rehberi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (approvedContacts.isEmpty)
              const Text('Doğrulanmış iletişim kaydı henüz sağlanmadı.')
            else
              for (final contact in approvedContacts)
                Card.outlined(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              contact.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text('${contact.region} · Onaylı kayıt'),
                            SelectableText(contact.phone!),
                            Text('Diller: ${contact.languages.join(', ')}'),
                          ],
                        ),
                      ),
                      SourceDetails(
                        title: contact.sourceTitle,
                        uri: contact.sourceUri,
                        verifiedAt: contact.verifiedAt,
                      ),
                    ],
                  ),
                ),
            if (catalog.contacts.length > approvedContacts.length)
              Text(
                '${catalog.contacts.length - approvedContacts.length} iletişim kaydı inceleme bekliyor.',
              ),
            const SizedBox(height: 24),
            Text(
              'Türkçe–Arapça kartlar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (approvedCards.isEmpty)
              const Text('İnsan incelemesinden geçmiş dil kartı henüz yok.')
            else
              for (final card in approvedCards)
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(card.turkish),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            card.arabic!,
                            style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 26,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (card.transliteration != null)
                          Text(card.transliteration!),
                        SourceDetails(
                          title: card.sourceTitle!,
                          uri: card.sourceUri!,
                          verifiedAt: card.reviewedAt!,
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Text('Saha bilgisi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (catalog.fieldInformation.isEmpty)
              const Text(
                'Kaynaklı ve geçerlilik süreli saha bilgisi henüz yok.',
              )
            else
              for (final item in catalog.fieldInformation)
                Card.outlined(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(item.value),
                            Text(item.displayStateAt(now)),
                            Text(
                              'Geçerlilik sonu: ${localDateTimeLabel(item.validUntil)}',
                            ),
                          ],
                        ),
                      ),
                      SourceDetails(
                        title: item.sourceTitle,
                        uri: item.sourceUri,
                        verifiedAt: item.observedAt,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
