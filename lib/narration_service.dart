import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'narration_backend.dart';
import 'offline_package.dart';

enum NarrationStatus { idle, loading, playing, paused, completed, error }

class NarrationState {
  const NarrationState(this.status, {this.asset, this.message});
  final NarrationStatus status;
  final String? asset;
  final String? message;
}

abstract class NarrationService extends ChangeNotifier {
  NarrationState get state;
  Duration get position => Duration.zero;
  Duration? get duration => null;
  Future<void> initialize();
  Future<void> playAsset(String asset, {String? title});
  Future<void> pause();
  Future<void> resume();
  Future<void> replay();
  Future<void> stop();
  Future<void> setSpeed(double speed);
  Future<void> seek(Duration value) async {}
}

class JustAudioNarrationService extends NarrationService {
  JustAudioNarrationService({this.packages, NarrationBackend? backend})
    : _backend = backend ?? DeviceNarrationBackend();
  final OfflinePackageManager? packages;
  final NarrationBackend _backend;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Future<void>? _initializing;
  Future<void> _operation = Future.value();
  bool _listening = false;
  bool _disposed = false;
  int _request = 0;
  double _speed = 1;
  Duration _position = Duration.zero;
  Duration? _duration;
  NarrationState _state = const NarrationState(NarrationStatus.idle);
  @override
  NarrationState get state => _state;
  @override
  Duration get position => _position;
  @override
  Duration? get duration => _duration;

  void _publish(NarrationState state) {
    if (_disposed) return;
    _state = state;
    notifyListeners();
  }

