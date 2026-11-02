# Erkek sesli APK hazırlığı — 2 Kasım 2026

Kullanıcı 54 erkek sesin APK içinde çalmasını istedi. Mevcut katalogdaki 53 adım ve bir Türkçe anlam kaydı taslak/inceleme durumundadır; kayıtlar son kullanıcıya onaylı dinî içerik olarak sunulamaz. Android üretim imza dosyası da bu çalışma ağacında yoktur. Bu nedenle hazırlanan yol, ayrı uygulama kimliğine sahip **ses inceleme APK'si** içindir; üretim APK'si değildir.

## Hazırlanan kod

- `KABE_AUDIO_REVIEW_BUILD=true` derleme tanımıyla başlangıç, depodaki iki taslak kataloğu paket varlığı olarak yükler. Normal derlemede bu kataloglar yüklenmez.
- İnceleme derlemesinin ana ekranı “SES İNCELEME SÜRÜMÜ” uyarısını gösterir. Adım ekranlarındaki taslak metin ve yapay zekâ ile üretilmiş erkek anlatımı açıklamaları korunur; sesler `approved` yapılmadı.
- `tools/build_audio_review_apk.py` projeyi geçici dizine kopyalar; yalnız bu kopyanın `pubspec.yaml` dosyasına iki katalog ve 54 erkek M4A dosyasını ekler. Geçici Android yapılandırmasında uygulama etiketi `Hac Umre Ses İncelemesi`, paket kimliği eki `.review` olur; mevcut uygulamanın üzerine kurulmaz. Teknik pilot derlemesi debug sertifikasıyla imzalanır.
- Derleme aracı oluşan APK'de iki katalogun baytlarını ve 54 sesin SHA-256 değerlerini denetler, eski kadın taslak seslerini reddeder. Normal üretim APK varlık denetimi değiştirilmedi.

## Şu ana kadar doğrulananlar

- `python3 tools/prepare_male_review_audio.py --check`: 54/54 ses, makbuz, metin sürümü ve katalog bağı geçti.
- Dart 3.13.5 `dart analyze`: tüm depoda sıfır sorun. Değişen Dart dosyaları biçimli; Python derleme sözdizimi geçti.
- APK denetleyicisi gerçek kaynak dosyalarından hazırlanmış ZIP fixture'ında 54 ses ve iki kataloğu kabul etti; sesler çıkarılınca reddetti.
- İlk derleme, Flutter'ın `integration_test` eklentisini release Java kaydına katması yüzünden durdu. Geçici kopyanın `pubspec.yaml` dosyasından yalnız bu test bağımlılığı çıkarıldı; ana projenin test bağımlılığı korunur.
- İkinci derleme başarılı: `build/review/Kabe_Hac_Ses_Inceleme.apk`, 112.662.476 bayt (~112,7 MB). SHA-256 `ce42a91c6707e52fc1d01f4a90305c5d9f0833e3f385430e46f323be52407925`.
- APK arşivinde iki katalog kaynak dosyalarıyla bayt düzeyinde aynı, 54 erkek M4A dosyasının SHA-256 değeri kataloglarla eşleşiyor; eski kadın taslak sesleri yok. Android `apksigner verify` v2 imzasını doğruladı. Sertifika `CN=Android Debug`; uygulama kimliği `com.mustafasenoglu.hac_umre_sesli_rehber.review`, etiketi `Hac Umre Ses İncelemesi`, min API 28 ve hedef API 36.
- Flutter 3.47.6 ile `flutter analyze --no-pub` sıfır sorun ve 257/257 Flutter testi geçti. Fiziksel Android cihazda oynatma ve son kullanıcı yayın kabulü yapılmadı.

Derleme erişimi açıldığında komut:

```sh
python3 tools/build_audio_review_apk.py \
  --flutter /Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter
```

Çıktı `build/review/Kabe_Hac_Ses_Inceleme.apk` olarak üretildi. Son kullanıcı yayını için metin uzman kararları, 54 kaydın insan dinleme/dağıtım kararı, Android cihazda gerçek oynatma ve üretim imzası hâlâ eksiktir; bunlar otomatik olarak varsayılmayacaktır.
