# Hac ve Umre Sesli Rehber

Flutter ile geliştirilen Türkçe sesli rehberin ilk teknik prototipi. Şu anda tek örnek kart, Arapça sağdan sola gösterim, yerel örnek ses ve SQLite içinde son görüntülenen kart kaydı vardır. Kartta ibadet talimatı bulunmaz.

## Çalıştırma

Flutter 3.47.6 ve Dart 3.13.5 ile oluşturuldu. Bu bilgisayardaki SDK:

```sh
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter pub get
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter analyze
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter test
```

Telefon çalıştırması için Android SDK veya Xcode kurulumu ve uygun cihaz gerekir. Mevcut aday alt sınırlar Android 9 (API 28) ve iOS 15'tir; gerçek cihaz desteği henüz doğrulanmadı.

## İçerik sınırı

`assets/audio/teknik_demo.m4a` sistem sesiyle üretilmiş teknik örnektir; nihai insan seslendirmesi değildir. Dinî metin, dua ve gerçek U/H içerik kimlikleri ancak kaynak ve uzman onayıyla eklenir. İnceleme ve aşama sırası için [ilk dilim notuna](docs/01-baslangic.md) bakın.
