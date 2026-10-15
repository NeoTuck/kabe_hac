# Mac kod ve yayın hazırlığı incelemesi — 8 Ekim 2026

## Kapsam ve Git durumu

Kullanıcının son yönlendirmesiyle inceleme kod, test ve loglarla sınırlandı. Cihaz pilot akışları tamamlanmış sayılmadı. İncelenen depo `/Users/mustafasenoglu/Desktop/kabe_hac`; yerel dal `codex/mvp1-pilot-desktop`, upstream `origin/codex/mvp1-pilot`. `codex/mvp1-pilot` adı başka bir worktree'de açık olduğundan mevcut temiz çalışma dizini fast-forward ile aynı uzak commit'e taşındı. Başlangıç ve fetch sonrası durum temizdi; `git fetch origin` ve `git merge --ff-only origin/codex/mvp1-pilot` başarılı. İncelenen HEAD ve beklenen commit birebir aynı: `f59c8ef9b609dc11b2c94d9d34bd3cc1042ef514`. Eski commit'e geri dönülmedi; `c7cb0c9`, `67335ff`, `f59c8ef` değişiklikleri görüldü. Push yapılmadı.

Bu rapor ile `test/counter_screen_test.dart` yerel, commitlenmemiş inceleme değişiklikleridir. Uygulama kaynak kodu değişmedi. Önceki CI sonucu geçmiş kanıt olarak okundu: `docs/13-yayin-hazirligi.md` içindeki `67335ff` / run `37769687931` yedi işi ve dört pilot akışı kapsıyor; bu Mac'teki cihaz veya canlı servis testi olarak sayılmadı. Mimari ve kabul sınırları için `AGENTS.md`, `docs/09-tam-surum-gelistirme.md`, `docs/qa/MOBIL_TEST.md`, `docs/11-kullanici-kalite-turu.md`, `docs/12-icerik-ve-ekran-gozden-gecirme.md` ve CI workflow okundu.

## Ortam

| Bileşen | Bu Mac'teki durum |
| --- | --- |
| İşletim sistemi | macOS 26.5.2, arm64 |
| Flutter / Dart | Projenin Flutter 3.47.6 / Dart 3.13.5 sürümü, tam yoldan kullanıldı. PATH içindeki bağımsız Dart 3.12.2 kullanılmadı. |
| Android | SDK `/opt/homebrew/share/android-commandlinetools`, API 35/36, build-tools 36.0.0, emulator 37.1.11; `flutter doctor -v` bazı Android lisanslarını eksik bildirdi. |
| Java | Sistem JDK 25; Android debug Gradle derlemesi bu sürümle tamamlandı. CI JDK 21 kullanıyor. |
| Xcode / CocoaPods | Xcode 26.6 uygulaması kurulu fakat seçili developer directory Command Line Tools. Xcode lisansı kabul edilmemiş; `simctl` açılamadı. `pod` yok. iOS derlemesi/uygulama açma çalıştırılamadı. Lisans kullanıcı adına kabul edilmedi. |
| QA araçları | Python 3.14.7, Maestro 2.11.0, ffmpeg mevcut. |

`flutter pub get` başarılı; bağımlılıklar topluca yükseltilmedi. `flutter doctor -v` ağ kaynaklarını erişilebilir, Android toolchain'i uyarılı ve Xcode'u kullanılamaz gösterdi.

## Yerel komutlar ve gerçek sonuçlar

