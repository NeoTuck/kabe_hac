# Kullanıcı geri bildirimi — 2 Kasım 2026

Arkadaşın değerlendirmesi: rehber ve sesler boş, yardım numaraları yararlı, harita fazla öne çıkıyor ve genel harita girişi Mekke'yi açıyor. Eklenen ekran görüntüsü uygulama değil, Mac'teki depo klasörü. Bu tur kod ve widget testleri üzerinden ilerledi.

## Yapılanlar

- Boş rehber mesajı metin ve seslerin incelemede olduğunu açık söylüyor. Boşken işlevsiz “Rehber seç” başlığı görünmüyor.
- Ana ekranda kaynak ve kontrol tarihi taşıyan yardım numaralarına ve yer/favori listesine doğrudan giriş var. Eski, yinelenen harita/gezi ve destek bağlantıları kaldırıldı. Yer girişi harita yerine Yolculuk listesini açıyor.
- Genel çevrimdışı harita girişinde iki şehir kuruluysa şehir seçimi bekleniyor; ilk paketin Mekke olması kullanıcı adına seçim sayılmıyor. Bir şehir kuruluysa veya paket yönetiminden belirli şehir açılmışsa mevcut doğrudan açma davranışı sürüyor.
- Erkek ses kayıtları inceleme adayı olarak depoda kalır. Bu değişiklik sesleri APK'ye eklemez, taslak rehber metnini görünür yapmaz veya `approved` durumuna çevirmez.

## Doğrulama ve açık sınır

Flutter 3.47.6 ile `flutter analyze --no-pub` sıfır sorun ve son tam koşuda 257/257 Flutter testi geçti. Değişen dört Dart dosyasında biçim kontrolü temiz. Native cihaz veya yeni APK kabulü yapılmadı.

İlk onaylı Umre metin/ses paketi için gerçek uzman, insan dinleme ve dağıtım hak kararları hâlâ gerekli. Görsel tasarımın cihazdaki birebir görünümü için uygulama ekran görüntüsü veya cihaz kabulü ayrı bir turdur.
