import 'package:flutter/material.dart';

import 'narration_service.dart';

class AudioControls extends StatelessWidget {
  const AudioControls({
    super.key,
    required this.narration,
    required this.asset,
    required this.title,
  });

  final NarrationService narration;
  final String asset;
  final String title;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: narration,
    builder: (context, _) {
      final state = narration.state;
      final thisRecording = state.asset == asset;
      final playing = thisRecording && state.status == NarrationStatus.playing;
      final loading = thisRecording && state.status == NarrationStatus.loading;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: loading
                ? null
                : () async {
                    if (playing) {
                      await narration.pause();
                    } else if (thisRecording &&
                        (state.status == NarrationStatus.paused ||
                            state.status == NarrationStatus.completed)) {
                      await narration.resume();
                    } else {
                      await narration.playAsset(asset, title: title);
                    }
                  },
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            label: Text(
              loading
                  ? 'Ses yükleniyor'
                  : playing
                  ? 'Duraklat'
                  : 'Anlatımı dinle',
            ),
          ),
          if (thisRecording && state.status != NarrationStatus.loading) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.status == NarrationStatus.error
                  ? () => narration.playAsset(asset, title: title)
                  : () => narration.replay(),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Tekrar dinle'),
            ),
          ],
          if (thisRecording && state.status == NarrationStatus.error) ...[
            const SizedBox(height: 8),
            Text(
              state.message ?? 'Ses açılamadı.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      );
    },
  );
}
