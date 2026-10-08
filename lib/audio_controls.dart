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
  String _time(Duration value) =>
      '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: narration,
    builder: (context, _) {
      final state = narration.state;
      final selected = state.asset == asset;
      final playing = selected && state.status == NarrationStatus.playing;
      final loading = selected && state.status == NarrationStatus.loading;
      final total = selected ? narration.duration : null;
      final position = selected ? narration.position : Duration.zero;
      return Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        if (playing) {
                          await narration.pause();
                        } else if (selected &&
                            const [
                              NarrationStatus.paused,
                              NarrationStatus.completed,
                            ].contains(state.status)) {
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
              if (total != null && total > Duration.zero) ...[
                const SizedBox(height: 12),
                Semantics(
                  label: 'Ses konumu',
                  child: Slider(
                    value: position.inMilliseconds
                        .clamp(0, total.inMilliseconds)
                        .toDouble(),
                    max: total.inMilliseconds.toDouble(),
                    label: _time(position),
                    onChanged: (value) =>
                        narration.seek(Duration(milliseconds: value.round())),
                  ),
                ),
                Text('${_time(position)} / ${_time(total)}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => narration.seek(
                        position - const Duration(seconds: 10),
                      ),
                      icon: const Icon(Icons.replay_10),
                      label: const Text('10 sn geri'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => narration.seek(
                        position + const Duration(seconds: 10),
                      ),
                      icon: const Icon(Icons.forward_10),
                      label: const Text('10 sn ileri'),
                    ),
                  ],
                ),
              ],
              if (selected) ...[
                const SizedBox(height: 8),
                if (state.status == NarrationStatus.paused ||
                    state.status == NarrationStatus.completed) ...[
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(
                      state.status == NarrationStatus.paused
                          ? 'Ses duraklatıldı'
                          : 'Ses tamamlandı',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!loading)
                  OutlinedButton.icon(
                    onPressed: state.status == NarrationStatus.error
                        ? () => narration.playAsset(asset, title: title)
                        : () => narration.replay(),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Tekrar dinle'),
                  ),
                TextButton.icon(
                  onPressed: narration.stop,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Sesi durdur'),
                ),
                if (state.message != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      state.message!,
                      style: TextStyle(
                        color: state.status == NarrationStatus.error
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
