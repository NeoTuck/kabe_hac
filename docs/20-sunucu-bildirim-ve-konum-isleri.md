# Sunucu bildirim ve konum dilimi — 9 Ekim 2026

Başlangıç uzak HEAD fetch ile `10963fe05931e8dc8f48afc0106da5abc380f04d` doğrulandı. Eski Linux worktree'sindeki dört commit ve iki belge değişikliği korunarak ayrı `codex/server-completion-oct09` worktree açıldı. Mac yolu ve fiziksel cihaz erişilebilir değildi. Önceki `docs/qa/2026-10-09-kabul-ozeti.json` tarihsel kabulü bu dilimin kabulü sayılmaz.

## Uygulanan davranış

`20261009090000_push_outbox.sql`: mesaj, duyuru ve program INSERT transaction'ında sunucuda token başına bir teslim işi oluşur. Kullanıcı kuyruk okuyamaz/yazamaz veya job RPC çalıştıramaz. Kaynak varlığı, güncel gönderen üyeliği/yetkisi, özel mesaj tarafı, alıcı üyeliği, arşiv/silme/süre ve opt-in token yeniden değerlendirilir. Aktif lease, `SKIP LOCKED`, eşsiz olay/token kimliği ve lease eşleşmeli bitirme aynı işi normal akışta iki worker'ın göndermesini engeller. Üyelikten çıkarılan alıcının işi iptal edilir; yeniden katılma eski iptali açmaz. Token sürümü sunucu saatindendir; eski token'ın geç gelen hatası yeni kaydı kapatmaz. İki hesaba bağlı aynı etkin token güvenli tarafta kalıp dışlanır.

`group-push` Edge Function: bağımsız bir servis yığını veya mobil bağımlılık eklenmeden mevcut Supabase içinde çalışır. Dedicated server secret ile POST çağrısı, service-role RPC, dar kapsamlı RS256 OAuth ve FCM HTTP v1 kullanır. Varsayılan `PUSH_SEND_MODE=disabled`; `test` modu açık test kullanıcı ve cihaz kayıt UUID allowlist'leri ister. Üretim modu ancak doğrulanmış hedef ve kullanıcı onayıyla açılmalıdır. 3 iş/çağrı, 8 saniye HTTP timeout, iki dakika lease, en çok beş deneme; HTTP 429/5xx/ağ hatasında en az 60 saniye üstel bekleme/jitter ve Retry-After uygulanır. 24 saat üzerindeki Retry-After gönderim penceresini aşarsa iş exhausted/RETRY_WINDOW_EXCEEDED olur; sağlayıcının istediği zamandan önce tekrar gönderilmez. UNREGISTERED token'ı kapatır; INVALID_ARGUMENT/payload, proje veya APNs yetki hatası sağlam token'ı iptal etmez, kalıcı iş hatası olarak tutulur. Yanıt/loglar credential, token, alıcı, sağlayıcı hata gövdesi veya mesaj taşımaz.

Bildirim metni yalnız “Kafilede yeni bir güncelleme var.”dır; mesaj metni, kişi, koordinat veya kaynak kayıt kimliği yoktur. Yönlendirme `kind/group_id` ve opak teslim olayını içerir. Mevcut istemci kafile üyeliğini yeniden sorgular; yetki/ağ hatasında ekran açılmaz. FCM cevabı `provider_accepted` olarak kaydedilir; telefona teslim kanıtı değildir.

**Dağıtık sistem sınırı:** Sağlayıcı kabulünden sonra worker ack yazamadan ölürse, lease sonunda sınırlı tekrar oluşabilir. FCM/APNs collapse kimliği yardımcıdır; tam exactly-once teslim garantisi vermez. Kontrol ile ağ isteği arasında gerçekleşen üyelik iptali, daha önce FCM'nin kabul ettiği bildirimi geri çağıramaz. Genel kilit ekranı metni ve istemci yeniden yetkilendirmesi bu aralıkta özel içerik açılmasını önler. Gerçek cihaz kabulünde bu yarış ayrıca denenmelidir.

