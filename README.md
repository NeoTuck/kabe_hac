# Hac ve Umre Sesli Rehber

Türkçe Flutter uygulaması. **Tek güncel geliştirme dalı `codex/mvp1-pilot`**, teslim noktası [taslak PR #1](https://github.com/NeoTuck/kabe_hac/pull/1). Eski `codex/full-version-20261009` dalı tarihsel olarak korunur; özgün Umre taslak özet değişikliği güncel dala taşınmıştır. `main` henüz birleştirilmedi.

## Uygulamada neler var?

- İlk açılışta doğrudan Umre öğrenme, ayrı yolculuk kaydı ve kaldığı başlığa dönüş; 18 Umre ve 35 Hac başlığı. Hac türü seçilir, fakat uzman onaysız profil uygulanabilirliği önizleme olarak kalır.
- Kaynak ve metin sürümü kayıtlı Türkçe **taslak** açıklamalar, manuel tavaf/sa‘y/cemarat sayaçları ve gerçek rehber ilerlemesinden ayrı eğitim provası.
- Rehber ve provaya bağlı 54 çevrimdışı **sentetik taslak** ses. Dosya özeti ve metin sürümü kontrol edilir. Arapça telbiye için kayıt yoktur. Dinî ve dil incelemesi ile sesin dağıtım hakkı beklenir.
- İsteğe bağlı Mekke/Medine çevrimdışı haritaları ve OSM kaynaklı yer paketi. Harita, yer listesi ve favoriler paket indirildiğinde açılır; indirme/iptal, doğrulama, bozulma, silme ve geri dönüş yolları vardır. Yer adları ve saha bilgileri insan incelemesi bekler; canlı yönlendirme verilmez.
- Ayarlar, kaynak/lisans, yerel veri yönetimi ve Kafile arayüzü. Gerçek hizmet kabulü ve bağlantıları sağlanmadıkça Kafile kapalıdır.

Ana sayfa kurulu harita ve yer paketlerinin doğrulama durumunu gösterir. Gezi sekmesi eksik paket için doğrudan indirme yoluna götürür. Dosya doğrulaması haritanın cihazda açılıp görsel olarak kabul edildiği anlamına gelmez.

## Yerelde çalıştırma

Flutter 3.47.6 / Dart 3.13.5 ile çalışılır. Flutter `PATH` içinde değilse bu Mac'te `/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter` kullanın.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Android alt sınırı API 28, iOS alt sınırı 15.0'dır. Kısa CI kaynak/QA, Flutter analiz/birim testi ve veritabanını çalıştırır. Uzun native/yayın işleri kullanıcının isteğiyle otomatik akışta değildir; önceki cihaz sonuçları son kodun veya fiziksel telefonun kabulü sayılmaz. `assets/audio/teknik_demo.m4a` yalnız ayrı teknik QA içindir ve kullanıcı APK'sına paketlenmez.

## Yayın durumu

Bu kod **teknik pilot** düzeyindedir. Gerçek dinî/dil uzmanı kararı, 54 sesin hak ve dinleme onayı, eksik Arapça telbiye kaydı, canlı test projesi ve veri sorumluluğu, fiziksel cihaz kabulü, üretim imzası ve mağaza beyanları gerekir. `LIVE_SERVICE_ACCEPTED` bu kanıtlar olmadan açılmaz. Güncel kod/kanıt: [birleşik çalışma kaydı](docs/43-birlesik-gunluk-kullanim-2026-10-13.md); gerçek karar teslimi: [release handoff](docs/release-handoff/2026-10-10/README.md).
