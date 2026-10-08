import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String localDateTimeLabel(DateTime value) {
  final date = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} · ${two(date.hour)}:${two(date.minute)}';
}

class SourceDetails extends StatelessWidget {
  const SourceDetails({
    super.key,
    required this.title,
    required this.uri,
    required this.verifiedAt,
  });
  final String title;
  final Uri uri;
  final DateTime verifiedAt;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: const Text('Kaynak ve güncellik'),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title),
      Text('Kayıt tarihi: ${localDateTimeLabel(verifiedAt)}'),
      const SizedBox(height: 8),
      SelectableText(uri.toString()),
      TextButton.icon(
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: uri.toString()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kaynak bağlantısı kopyalandı.')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bağlantı kopyalanamadı.')),
              );
            }
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Kaynak bağlantısını kopyala'),
      ),
    ],
  );
}
