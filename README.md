# Hac ve Umre Sesli Rehber

Flutter ile geliştirilen Türkçe hac ve umre sesli rehber uygulaması. Ana sayfa, öğrenme/yolculuk biçimleri, 18 Umre ve 35 Hac başlığı, Hac profilleri, ayrıntı ekranları ve SQLite tabanlı kaldığın yerden devam akışı vardır. Teknik örnek kart Arapça yazı yönünü ve yerel sesi gösterir. Dinî açıklamalar ve Hac profil kuralları henüz onaylı yayın içeriği değildir.

## Çalıştırma

Flutter 3.47.6 ve Dart 3.13.5 ile doğrulandı:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Android debug APK derlemesi ve Android 35 emülatör akışı doğrulandı. Alt sınır Android 9'dur (API 28). iOS derlemesi için tam Xcode ve CocoaPods gerekir; gerçek Android/iPhone cihaz testi henüz yapılmadı.

## İçerik sınırı

`assets/content/umre_inventory.v1.json` ve `assets/content/hac_inventory.v1.json` sürümlü yerel kataloglardır. Sabit kimlikler `U01.1` ve `H01.1` biçimindedir. JSON doğrulayıcı kimlikleri, grup sayılarını, kaynak ve inceleme alanlarını, ses haklarını ve metin–ses sürüm eşleşmesini denetler. Taslaklar uygulamada açıkça işaretlenir.

`assets/audio/teknik_demo.m4a` sistem sesiyle üretilmiş teknik örnektir; nihai insan seslendirmesi değildir. Dinî metin, dua ve sesler yalnız kaynak, uzman incelemesi ve kullanım hakkı kaydıyla yayınlanabilir. Mimari için [ana yapı belgesine](docs/02-ana-yapi.md), içerik hattı ve mobil doğrulama için [son doğrulama belgesine](docs/03-icerik-ve-mobil-dogrulama.md) bakın.