`20261009091000_location_lifecycle.sql`: konum INSERT'i üyelik ve rıza satırlarıyla kilitlenir; iptal/üyelik çıkarılması ile eşzamanlı gönderim serileştirilir. Üyelik kaldırılması eski rızayı kalıcı durdurur; yeniden katılma koordinatı açmaz. Kafileyi oluşturan eski yöneticinin, üyelik kaldırıldıktan sonra konum okuması da kapanır. Saklama süresi biten koordinat cleanup gecikse bile RLS'den okunamaz. Temizleme indeksli saklama alanını kullanıp planlı çağrı başına en fazla 100 koordinat siler (RPC batch aralığı 1–1000, NULL reddedilir); idempotent, SKIP LOCKED ve aktif kayıtları korur. Koordinatsız rıza geçmişi korunur; onun ayrı saklama kararı bekler.

**Saklama kararı:** Mevcut pilot istemcide `endsAt + 1 day` vardır; onaylı üretim politikası değildir. Yeni `location_retention_policy.seconds_after_end` başlangıçta NULL'dır: mevcut pilot sözleşmesini değiştirmez. Ürün/veri sorumlusu gerçek politikayı belirlediğinde sunucu değeri client talebinin yerine geçer. Üretim öncesi bu karar, kullanıcı açıklaması, mevcut pilot kayıtlarına uygulanacak geçiş ve koordinatsız rıza geçmişinin süresi belirlenmelidir. Sıfır, koordinatı paylaşım bitişinde silme hakkı verir; teknik ayar aralığı 0–30 gündür, önerilen üretim süresi değildir. Rıza geçmişi ile koordinat erişimi ayrıdır: sahibi kendi geçmiş koordinatını mevcut sözleşme gereği yalnız retention bitene kadar okuyabilir; yöneticinin erişimi iptal/endsAt anında kapanır. Yeni arka plan GPS veya otomatik ibadet tamamlaması eklenmedi.

## Çalıştırma ve geri dönüş

1. Ayrı test proje ref'i/URL'sini güvenli ortam ayarlarıyla eşleştir; üretim hedefinde fixture çalıştırma. Migration listesi ve şema yedeğini al; önce test projesinde iki migrasyonu uygula. Bu çalışma canlı veritabanında migrasyon uygulamadı.
2. Edge secret manager'a `SERVER_JOB_SECRET` (en az 32 karakter), `FCM_SERVICE_ACCOUNT_JSON`, `PUSH_SEND_MODE=test`, yalnız iki test hesabının `PUSH_TEST_USER_IDS` ve açık seçilen test cihaz kayıtlarının `PUSH_TEST_TOKEN_IDS` UUID değerlerini güvenli yerel dosyadan yükle. Secret değerini terminal loguna veya sohbete yazma. Mobil derleme yalnız Firebase istemci ayarlarını taşır; server secret/service-role/private key taşımaz.
3. İki fonksiyonu test projesine deploy et. JWT gateway yerine fonksiyon içi dedicated secret kontrolü aktiftir; kullanıcı JWT'si job çalıştıramaz. `supabase/functions/.env.example` yalnız boş yapılandırma şemasıdır.
4. pg_cron/pg_net ve Vault zaten varsa `supabase/operations/schedule_jobs.sql` ile iki adlandırılmış dakikalık işi kur. URL'nin ref'ini ayrıca kontrol et; Vault değerleri sadece çalışma sırasında çözülür. Bu script otomatik migrasyon değildir ve burada çalıştırılmadı. Kuyruk yükü/temizleme backlog'u sayım, en eski due timestamp ve job başarısıyla gözlenmeli; token/koordinat loglanmamalı.
5. Geri dönüş: adlandırılmış iki schedule'ı unschedule et, göndericiyi `disabled` yap, gerekirse yalnız yeni INSERT trigger'larını kaldırarak enqueue'yu durdur. Kuyruk, kişisel ilerleme veya katalog silinmez. Güvenlik/RLS ve konum iptal kilitlerini eski gevşek kurallara döndürme. Şema kaldırmak yerine bir sonraki ileri migrasyonu kullan; gerçekten schema rollback gerekirse doğrulanmış yedek/etki incelemesi ister.

Üretim hedefi, ücretli kaynak, gerçek kullanıcı bildirimi ve mağaza gönderimi bu dilimde yapılmadı. Test hesapları/telefonlar yapılandırılmadan hiçbir canlı push gönderilmedi.

## İçerik ve ses

