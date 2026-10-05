import 'package:flutter/foundation.dart';

import 'narration_service.dart';
import 'progress_store.dart';

class ReaderSettings extends ChangeNotifier {
  ReaderSettings(this.store, this.narration);

  final ProgressStore store;
  final NarrationService narration;

  double _textMultiplier = 1;
  double _narrationSpeed = 1;

  double get textMultiplier => _textMultiplier;
  double get narrationSpeed => _narrationSpeed;

  Future<void> load() async {
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

  Future<void> setTextMultiplier(double value) async {
    if (!const [1.0, 1.25, 1.5, 2.0].contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    await store.saveAppValue('text_scale', value.toString());
    _textMultiplier = value;
    notifyListeners();
  }

  Future<void> setNarrationSpeed(double value) async {
    if (!const [1.0, 1.25].contains(value)) {
      throw ArgumentError.value(value, 'value');
    }
    await narration.setSpeed(value);
    await store.saveAppValue('audio_speed', value.toString());
    _narrationSpeed = value;
    notifyListeners();
  }
}
