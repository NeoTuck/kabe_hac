import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/group_sync.dart';

void main() {
  test('konum paylaşımı başlamadan etkin sayılmaz', () {
    final start = DateTime.utc(2026, 10, 8);
    final share = LocalLocationShare(
      groupId: 'group',
      mode: LocationShareMode.trip,
      startedAt: start,
      endsAt: start.add(const Duration(minutes: 10)),
      enabled: true,
      stoppedAt: null,
    );
    expect(
      share.isActiveAt(start.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(share.isActiveAt(start), isTrue);
    expect(share.isActiveAt(share.endsAt), isFalse);
  });
}