Kataloglarda 18 Umre/35 Hac benzersiz sabit kimlik, metin sürümü, kaynak başlığı/URL/konumu/erişim tarihi/hak alanı ve mevcut ses-metin sürüm bağları denetlendi. Şema/sürümler ve kataloglar değişmedi. Katalog hâlâ 18 Umre/35 Hac taslağı; 1 taslak dua ve 3 taslak ses kimliği. Onaylı gerçek yeni girdi bulunmadı. Mevcut paket/harita yaşam döngüsü tekrar yazılmadı; gerçek izinli harita, POI/rota, sunucu ve kayıtlar gelmeden dolu/offline saha kabulü verilemez.

`tools/verify_recording.py`: gerçek kayıt geldiğinde catalog/audio/text kimliği ve sürümü, güvenli dosya yolu/symlink, byte boyutu/SHA-256, açık beklenen süre/tolerans, tek AAC stream, decode bozulması, clipping/sessizlik kontrolünü yapar. Receipt alanları aracın docstring'inde. Kullanım: `python3 tools/verify_recording.py --catalog assets/content/umre_inventory.v1.json --receipt release-inputs/recording-receipt.json --recording-dir release-inputs/recordings`. Araç içeriği onaylamaz, declaredOrigin'i gerçek insan sesi kanıtı saymaz; telaffuz/eksik kelime/kırpılmış başlangıç-bitiş ve hak incelemesi zorunlu kalır. Sentetik fixture yalnız aracın regresyon testinde kullanılır, kullanıcı paketi değişmedi.

## Doğrulama

Yerel Linux: 39 önceki pgTAP fixture kontrolü, 45 yeni sunucu SQL fixture kontrolü ve 13 Node işleyici/OAuth testi geçti. Deno 2.5.6 iki Edge giriş noktasını type-check etti. 30 Python testi (23 önceki + 4 kayıt QA + 3 ADB kanıt regresyonu), katalog sayım/sürüm denetimi ve teknik AAC QA geçti; nihai CI sonuçları aşağıda ayrıca kayıtlıdır. Yeni gerçek PostgreSQL concurrency testi iptal-önce, gönderim-önce, üyelik çıkarılması ve iki worker lease yarışlarını gözlenen DB lock ile doğrular; PGlite concurrency kanıtı sayılmaz.

Bu ortamda Flutter/Android SDK/Xcode veya canlı servis ayarı yoktur. Format/Flutter analiz-test, Android debug/split release, iOS simulator/no-codesign ve seçili native akışlar son kod commit'i için CI ile çalıştırıldı. İmzalı AAB/archive/TestFlight ve fiziksel cihaz profile/release performansı çalıştırılamaz. Build/CI kapsamı aşağıda ayrıca kayıtlıdır.

## Son kod ve artifact kanıtı

