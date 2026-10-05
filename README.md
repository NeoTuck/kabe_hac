# Hac ve Umre Sesli Rehber

Flutter ile geliştirilen Türkçe sesli rehberin çalışan prototipi. Umrenin 18 başlık envanteri, ayrı öğrenme/yolculuk kayıtları, kişisel adım işaretleri ve manuel tavaf/sa‘y sayaçları vardır. Teknik örnek kart Arapça yazı yönünü ve yerel sesi gösterir. Dinî açıklamalar henüz onaylı içerik olarak eklenmedi.

## Çalıştırma

Flutter 3.47.6 ve Dart 3.13.5 ile oluşturuldu. Bu bilgisayardaki SDK:

```sh
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter --no-version-check pub get
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter --no-version-check analyze --no-pub
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter --no-version-check test --no-pub
```

Telefon çalıştırması için Android SDK veya Xcode kurulumu ve uygun cihaz gerekir. Mevcut aday alt sınırlar Android 9 (API 28) ve iOS 15'tir; gerçek cihaz desteği henüz doğrulanmadı.

## İçerik sınırı

`assets/content/umre_inventory.v1.json` yalnız plan başlıklarını içerir. `draft-` kimlikleri, eski 3D plandaki kimlikler doğrulanana kadar geçicidir. JSON doğrulayıcı 18 benzersiz sıralı kayıt ve grup sayılarını şart koşar; yayın durumu için özet, tam metin, kaynak, inceleyen, ses ve kullanım hakkı alanları gerekir. Taslaklar uygulamada açıkça işaretlenir.

`assets/audio/teknik_demo.m4a` sistem sesiyle üretilmiş teknik örnektir; nihai insan seslendirmesi değildir. Dinî metin, dua ve gerçek U/H içerik kimlikleri ancak kaynak ve uzman onayıyla eklenir. İnceleme ve aşama sırası için [ilk dilim notuna](docs/01-baslangic.md) bakın.