| Kontrol | Sonuç |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | Temiz, 62 dosya / 0 değişiklik; test düzeltmesi sonrası tekrarlandı. |
| `flutter analyze` | Temiz; düzeltme sonrası tekrarlandı. |
| `flutter test --coverage` (`MVP_CAPTURE_UI=true`) | 153/153 başarılı. İlk koşuda sayaç testinde kaçan dokunuş uyarısı görüldü; aşağıdaki test düzeltildi. |
| `flutter test test/counter_screen_test.dart` | Düzeltmeden sonra 4/4 başarılı, uyarı yok. |
| `flutter test` | Düzeltmeden sonra 153/153 başarılı, önceki uyarı yok. |
| `python3 tools/verify_mobile_qa.py` | Dört Maestro YAML dosyası ve pilot komut politikası geçerli; cihaz testi değil. |
| `python3 -m unittest discover -s tools -p 'test_*.py' -v` | 14/14 başarılı. |
| `python3 tools/content_audit.py` | Umre 18/18, Hac 35/35 kayıt **taslak**; 1 dua, 3 ses kaydı tanımı. Onay kanıtı değil. |
| `python3 -m py_compile ...` | Başarılı. |
| `python3 tools/verify_audio.py` | 30 saniye AAC `teknik_demo.m4a` dosya QA başarılı; gerçek insan sesi/işitsel cihaz kabulü değil. |
| `flutter build apk --debug` | Başarılı. `build/app/outputs/flutter-apk/app-debug.apk`: 229603533 bayt, SHA-256 `61b78c0363cd70236f067212a7a79fe8fda031c33a49ba22d7a19c7a8fd10e16`. Debug/teknik paket; mağaza paketi değil. |
| `python3 tools/release_preflight.py --evidence-dir release-inputs` | Beklendiği gibi exit 2 / `blocked`: 155 engel. Rapor `build/release-preflight.json`. |
| Android pilot çalıştırıcısı | APK kuruldu ve kurulu hash beklenen APK ile eşleşti, fakat driver hazırlığında transport/boot kararlı kalmadı. `build/mobile-qa/20261008T115047Z-f774ca69/session.json`: `blocked`, `device_tests_run=false`; dört akıştan hiçbiri geçirilmiş sayılmaz. Kullanıcı yönlendirmesiyle cihaz denemesi sürdürülmedi. |
| iOS simulator build/açılış | Çalıştırılmadı: Xcode lisansı/developer directory ve CocoaPods ortamı hazır değil. |
| SQL fixture / canlı Supabase | Bu Mac'te çalıştırılmadı; pgTAP/PGlite test ortamı kurulmadı. CI'ın 39 bağımsız SQL testi canlı Supabase kabulü değil. |

Flutter widget testlerinin ürettiği ana ekran, ses, kafile ve karanlık ayar görselleri `build/mac-review/ui/` altında saklandı. Ana ekranın taslak uyarısı ve karanlık ayar ekranı görsel olarak incelendi; taşma görülmedi. Bunlar widget renderlarıdır, native Android/iOS ekranı değildir. Testin değiştirdiği izlenen `docs/mvp-ui/*.png` dosyaları ilk temiz Git sürümüne geri alındı.

## Düzeltme ve kod incelemesi

**Düşük önem — yanıltıcı sayaç regresyonu düzeltildi.** `test/counter_screen_test.dart` içindeki hızlı sıfırlama testi iki ekran dokunuşu yapıyordu. İlk dokunuşun açtığı modal engel ikinci dokunuşu yuttu; Flutter uyarı yazmasına rağmen test geçiyordu. Test artık aynı sıfırlama geri çağrısını yeniden çizimden önce iki kez çağırıyor, tek diyalog ve iptal sonrası sayının korunmasını doğruluyor. Uygulama sayaç kodu ve mevcut özellikler değişmedi.

Kod üzerinden doğrulanan teknik sınırlar:

- `lib/main.dart`: paket güven kökü yokken manifest reddedilir, paket kataloğu açılmaz; Supabase URL/publishable key yokken yapılandırılmamış kafile repository kullanılır; gezi/safety varsayılanları boş durumdur.
- `lib/content_repository.dart`, `lib/travel_repository.dart`, `lib/offline_package.dart`: etkin paket için tür, güven, dosya yolu/hash ve katalog ayrıştırma korumaları vardır; paket geri dönüş/silme yenilemesi `lib/selection_screens.dart` içinde bağlanmıştır. Bu kod lisanslı saha paketi bulunduğunu kanıtlamaz.
- `lib/guide_screens.dart`: taslak dua metni ve onaysız bağlı ses oynatımı gizlenir. `assets/content/*.json` onaylanmış yayın metni içermez.
- `lib/group_repository.dart` Supabase istemci adaptörü ve `supabase/` SQL/RLS fixture'ları vardır; derleme zamanı servis yapılandırması ve iki hesaplı canlı kabul yoktur.
- `android/app/build.gradle.kts`: üretim imzası yokken release engeli, yalnız açık `KABE_TECHNICAL_PILOT=true` için debug imzalı teknik release yolu vardır. İmza dosyaları okunmadı veya yazdırılmadı.

