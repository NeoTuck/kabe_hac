# MVP 1: teknik pilot ve teslim durumu

Bu çalışma 3D içermeyen Türkçe mobil rehberin arayüzünü, ses kontrolünü ve kafile bağlantı katmanını geliştirir. Kod inceleme ve teknik pilot içindir. **Tam Umre/Hac içerikli, mağazada yayımlanabilir sürüm değildir.** Uzman onaylı içerik, insan sesleri ve gerçek servis/cihaz kabulü olmadan uygulamayı dinî rehber olarak son kullanıcılara sunmayın.

## Uygulanan değişiklikler

- Ortak Material 3 tasarım: zümrüt/krem açık tema, koyu tema, yuvarlatılmış kartlar, 48–56 dp asgari butonlar ve belirgin durum/yeniden deneme mesajları.
- Rehber, Yolculuk, Kafile ve Ayarlar erişimi; hesap açmadan çalışan yerel rehber. Son adım, manuel işaretler ve sayaçlar korunur. Yeni yolculuk öncesi onay alınır; önceki yolculuk silinmez.
- Türkçe için Noto Sans, Arapça için Noto Naskh Arabic uygulamayla birlikte paketlenir. Arapça dua/örnek/dil kartları RTL ve Arapça font kullanır. Sistem/açık/koyu tema ile yazı ve anlatım hızları SQLite'da saklanır. OFL lisansları Ayarlar → Uygulama ve lisanslar ekranındadır.
- Ses başlatma ilk dinleme anına ertelenir. Yükleniyor, oynuyor, duraklatıldı, tamamlandı, hata ve yeniden deneme durumları; süre/konum, ileri/geri 10 saniye, sarma, tekrar ve yükleme sırasında iptal vardır. Kesinti veya kulaklık çıkışında duraklatma, kullanıcı isteğiyle devam etme korunur. Hızlı kart değişiminde eski yüklemenin sonradan çalması engellenir. Ses hiçbir adımı tamamlamaz.
- Güven/hash/boyut/yol kontrollerinden geçen paket katalog ve yerel sesleri çalışır; bozuk paket gömülü rehberi veya ilerlemeyi bozmaz. Sunucu ve güven kökü yokken indirme ağı açılmaz.
- `supabase_flutter` 2.18.0 ile e-posta kodu oturumu, kafile listesi, kişisel kafile oluşturma, süreli/tek kullanımlık davet, üyeler, son 100 mesaj, rehbere özel mesaj, duyuru, program ve rota kayıtlarının listesi eklendi. Private Realtime ile yenileme ve uygulama aktifken 30 saniyelik erişim kontrolü vardır. Realtime push değildir.
- Outbox şeması 8: mesaj kullanıcı hesabına bağlıdır. Eski hesabı belirsiz kayıtlar taşınır ama otomatik gönderilmez. Çıkışta o hesabın yerel bekleyen mesajları temizlenir. Aynı `client_id` ile tekrar deneme INSERT/ignore-duplicates kullanır; başarılı cevapta içerik karşılaştırılır. Bağlantı/erişim kontrolü başarısızsa uzak grup verisi ekranı temizlenir. Bekleyen mesaj teslim edilmiş gösterilmez.
- `create_personal_group` RPC grubu ve ilk yönetici üyeliğini atomik oluşturur. Anonim çalıştırma kapalıdır. Android ana manifestine release için de gerekli INTERNET izni eklendi.
- GitHub Actions: analiz/format/test/ses dosyası kontrolü, Android debug APK, macOS iOS debug/no-codesign ve PostgreSQL motorunda SQL kontrolleri. Workflow bu ortamda/GitHub'da henüz çalıştırılmadı.

## Doğrulama kanıtı ve sınırları

| Kontrol | Sonuç | Ne kanıtlamaz? |
| --- | --- | --- |
| Flutter analyze | Temiz | Native derleme veya cihaz davranışı |
| Dart format | Temiz | Görsel kullanılabilirlik |
| Flutter unit/widget test | **87 test geçti** | Gerçek telefon, canlı Auth/Realtime |
| Ses durum makinesi | Yükleme yarışı, iptal, kesinti, ses oturumu reddi, tekrar, sarma sınırı, paket reddi test edildi | Telefon/Bluetooth/çağrı ve hoparlör kalitesi |
| Supabase HTTP adaptörü | SDK istekleri mock HTTP ile test edildi; üyelik, tekrar gönderim, RPC, program, davet doğrulandı | Canlı Supabase, SMTP, RLS servis entegrasyonu |
| SQL pgTAP | 35 kontrol geçti, PGlite 0.5.8 + pgTAP 1.3.2 | Supabase Auth/Realtime servisleri veya tam `supabase test db` |
| UI | 320×568 ve 390×844, %100/%200 yazı; navigasyon, boş durum, tema; dokunma hedefi, erişilebilir etiket ve ana ekran kontrastı kontrol edildi | Bütün ekranlar için TalkBack/VoiceOver veya fiziksel kullanıcı testi |
| Ses dosyası | AAC, 6.600 s, 146432 PCM örneği; RMS -17.5 dBFS, tepe -3.2 dBFS; tam çözümleme başarılı | İnsan kaydı/onayı, dua telaffuzu veya dinleme kalitesi |
| Android debug build | Denendi; bu Linux ortamında Android SDK yok, derlenemedi | Önceki emülatör kanıtı yeni SDK değişikliklerinin kanıtı değildir |
| iOS build | Linux ortamında Xcode yok; çalıştırılamadı | İmzalama, TestFlight ve gerçek iPhone kabulü |

