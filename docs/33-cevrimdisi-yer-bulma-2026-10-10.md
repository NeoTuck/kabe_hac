# Çevrimdışı haritada yer bulma — 10 Ekim 2026

Başlangıç `46bc81e`, dal `codex/mvp1-pilot`. Kullanıcı mevcut tam ürün kapsamını koruyarak yerel geliştirme istedi. CI beklenmedi; workflow değiştirilmedi.

## Kullanıcıya dönük değişiklik

Harita yer seçicisi eczane, sağlık, yeme–içme, konaklama, ulaşım ve diğer mevcut kategorilerle süzülür. Türkçe karakterleri sade yazmak ve baştaki/sondaki boşluklar aramayı bozmaz; yerel isimlerde büyük/küçük harf farkı kaldırıldı. Gezi listesi ve harita aynı arama işlevini kullanır. Aramayı temizleme, tüm kategorilere dönme, sonuç sayısı ve anlamlı boş durum vardır.

Başlık, arama ve kategori alanı listeyle kaydırılır; klavye için alt boşluk ayrılır. Yer satırları yalnız gerektiğinde oluşturulur. Kayıt seçimi aynı POI nesnesini haritaya döndürür; kamera/ayrıntı, kaynak/ODbL, paket güveni, ilerleme ve favoriler değişmedi. Teknik test yerleri seçicide gizli kalır. Arama ağ veya GPS istemez; yalnız seçili şehir kayıtları kullanılır.

## Yerel doğrulama

Flutter 3.47.6 / Dart 3.13.5 ile:

- Harita seçici ve katalog hedefli testleri 7/7 başarılı: Türkçe/yerel ad, kategoriyle birlikte arama, sıfır sonuç, filtreyi kaldırma, seçilen POI dönüşü ve test verisi gizleme.
- 320×640 ekran, yüzde 200 yazı ve 280 piksel klavye alanında gerçek kaydırmayla son yer erişimi; taşma/Flutter istisnası yok.
- Tüm Flutter testleri 210/210 başarılı, `flutter analyze --no-pub` temiz, `dart format` 84 dosya/0 değişiklik, `git diff --check` temiz.
- Oturumda test araçları yeniden kuruldu; tam sürüm bağımlılıkları değişmedi. Sabit pub.dev arşivleri kilit hash'leriyle doğrulandı; `pubspec.lock` değişmedi. SDK başlangıcındaki metadata erişimi güvenlik incelemesince reddedildi; o komut sürdürülmedi. CI/analitik kapalı güvenli kurulumla testler tamamlandı. Mevcut sistem SQLite kütüphanesi yalnız oturumdaki yerel yükleme adıyla kullanıldı.

Bu tur native Android/iOS derlemesi, fiziksel cihaz veya yeni ses dinleme kabulü değildir. Önceki 54 sentetik taslak ses ve üç OSM paketi korunur; Arapça telbiye, uzman/ses hakları, canlı servis ve üretim imzası açık kalır. Yeni saha saati, güvenli rota veya insan onayı üretilmedi. Full ürün kapsamı korunmuştur; genel kullanıcı yayını hazır iddiası yapılmaz.