  @override
  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });
  Future<void> _initialize() async {
    await _backend.initialize();
    if (_disposed) {
      await _backend.dispose();
      return;
    }
    if (_listening) return;
    _listening = true;
    _subscriptions.add(
      _backend.interruptions.listen((_) {
        if (_state.status == NarrationStatus.playing) unawaited(_interrupt());
      }),
    );
    _subscriptions.add(
      _backend.completions.listen((_) {
        if (_state.status == NarrationStatus.playing) {
          _publish(
            NarrationState(NarrationStatus.completed, asset: _state.asset),
          );
        }
      }),
    );
    _subscriptions.add(
      _backend.positions.listen((value) {
        if (_disposed || _state.asset == null) return;
        _position = value;
        notifyListeners();
      }),
    );
    _subscriptions.add(
      _backend.durations.listen((value) {
        if (_disposed || _state.asset == null) return;
        _duration = value;
        notifyListeners();
      }),
    );
  }

  Future<void> _interrupt() async {
    final id = _request;
    try {
      await _backend.pause();
      if (id == _request && _state.status == NarrationStatus.playing) {
        _publish(
          NarrationState(
            NarrationStatus.paused,
            asset: _state.asset,
            message:
                'Ses kesinti nedeniyle duraklatıldı. Devam etmek için oynat.',
          ),
        );
      }
    } catch (_) {
      _error(id);
    }
  }

  void _error(int id) {
    if (id == _request) {
      _publish(
        NarrationState(
          NarrationStatus.error,
          asset: _state.asset,
          message: 'Ses açılamadı. Dosyayı ve ses çıkışını kontrol edip yeniden dene.',
        ),
      );
    }
  }

  @override
  Future<void> playAsset(String asset, {String? title}) {
    final id = ++_request;
    _position = Duration.zero;
    _duration = null;
    _publish(NarrationState(NarrationStatus.loading, asset: asset));
    final run = _operation.then((_) async {
      if (_disposed || id != _request) return;
      try {
        await initialize();
        if (_disposed || id != _request) return;
        await _backend.stop();
        final file = await resolvePackageAudio(asset, packages);
        if (_disposed || id != _request) return;
        await _backend
            .load(asset, file, title ?? 'Sesli rehber')
            .timeout(const Duration(seconds: 30));
        if (_disposed || id != _request) return;
        if (!await _backend.activate()) {
          throw StateError('Ses oturumu açılamadı.');
        }
        await _backend.setSpeed(_speed);
        if (_disposed || id != _request) return;
        _publish(NarrationState(NarrationStatus.playing, asset: asset));
        _start(id);
      } catch (_) {
        _error(id);
      }
    });
    _operation = run;
    return run;
  }

  void _start(int id) {
    unawaited(_backend.play().catchError((Object _) => _error(id)));
  }

  @override
  Future<void> pause() async {
    if (_state.status != NarrationStatus.playing) return;
    final id = _request;
    try {
      await _backend.pause();
      if (id == _request) {
        _publish(NarrationState(NarrationStatus.paused, asset: _state.asset));
      }
    } catch (_) {
      _error(id);
    }
  }

  @override
  Future<void> resume() async {
    if (!const [
      NarrationStatus.paused,
      NarrationStatus.completed,
    ].contains(_state.status)) {
      return;
    }
    final id = _request;
    try {
      if (!await _backend.activate()) {
        throw StateError('Ses oturumu açılamadı.');
      }
      if (_state.status == NarrationStatus.completed) {
        await _backend.seek(Duration.zero);
      }
      if (_disposed || id != _request) return;
      _publish(NarrationState(NarrationStatus.playing, asset: _state.asset));
      _start(id);
    } catch (_) {
      _error(id);
    }
  }

  @override
  Future<void> replay() async {
    if (_state.asset == null || _state.status == NarrationStatus.loading) {
      return;
    }
    final id = _request;
    try {
      await _backend.seek(Duration.zero);
      if (!await _backend.activate()) {
        throw StateError('Ses oturumu açılamadı.');
      }
      if (_disposed || id != _request) return;
      _publish(NarrationState(NarrationStatus.playing, asset: _state.asset));
      _start(id);
    } catch (_) {
      _error(id);
    }
  }

  @override
  Future<void> stop() {
    ++_request;
    _position = Duration.zero;
    _duration = null;
    _publish(const NarrationState(NarrationStatus.idle));
    final run = _operation
        .then((_) => _backend.stop())
        .catchError((Object _) {});
    _operation = run;
    return run;
  }

  @override
  Future<void> seek(Duration value) async {
    final total = _duration;
    if (total == null ||
        _state.asset == null ||
        _state.status == NarrationStatus.loading) {
      return;
    }
    final bounded = Duration(
      milliseconds: value.inMilliseconds.clamp(0, total.inMilliseconds),
    );
    final id = _request;
    try {
      await _backend.seek(bounded);
      if (!_disposed && id == _request) {
        _position = bounded;
        notifyListeners();
      }
    } catch (_) {
      _error(id);
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (speed < 0.75 || speed > 1.5 || !speed.isFinite) {
      throw ArgumentError.value(speed, 'speed');
    }
    if (_listening) await _backend.setSpeed(speed);
    _speed = speed;
  }

  @override
  void dispose() {
    _disposed = true;
    ++_request;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_backend.dispose());
    super.dispose();
  }
}

/// Package references cannot fall through to a bundled asset or a network URL.
Future<File?> resolvePackageAudio(
  String reference,
  OfflinePackageManager? manager,
) async {
  if (!reference.startsWith('package:')) return null;
  final split = reference.indexOf('/', 'package:'.length);
  if (manager == null || split < 0) {
    throw const PackageFormatException('Ses paketi kullanılamıyor.');
  }
  final relativePath = reference.substring(split + 1);
  if (!relativePath.startsWith('audio/')) {
    throw const PackageFormatException('Paket ses yolu geçersiz.');
  }
  final file = await manager.resolveActiveFile(
    reference.substring('package:'.length, split),
    relativePath,
    kind: OfflinePackageKind.audio,
  );
  if (file == null) {
    throw const PackageFormatException('Ses paketi bulunamadı.');
  }
  return file;
}
