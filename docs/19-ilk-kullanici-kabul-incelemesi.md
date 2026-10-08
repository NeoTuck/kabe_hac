# İlk kullanıcı kabul incelemesi — 9 Ekim 2026

**Son kullanıcı yayını hâlâ engelli.** Bu tur açılış, ses, izin/iptal yarışları ve native test kapsamını iyileştirir. Teknik emülatör kabulü, dinî içerik ve gerçek saha kullanım kabulünden ayrıdır.

Başlangıç: `04e7ebdd2ab2ec4d422798216844faa9caef2b34`. Doğrulanan son kod: `2fbaaf5e091858fae36b4c810b930d6a51c130ca`, dal `codex/mvp1-pilot`. PR test çalışma ağacı: `4139051b604f4df6a46712f12a5813bb06bbdf14`. [CI 37856131455](https://github.com/NeoTuck/kabe_hac/actions/runs/37856131455).

Bu çalışma Linux inceleme ortamındadır; kullanıcının Mac'i veya fiziksel telefonu değildir. Yerel Flutter/Android SDK/Xcode yoktur. Flutter ve native build/çalıştırma GitHub CI ile doğrulanır. Yerel Python/format/YAML/AAC kontrolleri ayrıca çalıştırılmıştır. Bu belgenin son commit'i yalnız doküman günceller; kod kabulü yukarıdaki SHA ve CI run'ına aittir.

## Kod düzeltmeleri

- İlk ekran yerel platform yüklemesi başlamadan çizilir; yerel yükleme hatasında kayıtları silmeden tekrar denenebilir.
- Yerel rehber kullanılabilir olduktan sonra Supabase/Firebase hazırlanır. Servis arızası offline rehberi kilitlemez. Backend hazır olduğunda ana ekran güncel repository'yi kullanır.
- Gömülü içerik bir kez okunur, bağımsız yerel okumalar birlikte başlatılır. İndirilen rehber JSON'u 8 MiB ile sınırlıdır.
- Platform medya entegrasyonu ilk ses isteğine ertelenir ve süreç genelinde bir kez kurulur. Tekrarlanan background audio kaydı engellenir.
- Native oynatma/pause değişiklikleri rehber UI'ına yansır; completed durumunun native event sırasına dayanıklılığı düzeltilir. Ses olayı dinî ilerleme üretmez.
- Bildirim aç/kapat/devam işlemleri sıraya alınır. İzin beklerken kapatılan kayıt sonradan yeniden açılmaz; dispose sonrası notify engellenir.
- Konum gönderimi sürerken iptal veya hesap değişimi, yeni paylaşım başarısı gibi sunulmaz.
- 3D eklenmedi; mevcut rehber, sayaç, gezi, kafile, paket ve isteğe bağlı prova akışları korunur.

## Test kapsamı ve kanıt

| Kontrol | Sonuç ve sınır |
| --- | --- |
| Flutter | 180 test; format/analiz temiz. Widget testleri, gerçek cihaz kabulü değildir. |
| Python | 23 kontrol; YAML ve QA politika denetimi başarılı. |
| SQL | 39 bağımsız pgTAP fixture kontrolü; canlı Supabase değildir. |
| UI widget matrisi | 320/390 px ve %100/%200 yazı; ana ekran ve koyu ayar renderları gözle incelendi. |
| Android build | Debug ve üç optimize ABI split build; teknik debug imzası, mağaza imzası yok. |
| iOS build | No-codesign, simulator ve ayrı QA app build; fiziksel dağıtım imzası yok. |
| Android API28/API35 | İlk kod turunda beş uygulama + ayrı ses vakası geçti; session/JUnit ve kurulu APK hashleri ayrı incelendi. Son selector düzeltmesi için CI tekrarı: Android API28 ve API35 son CI tekrarında da 5+1 passed; aynı run'ın kurulu APK/hash denetimi ve JUnit vaka denetimi başarı şartıdır.. |
| iOS 18.5/iPhone16 simulator | Son turda beş uygulama ve ayrı native ses vakası geçti; CI loglarında iki `passed` / `device_tests_run=true` kaydı. Son iOS artifact'ın tüm görüntüleri ayrıca gözle incelendi iddiası verilmez. |
| AAC dosya QA | 30.000 s, AAC, RMS -17.5/peak -3.2 dBFS. Teknik test dosyası; insan sesi kabulü değil. |
| Kullanıcı APK'sı | Teknik ses fixture'ının dışlanması zorunlu kontrol ile doğrulanır. Ayrı QA APK kullanıcı paketi değildir. |

Native uygulama akışları debug kullanıcı build'indedir; optimize release build yalnız derleme/boyut/fixture kontrolünden geçti, release üzerinde native tüm ürün veya fiziksel performans kabulü verilmez.

Ana beşli matris: Umre hazırlık/yolculuk girişleri, ayarlar, onaylı ses yok durumu, yapılandırılmamış servisler, isteğe bağlı prova başlat/duraklat/yeniden aç/devam. Bu matris boş/onaysız build'deki akışları test eder; onaylı 53 adımı, dolu haritayı, canlı kafileyi veya gerçek push/GPS teslimini kabul etmiş olmaz.

Ses probe'u `tools/audio_probe.dart` ve `.maestro/audio-probe.yaml` ile ayrı debug giriş noktasıdır. `KABE_AUDIO_QA=true` ister, release modda çalışmayı reddeder, `lib/main.dart` tarafından import edilmez. Build aracı fixture'ı yalnız geçici pubspec'e ekler ve üretim manifest/artifact'ını `finally` ile geri getirir. Native eklentide oynatma, süre ve konum ilerlemesi, pause/resume, seek/completion, replay/stop kontrol edilir. Probe dinî ilerleme yazmaz.

**Android CI emülatörü `-noaudio` kullanır.** Decode/oynatıcı durumu kanıtı hoparlörden duyma, insan telaffuzu, kilit ekranı, Bluetooth veya çağrı kabulü değildir. Fiziksel Android/iPhone ve TalkBack/VoiceOver ayrı kalır. Minimum build sürümleri API28 ve iOS15; native iOS testi 18.5'tedir, iOS15 cihaz kabulü verilmez.

## Yakalanan CI hataları ve müdahale

- Önceki iOS run `37849860678`: dört vakadan ilk rehber geçişi başarısız, hata görüntüsü boş ekran. Yalnız görüntüyle kesin kök neden atanmadı. Driver hazırlığı/konsol kaydı eklendi; assertion kaldırılmadı.
- İlk genişletilmiş run [37853800928](https://github.com/NeoTuck/kabe_hac/actions/runs/37853800928), kod `cf7617b8f29b5ae2a7fc381d7a1b976ddfdb1c6d`: 180 Flutter/23 Python/39 SQL, iki Android'de 5+1 başarılı. iOS ilk dört vaka başarılı, prova başlığı exact selector ile bulunamadı.
- iOS hata hiyerarşisi başlığın `1 / 18 · U01\nKullanım biçimi seçimi\n…` içinde birleştiğini gösterdi; görüntüde ekran açılmıştı. Yalnız başlığı zorunlu tutan tek/birleşik label regex'i ve yapılandırma regresyonu değişti. Son iOS 5+1 geçti. Başarısız UI assertion'ları otomatik tekrar edilmez.
- Önceki apt indirmesi 180 s'de durmuştu; bağımlılık kurulumu 600 s sınırlı tekrar ve `--no-install-recommends` kullanır.
- Son run ilk Flutter işi: 180 test ve AAC QA geçti, Android NDK indirmesi `unknown archive` ile derlemeyi durdurdu. Yalnız bu ortam hatası için ilgili job yeniden çalıştırıldı. Flutter tekrarı başarılı. API35 ilk native girişinde ADB okuma hatasıyla blocked/device_tests_run=false oldu; UI başlamadan duran yalnız bu ortam işi tekrar çalıştırıldı ve 5+1 passed. Run üçüncü attempt sonunda yedi iş success..

İlk genişletilmiş Android kanıtı: API28 artifact `11583996272`, API35 `11583970758`; üretim debug APK SHA-256 `99a75c1e9030183a3d27f51ffe6121dc448bf44eaa0c127b487229bc08f3b8f1`, ayrı QA APK `435abd80dec44ed83f387131e39d186500ba47b25ed604b59ccd6086cdd671a6`. İki session'da installed/expected hash eşit, driver_prepared/device_tests_run true.

Son iOS artifact: `11585280946`; optimize split artifact: `11584067681`. ARM64 teknik pilot: 36,262,857 bayt (~36.3 MB), SHA-256 `76f96dc41b7207f7cb3868444e96d269ff5f8451f834c4fd9d1cfe73f11573ea`. ARMv7 ~31.0 MB, x86_64 ~38.2 MB. Boyut açılış hızı veya düşük bellekli telefon akıcılığı kanıtı değildir. Son native artifact'lar CI run sayfasındadır.

## Yayın engelleri — gerçek gerekenler

`release_preflight.py --evidence-dir release-inputs`: **blocked, 155**. Kod hatası toplamı değil, eksik girdi/kanıt toplamıdır: 53 adım, 52 anlatım bağlantısı, 35 Hac profil incelemesi, 1 dua, 3 ses kaydı ve 11 dış kabul kategorisi.

1. 18 Umre/35 Hac için kaynaklı açıklama/dua ve üç Hac profilinin gerçek yetkili uzman incelemesi. Kaynak ve özgün taslaklar zaten vardır; uzman kararı uydurulmaz.
2. Metin kimliği/sürümüyle eşleşen izinli insan kayıtları ve kaynak/ses kullanım hakları. Üretim metin/ses paketinin uçak modu, yeniden açma, yarım indirme ve güncelleme kabulü.
3. Gerçek paket sunucusu, sabit güven özetleri, offline dağıtım izni bulunan harita ve doğrulanmış POI/rota/iletişim/dil/saha verisi.
4. Gerçek Supabase/Firebase proje yapılandırması; iki hesap/grupta Auth/RLS/Realtime/outbox kabulü, sunucu push göndericisi, APNs/FCM teslimi, GPS izin/iptal/süre, saklama/silme otomasyonu. Model ve istemci kodu tek başına canlı entegrasyon değildir.
5. Fiziksel Android/iPhone: izin reddi, Bluetooth/kulaklık/çağrı/arka plan, uçak modu, düşük bellek, native erişilebilirlik. Profile/release modunda cihaz adıyla soğuk/sıcak açılış, kare/bellek/pil ölçümü; bu tur gerçek cihaz ms/FPS hedefi kanıtlamaz.
6. Gerçek upload/Apple dağıtım imzaları, sürüm kodu, gizlilik/mağaza beyanları, gerçek destek URL'leri ve imzalı mağaza artifact'ı.

Son kanıt olmadan `approved`, gerçek inceleyen/hak belgesi veya fiziksel cihaz sonucu eklenmedi. Onaysız dinî içerik ve test saha verisi kullanıcıya açılmadı. Teknik QA dosyası kullanıcı APK'sından ayrı tutuldu. **Tam ibadet ve saha rehberi olarak ilk son kullanıcılara hazır kabulü verilmez.** Yalnız açıkça bilgilendirilmiş teknik test kapsamına uygundur.

Tam cihaz matrisi ve ayrı QA paketinin çalıştırılması: [MOBIL_TEST.md](qa/MOBIL_TEST.md).

## Son run manifesti

CI attempt 3: **completed / success, yedi iş**. Son source SHA aynı `2fbaaf5`; Android 28 artifact `11585467638`, Android 35 `11585972310`, iOS `11585280946`; kullanıcı debug APK `11585930233`, yalnız QA APK `11585645924`, UI render `11584883418`, optimize split `11584067681`.

Son CI loglarında üç platformun her birinde beş uygulama + ayrı ses session'ı `passed` ve `device_tests_run=true` olarak doğrulandı; çalıştırıcı JUnit vaka sayısı, failure/error/skipped ve Android installed/expected hash şartlarını geçmeden başarı vermez. Son artifact arşivleri bu ortamda bağımsız yeniden açıldı iddiası verilmez; yerel komut aracı son aşamada yanıt vermedi. Önceki Android artifact'larının bağımsız JUnit/hash/ekran incelemesi yukarıda farklı SHA ile belirtilmiştir. Son iOS prova hata görüntüsü/hiyerarşisi incelendi ve assertion düzeltmesinin native tekrar sonucu başarıdır.

Makine okunur özet: [2026-10-09-kabul-ozeti.json](qa/2026-10-09-kabul-ozeti.json). Bu manifest üretim kabul dosyası değildir.
