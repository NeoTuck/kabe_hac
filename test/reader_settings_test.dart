import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';

import 'test_fakes.dart';

class DelayedSettingsStore extends MemoryGuideStore {
  final gate = Completer<void>();
  int calls = 0;
  bool fail = false;
  @override
  Future<void> saveAppValue(String key, String value) async {
    calls++;
    if (calls == 1) await gate.future;
    if (fail) throw StateError('disk');
    await super.saveAppValue(key, value);
  }
}

void main() {
  test('yazı ve anlatım ayarı kaydedilip yeniden yüklenir', () async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final first = ReaderSettings(store, narration);
    await first.setThemeMode(ThemeMode.dark);
    await first.setTextMultiplier(1.5);
    await first.setNarrationSpeed(1.25);

    final second = ReaderSettings(store, narration);
    await second.load();
    expect(second.themeMode, ThemeMode.dark);
    expect(second.textMultiplier, 1.5);
    expect(second.narrationSpeed, 1.25);
    expect(narration.speed, 1.25);
    first.dispose();
    second.dispose();
    narration.dispose();
  });
  test(
    'rapid changes persist in tap order and failure does not poison queue',
    () async {
      final store = DelayedSettingsStore();
      final audio = FakeNarration();
      final settings = ReaderSettings(store, audio);
      final first = settings.setTextMultiplier(1.25);
      final second = settings.setTextMultiplier(2);
      await Future<void>.delayed(Duration.zero);
      expect(store.calls, 1);
      store.gate.complete();
      await Future.wait([first, second]);
      expect(settings.textMultiplier, 2);
      expect(store.appValues['text_scale'], '2.0');
      store.fail = true;
      await expectLater(
        settings.setThemeMode(ThemeMode.dark),
        throwsStateError,
      );
      store.fail = false;
      await settings.setThemeMode(ThemeMode.light);
      expect(settings.themeMode, ThemeMode.light);
      settings.dispose();
      audio.dispose();
    },
  );
  test('failed audio preference save restores the playing speed', () async {
    final store = DelayedSettingsStore()..fail = true;
    store.gate.complete();
    final audio = FakeNarration();
    final settings = ReaderSettings(store, audio);
    await expectLater(settings.setNarrationSpeed(1.25), throwsStateError);
    expect(audio.speed, 1);
    expect(settings.narrationSpeed, 1);
    settings.dispose();
    audio.dispose();
  });
}
