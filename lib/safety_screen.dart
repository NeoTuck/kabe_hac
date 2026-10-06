import 'package:flutter/material.dart';

import 'safety_catalog.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, required this.catalog});

  final SafetyCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
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
            if (catalog.contacts.isEmpty)
              const Text('Doğrulanmış iletişim kaydı henüz sağlanmadı.')
            else
              for (final contact in catalog.contacts)
                Card.outlined(
                  child: ListTile(
                    title: Text(contact.name),
                    subtitle: Text(
                      '${contact.region} · ${contact.status.name}\n'
                      '${contact.phone ?? 'Numara doğrulama bekliyor'}',
                    ),
                    isThreeLine: true,
                  ),
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
                            style: const TextStyle(fontSize: 26, height: 1.5),
                          ),
                        ),
                        if (card.transliteration != null)
                          Text(card.transliteration!),
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
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.value}\n${item.displayStateAt(now)} · ${item.sourceKind.name}',
                    ),
                    isThreeLine: true,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
