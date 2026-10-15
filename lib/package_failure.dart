import 'dart:async';
import 'dart:io';

import 'offline_package.dart';
import 'package_catalog.dart';
import 'package_downloader.dart';

/// User-facing reasons only; never expose server URLs, file paths or credentials.
String packageFailureMessage(Object error) {
  if (error is PackageDownloadException && error.cause != null) {
    return packageFailureMessage(error.cause!);
  }
  if (error is PackageCatalogException && error.cause != null) {
    return packageFailureMessage(error.cause!);
  }
  final detail = switch (error) {
    PackageDownloadException() => error.message,
    PackageFormatException() => error.message,
    PackageCatalogException() => error.message,
    _ => '',
  };
  if (error is SocketException || detail.contains('SocketException')) {
    return 'Paket sunucusuna ulaşılamadı. İnternet bağlantını kontrol edip yeniden dene. Kurulu paketlerini çevrimdışı kullanabilirsin.';
  }
  if (error is TimeoutException || detail.contains('TimeoutException')) {
    return 'İndirme zamanında tamamlanmadı. Daha iyi bir bağlantıyla yeniden dene; uygun yarım dosyadan devam edilir.';
  }
  if (detail.contains('depolama') ||
      (error is FileSystemException && error.osError?.errorCode == 28)) {
    return 'Cihazda yeterli boş alan yok. Kullanmadığın paketleri sil veya yer açıp yeniden dene. Rehber ilerlemen korunur.';
  }
  if (detail.contains('HTTP 404') || detail.contains('HTTP 410')) {
    return 'Bu paket artık sunucuda bulunmuyor. Kataloğu yenileyip mevcut sürümü seç.';
  }
  if (detail.contains('HTTP 401') || detail.contains('HTTP 403')) {
    return 'Sunucu bu pakete erişim vermiyor. Kataloğu yenile; sürerse destek bölümünden yardım iste.';
  }
  if (detail.contains('HTTP 5') || detail.contains('HTTP 429')) {
    return 'Paket sunucusu şu an yanıt veremiyor. Bir süre sonra yeniden dene; kurulu sürümün korunur.';
  }
  if (detail.contains('migrasyon') || detail.contains('şema')) {
    return 'Bu paket mevcut kayıtlarla uyumlu değil. Uygulamayı güncelle; mevcut paketini ve ilerlemeni koru.';
  }
  if (error is PackageFormatException ||
      error is PackageCatalogException ||
      detail.contains('doğrulan') ||
      detail.contains('boyut') ||
      detail.contains('özeti') ||
      detail.contains('Güvensiz') ||
      detail.contains('İzin verilmeyen') ||
      detail.contains('yönlendirme')) {
    return 'Paketin bütünlüğü veya kaynağı doğrulanamadı; kullanıma açılmadı. Kataloğu yenileyip yeniden indir. Kurulu dosya bozuksa önce önceki sürüme dön veya bu paketi sil. Rehber ilerlemen korunur.';
  }
  if (error is FileSystemException) {
    return 'Paket dosyaları okunamadı veya yazılamadı. Cihazdaki boş alanı kontrol et; paketi yeniden kontrol et veya önceki sürüme dön.';
  }
  return 'İşlem tamamlanamadı. Yeniden dene; sorun sürerse destek bölümünden yardım iste. Mevcut ilerlemen korunur.';
}
