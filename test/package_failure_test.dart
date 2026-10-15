import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hac_umre_sesli_rehber/offline_package.dart';
import 'package:hac_umre_sesli_rehber/package_catalog.dart';
import 'package:hac_umre_sesli_rehber/package_downloader.dart';
import 'package:hac_umre_sesli_rehber/package_failure.dart';

void main() {
  test('taşıma sarmalayıcıları ağ hatasının nedenini korur', () {
    final nested = PackageCatalogException(
      'catalog',
      cause: PackageDownloadException(
        'file',
        cause: const SocketException('private host'),
      ),
    );
    expect(packageFailureMessage(nested), contains('İnternet bağlantını'));
    expect(packageFailureMessage(nested), isNot(contains('private host')));
    expect(
      packageFailureMessage(TimeoutException('secret URL')),
      contains('zamanında'),
    );
  });
  test(
    'alan, bulunamayan sürüm ve bozuk paket farklı sonraki adım gösterir',
    () {
      expect(
        packageFailureMessage(
          const FileSystemException('disk', '/private', OSError('full', 28)),
        ),
        contains('yer aç'),
      );
      expect(
        packageFailureMessage(const PackageDownloadException('HTTP 404')),
        contains('mevcut sürümü seç'),
      );
      expect(
        packageFailureMessage(
          const PackageFormatException('Dosya özeti uyuşmuyor'),
        ),
        contains('kullanıma açılmadı'),
      );
    },
  );
}
