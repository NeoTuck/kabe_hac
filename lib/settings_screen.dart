import 'package:flutter/material.dart';

import 'reader_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.settings});

  final ReaderSettings settings;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yazı ve ses ayarları')),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Yazı boyutu', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [1.0, 1.25, 1.5, 2.0])
                  ChoiceChip(
                    label: Text('%${(value * 100).round()}'),
                    selected: settings.textMultiplier == value,
                    onSelected: (_) => settings.setTextMultiplier(value),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text(
              'Türkçe anlatım hızı',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [1.0, 1.25])
                  ChoiceChip(
                    label: Text('${value}x'),
                    selected: settings.narrationSpeed == value,
                    onSelected: (_) => settings.setNarrationSpeed(value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Onaylı anlatım kayıtları henüz eklenmedi.'),
          ],
        ),
      ),
    ),
  );
}
