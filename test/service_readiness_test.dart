import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/service_readiness.dart';

void main() {
  const valid = 'https://example.org/help';

  test('live service remains closed without approval or every public link', () {
    expect(ServiceReadiness.liveServiceAccepted, isFalse);
    expect(
      ServiceReadiness.ready(
        accepted: false,
        privacyUrl: valid,
        supportUrl: valid,
        accountDeletionUrl: valid,
      ),
      isFalse,
    );
    expect(
      ServiceReadiness.ready(
        accepted: true,
        privacyUrl: valid,
        supportUrl: valid,
        accountDeletionUrl: '',
      ),
      isFalse,
    );
    expect(
      ServiceReadiness.ready(
        accepted: true,
        privacyUrl: valid,
        supportUrl: valid,
        accountDeletionUrl: valid,
      ),
      isTrue,
    );
  });

  test('links must be public HTTPS URLs without embedded credentials', () {
    for (final value in [
      'http://example.org',
      'https://user@example.org',
      'not a URL',
    ]) {
      expect(ServiceReadiness.httpsUrl(value), isNull);
    }
    expect(ServiceReadiness.httpsUrl(valid), isNotNull);
  });
}
