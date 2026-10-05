import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

enum NarrationStatus { idle, loading, playing, paused, completed, error }

class NarrationState {
  const NarrationState(this.status, {this.asset, this.message});

  final NarrationStatus status;
  final String? asset;
  final String? message;
}

abstract class NarrationService extends ChangeNotifier {
  NarrationState get state;
  Future<void> playAsset(String asset);
  Future<void> pause();
  Future<void> resume();
  Future<void> replay();
  Future<void> stop();
  Future<void> setSpeed(double speed);
}

class JustAudioNarrationService extends NarrationService {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _subscription;
  NarrationState _state = const NarrationState(NarrationStatus.idle);
  double _speed = 1;

  @override
  NarrationState get state => _state;

  void _publish(NarrationState state) {
    _state = state;
    notifyListeners();
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _player = player;
    _subscription = player.playerStateStream.listen((event) {
      if (event.processingState == ProcessingState.completed &&
          _state.asset != null) {
        _publish(
          NarrationState(NarrationStatus.completed, asset: _state.asset),
        );
      }
    });
    return player;
  }

  @override
  Future<void> playAsset(String asset) async {
    final player = _ensurePlayer();
    await player.stop();
    _publish(NarrationState(NarrationStatus.loading, asset: asset));
    try {
      await player.setAsset(asset);
      await player.setSpeed(_speed);
      _publish(NarrationState(NarrationStatus.playing, asset: asset));
      _startPlaying(player, asset);
    } catch (_) {
      _publish(
        NarrationState(
          NarrationStatus.error,
          asset: asset,
          message: 'Ses dosyası bulunamadı veya açılamadı.',
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    if (_state.status != NarrationStatus.playing) return;
    await _player?.pause();
    _publish(NarrationState(NarrationStatus.paused, asset: _state.asset));
  }

  @override
  Future<void> resume() async {
    final player = _player;
    if (player == null || _state.asset == null) return;
    if (_state.status == NarrationStatus.completed) {
      await player.seek(Duration.zero);
    }
    _publish(NarrationState(NarrationStatus.playing, asset: _state.asset));
    _startPlaying(player, _state.asset!);
  }

  @override
  Future<void> replay() async {
    final player = _player;
    if (player == null || _state.asset == null) return;
    await player.seek(Duration.zero);
    _publish(NarrationState(NarrationStatus.playing, asset: _state.asset));
    _startPlaying(player, _state.asset!);
  }

  void _startPlaying(AudioPlayer player, String asset) {
    unawaited(
      player.play().catchError((Object _) {
        _publish(
          NarrationState(
            NarrationStatus.error,
            asset: asset,
            message: 'Ses oynatılamadı.',
          ),
        );
      }),
    );
  }

  @override
  Future<void> stop() async {
    await _player?.stop();
    _publish(const NarrationState(NarrationStatus.idle));
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (speed < 0.75 || speed > 1.5) {
      throw ArgumentError.value(speed, 'speed');
    }
    _speed = speed;
    await _player?.setSpeed(speed);
  }

  @override
  void dispose() {
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    final player = _player;
    if (player != null) {
      unawaited(player.dispose());
    }
    super.dispose();
  }
}