## Öneme göre bulgular ve kalan kabul

| Önem | Bulgu ve kanıt | Gereken somut iş |
| --- | --- | --- |
| Yayın engeli | `assets/content/umre_inventory.v1.json`, `hac_inventory.v1.json`: 53/53 adım taslak. `build/release-preflight.json`: 53 adım, 52 anlatım bağlantısı, 35 Hac profil incelemesi, 1 dua, 3 ses kaydı ve 11 dış kanıt kategorisi dahil 155 engel. | Gerçek metin/dua/kaynak/hak ve üç Hac profili için yetkili uzman incelemesi; içerik sürümüyle eşleşen izinli insan sesleri. |
| Yayın engeli | `lib/main.dart`, `lib/package_catalog.dart`, `lib/travel_repository.dart`, `lib/safety_catalog.dart`: gerçek paket sunucusu/güven özeti, lisanslı harita/POI/rota ve doğrulanmış saha/iletişim/dil girdileri yok. | İzinli veri/sağlayıcı, gerçek paketler, atıf ve uçak modu cihaz kabulü. |
| Yayın engeli | `lib/group_repository.dart`, `lib/group_sync.dart`, `lib/progress_store.dart`: mobil adaptör/outbox ve yerel rıza var; canlı Supabase, Auth/RLS/Realtime, gerçek GPS izin/gönderim ve APNs/FCM entegrasyonu kabul edilmedi. | İki hesap/grupla canlı izolasyon ve senkronizasyon; gerçek konum/push kodu ve teslim/iptal testleri. |
| Yayın engeli | `android/app/build.gradle.kts`, `pubspec.yaml`, `docs/13-yayin-hazirligi.md`: sürüm `0.1.0+1`, bu Mac'teki APK debug imzalı; iOS dağıtım imzası/mağaza belgeleri kanıtlanmadı. | Gerçek Android upload ve iOS dağıtım imzası, sürüm/artifact kimliği, gizlilik/mağaza beyanları ve fiziksel cihaz kabulü. |
| Ortam engeli | `flutter doctor -v`, Xcode çıktısı: Xcode lisansı/developer directory/CocoaPods hazır değil. | Geliştirme ortamı yetkili kullanıcı tarafından tamamlandıktan sonra iOS simulator build ve açılışı. |
| QA açığı | `build/mobile-qa/.../session.json`: Android pilot `blocked`, `device_tests_run=false`; kullanıcı kapsamı kod/log incelemesine daralttı. | Ayrı test cihazında açık seçimle dört pilot ve `docs/qa/MOBIL_TEST.md` tam matrisi; fiziksel Android/iPhone, ses, kulaklık/Bluetooth, çağrı, uçak modu ve erişilebilirlik kabulü. |

## Tamamlanma ayrımı

**Teknik olarak çalışan ve bu Mac'te otomatik test edilen:** Umre/Hac seçim ve kişisel devam akışları, manuel tavaf/sa‘y/cemarat sayaçları, taslak/onay filtresi, teknik ses durumları, güvenli offline paket ve gezi katalog katmanı, favori/ilerleme ayrımı, boş güvenlik/kafile durumları, açık/koyu tema ve 320/390 piksel ile %100/%200 yazı widget matrisi. Test isimleri ve kapsamı `test/` içindeki 153 Flutter testiyle sınırlıdır.

**Kısmi teknik temel:** grup backend/outbox, rızalı yerel konum modeli, harita adaptörü, çevrimdışı indirme ve ses oturumu. Mock/fixture ve simülatör geçmiş kanıtları üretim servis/cihaz kabulüne dönüşmez.

**Eksik üretim girdileri ve entegrasyon:** uzman onayı, insan sesi/hakları, lisanslı harita ve güncel saha verisi, canlı Supabase, GPS izin/gönderim, push, gerçek Android/iPhone ve dağıtım imzaları. 3D eklenmedi; mevcut özellikler kaldırılmadı.
