import 'package:flutter/material.dart';

import 'narration_service.dart';
import 'progress_store.dart';

class ReaderSettings extends ChangeNotifier {
  ReaderSettings(this.store, this.narration);

  final ProgressStore store;
  final NarrationService narration;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;
  double _textMultiplier = 1;
  double _narrationSpeed = 1;
  Future<void> _pending = Future.value();

  Future<void> _save(Future<void> Function() action) {
    final operation = _pending.then((_) => action());
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  double get textMultiplier => _textMultiplier;
  double get narrationSpeed => _narrationSpeed;

  Future<void> load() async {
    final savedTheme = await store.readAppValue('theme_mode');
    _themeMode =
        ThemeMode.values.where((mode) => mode.name == savedTheme).firstOrNull ??
        ThemeMode.system;
    final savedText = double.tryParse(
      await store.readAppValue('text_scale') ?? '',
    );
    final savedSpeed = double.tryParse(
      await store.readAppValue('audio_speed') ?? '',
    );
    if (const [1.0, 1.25, 1.5, 2.0].contains(savedText)) {
      _textMultiplier = savedText!;
    }
    if (const [1.0, 1.25].contains(savedSpeed)) {
      _narrationSpeed = savedSpeed!;
    }
    await narration.setSpeed(_narrationSpeed);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) => _save(() async {
    await store.saveAppValue('theme_mode', value.name);
    _themeMode = value;
    notifyListeners();
  });

  Future<void> setTextMultiplier(double value) => _save(() async {
    if (!const [1.0, 1.25, 1.5, 2.0].contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    await store.saveAppValue('text_scale', value.toString());
    _textMultiplier = value;
    notifyListeners();
  });

  Future<void> setNarrationSpeed(double value) => _save(() async {
    if (!const [1.0, 1.25].contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    await narration.setSpeed(value);
    try {
      await store.saveAppValue('audio_speed', value.toString());
    } catch (_) {
      await narration.setSpeed(_narrationSpeed);
      rethrow;
    }
    _narrationSpeed = value;
    notifyListeners();
  });
}
