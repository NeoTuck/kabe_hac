import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/narration_backend.dart';
import 'package:hac_umre_sesli_rehber/narration_service.dart';

class ControlledAudio extends NarrationBackend {
  final interrupted = StreamController<void>.broadcast(sync: true);
  final completed = StreamController<void>.broadcast(sync: true);
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final durationEvents = StreamController<Duration?>.broadcast(sync: true);
  final loaded = <String>[];
  Completer<void>? gate;
  bool active = true;
  bool failLoad = false;
  bool failSpeed = false;
  bool failInitialize = false;
  Future<void>? nextPlay;
  int plays = 0, pauses = 0, stops = 0, initializations = 0;
  double speed = 1;
  Duration lastSeek = Duration.zero;
  @override
  Stream<void> get interruptions => interrupted.stream;
  @override
  Stream<void> get completions => completed.stream;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<Duration?> get durations => durationEvents.stream;
  @override
  Future<void> initialize() async {
    initializations++;
    if (failInitialize) throw StateError('no audio device');
  }

  @override
  Future<bool> activate() async => active;
  @override
  Future<void> load(String reference, File? file, String title) async {
    loaded.add(reference);
    await gate?.future;
    if (failLoad) throw StateError('decode failed');
    durationEvents.add(const Duration(seconds: 60));
  }

  @override
  Future<void> play() async {
    final pending = nextPlay;
    nextPlay = null;
    plays++;
    await pending;
  }

  @override
  Future<void> pause() async {
    pauses++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
  }

  @override
  Future<void> setSpeed(double value) async {
    if (failSpeed) throw StateError('speed unavailable');
    speed = value;
  }

  @override
  Future<void> dispose() async {
    await interrupted.close();
    await completed.close();
    await positionEvents.close();
    await durationEvents.close();
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late ControlledAudio backend;
  late JustAudioNarrationService service;
  setUp(() {
    backend = ControlledAudio();
    service = JustAudioNarrationService(backend: backend);
  });
  tearDown(() => service.dispose());

  test('speed stays lazy and is applied to first playback', () async {
    await service.setSpeed(1.25);
    expect(backend.initializations, 0);
    await service.playAsset('one');
    expect(backend.speed, 1.25);
    expect(service.state.status, NarrationStatus.playing);
    expect(() => service.setSpeed(double.nan), throwsArgumentError);
  });
  test(
    'a new request prevents the previous loading clip from playing',
    () async {
      backend.gate = Completer<void>();
      final first = service.playAsset('one');
      await tick();
      expect(backend.loaded, ['one']);
      final second = service.playAsset('two');
      backend.gate!.complete();
      await Future.wait([first, second]);
      expect(backend.loaded, ['one', 'two']);
      expect(backend.plays, 1);
      expect(service.state.asset, 'two');
    },
  );
  test('stop during loading cannot start playback later', () async {
    backend.gate = Completer<void>();
    final loading = service.playAsset('one');
    await tick();
    final stopped = service.stop();
    expect(service.state.status, NarrationStatus.idle);
    backend.gate!.complete();
    await Future.wait([loading, stopped]);
    expect(backend.plays, 0);
    expect(service.state.asset, isNull);
  });
  test(
    'a late failure from an old player cannot replace the current clip',
    () async {
      final oldPlay = Completer<void>();
      backend.nextPlay = oldPlay.future;
      await service.playAsset('one');
      await service.playAsset('two');
      oldPlay.completeError(StateError('old interrupted player'));
      await tick();
      expect(service.state.status, NarrationStatus.playing);
      expect(service.state.asset, 'two');
    },
  );
  test('device initialization failure can retry without relaunching', () async {
    backend.failInitialize = true;
    await service.playAsset('one');
    expect(service.state.status, NarrationStatus.error);
    backend.failInitialize = false;
    await service.playAsset('one');
    expect(service.state.status, NarrationStatus.playing);
    expect(backend.initializations, 2);
  });
  test('failure is recoverable with the same clip', () async {
    backend.failLoad = true;
    await service.playAsset('one');
    expect(service.state.status, NarrationStatus.error);
    backend.failLoad = false;
    await service.playAsset('one');
    expect(service.state.status, NarrationStatus.playing);
    expect(backend.plays, 1);
  });
  test('audio focus rejection does not play', () async {
    backend.active = false;
    await service.playAsset('one');
    expect(service.state.status, NarrationStatus.error);
    expect(backend.plays, 0);
  });
  test('phone or headphone interruption requires manual resume', () async {
    await service.playAsset('one');
    backend.interrupted.add(null);
    await tick();
    expect(service.state.status, NarrationStatus.paused);
    expect(backend.pauses, 1);
    expect(backend.plays, 1);
    await service.resume();
    expect(backend.plays, 2);
  });
  test('seeking clamps to the duration and negative position', () async {
    await service.playAsset('one');
    await service.seek(const Duration(seconds: 100));
    expect(backend.lastSeek, const Duration(seconds: 60));
    await service.seek(const Duration(seconds: -10));
    expect(backend.lastSeek, Duration.zero);
    backend.positionEvents.add(const Duration(seconds: 12));
    expect(service.position, const Duration(seconds: 12));
  });
  test('completion and replay preserve the clip and reset position', () async {
    await service.playAsset('one');
    backend.completed.add(null);
    expect(service.state.status, NarrationStatus.completed);
    await service.resume();
    expect(service.state.status, NarrationStatus.playing);
    expect(backend.lastSeek, Duration.zero);
    await service.replay();
    expect(backend.plays, 3);
  });
  test(
    'a rejected package reference never reaches the device player',
    () async {
      await service.playAsset('package:untrusted/audio/one.m4a');
      expect(service.state.status, NarrationStatus.error);
      expect(backend.loaded, isEmpty);
    },
  );
  test(
    'failed speed change does not change later playback preference',
    () async {
      await service.playAsset('one');
      backend.failSpeed = true;
      await expectLater(service.setSpeed(1.25), throwsStateError);
      backend.failSpeed = false;
      await service.playAsset('two');
      expect(backend.speed, 1);
    },
  );
}