Son kod `a4dee8d35f0b764373da3bdc4d313babc031cf67`; PR test SHA `9c360482281e55fcd87e348ba85264ba604ea24c`. Fetch ile ikisinin ağacı birebir `b6d355ca00e255dbeb512df8623e3f7848538f25` doğrulandı. [Nihai CI 37899499075](https://github.com/NeoTuck/kabe_hac/actions/runs/37899499075); attempt 2 completed/success, yedi iş başarılı; altı başarılı iş korunup yalnız iOS hazırlık ortam işi bir kez tekrarlandı. Makinece okunabilir kanıt `docs/qa/2026-10-09-sunucu-kabul.json`. CLI fetch çalıştı; CLI push credential bulunmadığı için bağlı GitHub uygulamasında Git Data API ile test edilen ağaçların aynısı oluşturuldu. Dal expected HEAD ile force=false, normal fast-forward ilerletildi. Main merge edilmedi. Eski worktree HEAD `83d70ca`, dört yerel commit ve iki dirty belge korundu; Mac yolu erişilebilir değildi.

Commit'ler: sunucu `20d4332`; kayıt QA `d0eb4a1`; postgres-okunabilir fixture `6614584`; rıza açılışı/kaldırılma ve RLS saat uyumu `896185a`; test cihaz filtresi/bekleme sınırı `45cc5ed`; ADB tanı/aynı dosya shell aktarımı `dd4283d`; NULL batch sınırı `a4dee8d`. Son belge commit'i yalnız kanıtı kaydeder; kod kabulü yukarıdaki SHA'dır.

Nihai CI'da 39 pgTAP + 45 yeni SQL + 7 gerçek PostgreSQL 16 yarış + 13 işleyici/OAuth ve Deno 2.5.6 check başarılı. QA 30 Python; Flutter 3.47.6 format 71 dosya temiz, analiz temiz ve 180 test başarılı. Android debug/ayrı ses QA ve üç optimize release build'i başarılı. iOS debug/no-codesign, simulator ve ayrı ses QA build'leri başarılı; native sonucu aşağıda ayrıca tutulur: iPhone16/iOS18.5/SDK18.5 simülatörü artifact `11602993704` bağımsız açıldı; beş uygulama + bir ayrı ses JUnit, failure/error/skipped yok, iki session passed/device_tests_run=true/driver_prepared=true ve PR source SHA eşit. Fiziksel iPhone değildir.

Optimize kullanıcı APK artifact'ı [11602071572](https://github.com/NeoTuck/kabe_hac/actions/runs/37899499075/artifacts/11602071572); debug kullanıcı APK [11601034745](https://github.com/NeoTuck/kabe_hac/actions/runs/37899499075/artifacts/11601034745). ZIP içindeki gerçek APK byte boyutu/SHA-256 bağımsız hesaplanıp CI raporuyla karşılaştırıldı. Üç optimize APK'da APK v2 signed-data RSA imzası, chunked içerik digest'i ve sertifika/public key eşleşmesi ayrıca doğrulandı. Sertifika `C=US,O=Android,CN=Android Debug`, SHA-256 `69ef4d2fddc1e86f0846ca64c6b6124023e839cad736102e7cf903a761021b50`; üretim/upload anahtarı değildir. APK hash'i ZIP hash'i değildir.

| Tür | Byte | APK SHA-256 | İmza/kabul |
| --- | ---: | --- | --- |
| ARM64 optimize release APK | 36,262,857 | `affa8e3a56f3fe285ca1494f836d1de820dc6533c97debd98b58584b24e8099f` | Teknik debug key; v2 imza/digest doğrulandı |
| ARMv7 optimize release APK | 31,007,791 | `5ee8b090e910c042da97ce703d5bb6478703bf45427eef40c0a7e7d02cd7f598` | Teknik debug key; v2 imza/digest doğrulandı |
| x86_64 optimize release APK | 38,163,750 | `989c9b06ea9149ed03d425882810fc2898a369b6be4653adaa71ed526ad36b80` | Teknik debug key; v2 imza/digest doğrulandı |
| Android debug kullanıcı APK | 216,958,400 | `fe1aae158fba89392ed694c7053abf98d1a17361cd6cf9966f9530024a349e41` | Debug key; son native kurulu hash eşit |
| İmzalı AAB / iOS archive / TestFlight | Oluşturulmadı | Yok | Gerçek üretim imzaları yok |

iOS `.app` bundle'ı CI'da derlendi ancak teslim artifact'ı olarak yüklenmiyor; boyutu/hash'i bu tur ölçülmedi. Bu imzalı iPhone archive değildir. Optimize APK üzerinde fiziksel/release smoke veya performans kabulü verilmez. Native matris son debug kullanıcı APK'sını test eder. Ayrı ses QA APK'sı `11602151789`, kullanıcı dağıtımı değildir; native hash `1828774801ccc52686777fb23bada49c4f654f8de27f9f4940021cef03f7dddc`. Kullanıcı APK'ları için teknik fixture exclusion kontrolü geçti.

Android API28 artifact `11602052148` ve API35 artifact `11602177716` bağımsız açıldı. Her birinde beş uygulama + bir ayrı ses vakası, JUnit failure/error/skipped yok; iki session passed/device_tests_run=true/driver_prepared=true. Kullanıcı/QA installed ve expected hash'leri eşit. Bunlar Pixel 2 profilli x86_64 google_apis emülatör/debug testidir, fiziksel telefon değildir. Android CI -noaudio; insan sesi veya işitsel kalite kabulü vermez. Umre/Hac'ın tamamı/üç profil/gerçek paket/servis/erişilebilirlik/arka plan ve kesinti kabulünü beş seçili akıştan çıkarmayın. UI widget renderları önceki aynı Flutter kodu `45cc5ed` artifact `11599959390` üzerinden incelendi; son CI da render üretir, TalkBack/VoiceOver kabulü değildir.

### Teşhis edilen başarısızlıklar

- DB `37895450458`: test başlamadan postgres kullanıcısı checkout'u okuyamadı; fixture okunabilir `/tmp` dizinine kopyalandı.
- DB `37895564259`: gerçek yarış assertion'ı transaction-start `now()` ile yeni ölçüm zamanı uyumsuzluğunu buldu. RLS wall-clock ve rıza açılışı üyelik kilidi düzeltildi; assertion kaldırılmadı.
- Android API35 `37896363030` attempt 1/2: APK transfer önkontrolü failed, UI hiç başlamadı. Eski araç komut/stderr'i saklamıyordu; hata ayrıntısı ve tek shell dosya aktarımı alternatifi eklendi. Son run normal adb-sync ile geçti, fallback kullanılmadı. Önceki transfer hatasının kök nedeni kesinleşmedi; fallback'in bunu çözdüğü iddia edilmez. Hash şartı hiç atlanmadı.
- iOS `37899499075` attempt 1: simulator ve build başarılı, Maestro XCTest driver 180 sn hazırlık timeout'u; `device_tests_run=false`, uygulama assertion'ı çalışmadı. Artifact `11601857715` driver/session log'u bağımsız açıldı. Yalnız bu teşhis edilen ortam işi bir kez tekrarlandı; attempt 2 geçti. Test başlamadan oluşan ortam hatası UI başarısızlığı değildir; başarısız uygulama assertion tekrar edilmedi.

## Dış girdiler ve sonraki kabul

| Sorumlu | Somut girdi | Sonraki doğrulama |
| --- | --- | --- |
| Ürün/veri sorumlusu | Koordinat ve rıza geçmişi saklama politikası; kullanıcı açıklaması | Sunucu ayarı, sınır ve geçiş/temizleme kabulü |
| Backend/Firebase hesap yöneticisi | Doğrulanmış test proje ref'i, iki hesap/iki kafile; test cihazları ve APNs | Auth/RLS/Realtime/offline outbox, tercih/token/üyelik iptali ve FCM/APNs uçtan uca |
| Dinî/dil uzmanı | 53 adım, dua, üç Hac profilinin gerçek tarihli incelemesi | Sabit kimlik/sürüm bağları korunarak katalog kabulü |
| Ses hakkı sahibi ve dil inceleyeni | Metin sürümüne bağlı izinli kayıt + hak kanıtı | verify_recording, işitsel inceleme; hoparlör/Bluetooth/çağrı/kilit ekranı |
| Saha/veri/harita sorumlusu | Dağıtım lisansı/atıf, kaynak ve güncellik, doğrulanmış POI/rota/iletişim; HTTPS paket hosting/pin | Gerçek paket uçak modu/kesinti/hash/güncelleme/geri dönüş/silme |
| Mobil test sorumlusu | Fiziksel Android/iPhone ve build kimliği | Tam profil/rehber/sayaç/prova, erişilebilirlik ve profile/release ölçümleri |
| Yayın hesabı sahibi | Android upload/Apple distribution imzası, yayın geçmişi ve gerçek destek/gizlilik girdileri | İmzalı AAB/archive, son artifact smoke, kullanıcı incelemesi; ardından mağaza gönderimi |

Teknik debug test dağıtımı: seçili smoke geçmiş son debug kullanıcı APK, açık içerik sınırlamalarıyla yalnız ayrılmış test cihazı/yeni test profili için incelemeye sunulabilir. CI debug sertifikası run'lar arasında değişir (önceki ve son fingerprint farklı); mevcut kullanıcı uygulamasını/ilerleme/favorileri silerek imza uyuşmazlığını aşmayın. Mevcut uygulamaya güncelleme aynı imza ve veri koruma kabulünü ister. Optimize APK: build/hash/imza doğrulandı, son optimize artifact cihaz smoke/performance bekler. Gerçek kullanıcı yayını için yukarıdaki sahip/girdi/kabul zinciri tamamlanmalıdır; `release_preflight` 155 eksik girdi/kanıt bildirir, uygulama hata sayısı değildir.
