import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/reader_settings.dart';

import 'test_fakes.dart';

void main() {
  test('yazı ve anlatım ayarı kaydedilip yeniden yüklenir', () async {
    final store = MemoryGuideStore();
    final narration = FakeNarration();
    final first = ReaderSettings(store, narration);
    await first.setTextMultiplier(1.5);
    await first.setNarrationSpeed(1.25);

    final second = ReaderSettings(store, narration);
    await second.load();
    expect(second.textMultiplier, 1.5);
    expect(second.narrationSpeed, 1.25);
    expect(narration.speed, 1.25);
    first.dispose();
    second.dispose();
    narration.dispose();
  });
}
