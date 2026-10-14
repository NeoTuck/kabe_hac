# Hac ve Umre Sesli Rehber

Türkçe Flutter uygulaması. **Tek güncel geliştirme dalı `codex/mvp1-pilot`**, teslim noktası [taslak PR #1](https://github.com/NeoTuck/kabe_hac/pull/1). Eski `codex/full-version-20261009` dalı tarihsel olarak korunur; özgün Umre taslak özet değişikliği güncel dala taşınmıştır. `main` henüz birleştirilmedi.

## Uygulamada neler var?

- Umre/Hac rehber altyapısı, ayrı kişisel yolculuk kayıtları ve isteğe bağlı prova. **Uygulama paketinde onaylı rehber içeriği veya anlatım sesi henüz yoktur.** Rehber ve prova, içerik sağlanana kadar boş durum gösterir. Eski kişisel kayıtlar silinmez.
- Kaynaklı 53 metin ve 54 sentetik ses yalnız depodaki inceleme dosyalarıdır; Flutter kullanıcı paketine alınmaz. Gelecek onaylı içerik, güvenilir çevrimdışı paketle kademeli açılabilir. Tamamlanmamış paket yolculuk hazırlığı sayılmaz.
- İsteğe bağlı Mekke/Medine çevrimdışı haritaları ve OSM kaynaklı yer paketi. Harita, yer listesi ve favoriler paket indirildiğinde açılır; indirme/iptal, doğrulama, bozulma, silme ve geri dönüş yolları vardır. Yer adları ve saha bilgileri insan incelemesi bekler; canlı yönlendirme verilmez.
- Ayarlar, kaynak/lisans, yerel veri yönetimi ve Kafile arayüzü. Gerçek hizmet kabulü ve bağlantıları sağlanmadıkça Kafile kapalıdır.

Ana sayfa kurulu harita ve yer paketlerinin doğrulama durumunu gösterir. Gezi sekmesi eksik paket için doğrudan indirme yoluna götürür. Dosya doğrulaması haritanın cihazda açılıp görsel olarak kabul edildiği anlamına gelmez.

Açık harita ve gezi ekranları paket yönetiminden dönüşte yer kayıtlarını yeniler.
Önceki taslak içerikli uygulama durumu [13 Ekim planında](docs/44-tam-paket-uygulama-plani-2026-10-13.md)
tarihsel olarak kayıtlıdır; güncel kullanıcı paketi için
[14 Ekim içerik sınırına](docs/44-demo-icerik-cikarma-2026-10-14.md) bakın.

## Yerelde çalıştırma

Flutter 3.47.6 / Dart 3.13.5 ile çalışılır. Flutter `PATH` içinde değilse bu Mac'te `/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter` kullanın.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

Android alt sınırı API 28, iOS alt sınırı 15.0'dır. Kısa CI kaynak/QA, Flutter analiz/birim testi ve veritabanını çalıştırır. Uzun native/yayın işleri kullanıcının isteğiyle otomatik akışta değildir; önceki cihaz sonuçları son kodun veya fiziksel telefonun kabulü sayılmaz. Teknik QA sesleri ve taslak katalog/ses dosyaları kullanıcı paketine alınmaz.

## Yayın durumu

Bu kod **teknik pilot** düzeyindedir. Gerçek dinî/dil uzmanı kararı, ses hakkı ve dinleme onayı, canlı test projesi ve veri sorumluluğu, fiziksel cihaz kabulü, üretim imzası ve mağaza beyanları gerekir. `LIVE_SERVICE_ACCEPTED` bu kanıtlar olmadan açılmaz. Güncel içerik sınırı: [demo içerik çıkarma kaydı](docs/44-demo-icerik-cikarma-2026-10-14.md); gerçek karar teslimi: [release handoff](docs/release-handoff/2026-10-10/README.md).