`docs/mvp-ui/` içindeki PNG'ler gerçek Flutter widget render'larıdır; HTML tasarım maketi değildir. Gösterilen ses ekranı teknik örnek ve sahte test oynatıcısı kullanır; gerçek cihazda çalındığını iddia etmez.

## Üretim/pilot kabulünde hâlâ açık olanlar

1. 18 Umre ve 35 Hac adımının gerçek metin/dua/içerikleri, kaynak ve uzman onayı; üç Hac türünün uygulanabilirlik matrisi. Şu an kataloglar envanter/taslak; onay filtresi korunur.
2. Metin/sürüm eşleşmesi ve dağıtım hakkı bulunan insan sesleri; güvenilen manifest/indirilebilir üretim paketleri.
3. Gerçek Supabase URL/publishable key, migration kurulumu, OTP e-posta şablonu, iki gerçek hesapla üyelik/davet/özel mesaj/üyelik iptali/Realtime testi. Program/duyuru yayınlama gerçek serviste henüz kabul edilmedi. Son 100 mesajın ötesinde geçmiş sayfalama ve uzun kesinti senkronizasyonu geniş sürüm işidir.
4. Lisanslı offline harita sağlayıcısı, gerçek POI ve rota verisi. Mevcut gezi ekranı liste/arama/favori ve harita indirme adaptörü temelidir; etkileşimli harita ekranı ve şirket rotası oluşturma/indirme akışı henüz tamamlanmadı.
5. Doğrulanmış iletişim/dil/saha verileri. GPS izinleri ve canlı konum gönderimi, APNs/FCM bildirimleri, şirket yönetim paneli, rota paylaşım/moderasyon akışı bu pilotta tamamlanmış özellik değildir.
6. Yeni bağımlılıklarla Android/iOS derlemeleri, gerçek cihazda kilit ekranı/çağrı/kulaklık/Bluetooth ve düşük bellek testleri. Mağaza imzası, gizlilik beyanı ve dağıtım kabulü bekler. Mevcut Android release yapılandırması debug imzası kullanır; mağazaya uygun değildir.

## Yapılandırma

Rehber için hesap veya servis bilgisi gerekmez. Kafile hizmetini açmak için yalnız client-safe değerleri verin:

```sh
flutter run --dart-define=SUPABASE_URL=https://PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_PUBLIC_CLIENT_KEY
```

Gerçek public/publishable key kullanın; `sb_secret_` veya service-role key kabul edilmez. URL HTTPS origin olmalı. Paket kataloğunun ayrı `OfflinePackageRuntimeConfig` sözleşmesi korunur.

Supabase'de üç migration sırayla uygulanmalı. Auth e-posta şablonunda kullanıcıya kodu göstermek için `{{ .Token }}` bulunmalı; yalnız magic-link şablonuyla bu kod ekranının kabulü yapılmış sayılmaz. E-posta sağlayıcısı, hız limitleri ve davet/üyelik politikaları gerçek test projesinde doğrulanmalıdır. Gerçek kişilere test mesajı veya e-posta bu çalışmada gönderilmedi.

## Tekrarlanabilir kontroller

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --coverage
python3 tools/verify_audio.py
MVP_CAPTURE_UI=true flutter test test/mvp_ui_test.dart
flutter build apk --debug
# Yalnız macOS + Xcode ortamında:
flutter build ios --debug --no-codesign
```

Ses dosyası QA komutu ffmpeg/ffprobe ister; bunlar mobil uygulama bağımlılığı değildir. SQL harness kurulumu `supabase/tests/README.md` içindedir. PGlite uygulamanın mobil çalışma bağımlılığı değildir.

## GitHub ve devir

7 Ekim 2026 tarihinde GitHub yazma erişimi yeniden doğrulandı ve `codex/mvp1-pilot` dalı oluşturuldu. Önceki 403 erişim engeli giderildi. MVP çalışması bu dal üzerinden incelemeye sunulur; `main` ile eşit olduğu veya CI kontrollerinin geçtiği yalnız uzak depo kanıtıyla söylenebilir. Teslim paketi patch, doğrulama çıktıları ve ekran görüntülerini içerir. Temiz `b3ae97d` tabanına patch için önce `git apply --check mvp1.patch`, ardından `git apply mvp1.patch` çalıştırın. Yerel değişiklik varsa üzerine zorla uygulamayın; ayrı dal kullanın. Patch eski güvenlik/paket düzeltmelerini de içerir.

## Android CI ilk derleme düzeltmesi

İlk GitHub çalışması SDK action varsayılanının artık bulunamayan `tools` paketini istemesi nedeniyle APK üretmeden durdu. SDK paketleri platform-tools, Android 36 ve build-tools 36.0.0 olarak açıkça seçildi. SQL işinde eksik ripgrep kurulumu eklendi. Yeni workflow sonucu doğrulanana kadar APK hazır sayılmaz.
