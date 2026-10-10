import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// The device boundary is injectable so loading, interruptions and races can be tested.
abstract class NarrationBackend {
  Future<void> initialize();
  Stream<void> get interruptions;
  Stream<void> get completions;
  Stream<Duration> get positions;
  Stream<Duration?> get durations;
  Stream<bool> get playbackChanges => const Stream<bool>.empty();
  Future<bool> activate();
  Future<void> load(String reference, File? file, String title);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class DeviceNarrationBackend extends NarrationBackend {
  // The plugin replaces the process-wide audio platform. Re-registering it
  // would wrap the previous background platform instead of the device plugin.
  static Future<void>? _backgroundInitialization;
  AudioPlayer? _player;
  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruption;
  StreamSubscription<void>? _noisy;
  final _interruptions = StreamController<void>.broadcast();
  AudioPlayer get _audio => _player ?? (throw StateError('Ses başlatılmadı.'));
  @override
  Future<void> initialize() async {
    if (_player != null) return;
    // Register media integration only when audio is actually requested.
    // Offline reading must not wait for platform audio services at launch.
    await (_backgroundInitialization ??= JustAudioBackground.init(
      androidNotificationChannelId:
          'com.mustafasenoglu.hac_umre_sesli_rehber.audio',
      androidNotificationChannelName: 'Sesli rehber oynatma',
    ));
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
    _session = session;
    _player = AudioPlayer();
    _interruption = session.interruptionEventStream.listen((event) {
      if (event.begin) _interruptions.add(null);
    });
    _noisy = session.becomingNoisyEventStream.listen(
      (_) => _interruptions.add(null),
    );
  }

  @override
  Stream<void> get interruptions => _interruptions.stream;
  @override
  Stream<void> get completions => _audio.playerStateStream
      .where((event) => event.processingState == ProcessingState.completed)
      .map((_) {});
  @override
  Stream<Duration> get positions => _audio.positionStream;
  @override
  Stream<Duration?> get durations => _audio.durationStream;
  @override
  Stream<bool> get playbackChanges => _audio.playingStream;
  @override
  Future<bool> activate() async => await _session?.setActive(true) ?? false;
  @override
  Future<void> load(String reference, File? file, String title) async {
    final tag = MediaItem(
      id: reference,
      album: 'Hac ve Umre Sesli Rehber',
      title: title,
    );
    if (file == null) {
      await _audio.setAsset(reference, tag: tag);
    } else {
      await _audio.setAudioSource(AudioSource.uri(file.uri, tag: tag));
    }
  }

  @override
  Future<void> play() => _audio.play();
  @override
  Future<void> pause() => _audio.pause();
  @override
  Future<void> stop() async {
    await _player?.stop();
    await _session?.setActive(false);
  }

  @override
  Future<void> seek(Duration position) => _audio.seek(position);
  @override
  Future<void> setSpeed(double speed) async {
    await _player?.setSpeed(speed);
  }

  @override
  Future<void> dispose() async {
    await _interruption?.cancel();
    await _noisy?.cancel();
    await _player?.dispose();
    await _session?.setActive(false);
    await _interruptions.close();
  }
}
