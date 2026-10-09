# Sunucu bildirim ve konum dilimi — 9 Ekim 2026

Başlangıç uzak HEAD fetch ile `10963fe05931e8dc8f48afc0106da5abc380f04d` doğrulandı. Eski Linux worktree'sindeki dört commit ve iki belge değişikliği korunarak ayrı `codex/server-completion-oct09` worktree açıldı. Mac yolu ve fiziksel cihaz erişilebilir değildi. Önceki `docs/qa/2026-10-09-kabul-ozeti.json` tarihsel kabulü bu dilimin kabulü sayılmaz.

## Uygulanan davranış

`20261009090000_push_outbox.sql`: mesaj, duyuru ve program INSERT transaction'ında sunucuda token başına bir teslim işi oluşur. Kullanıcı kuyruk okuyamaz/yazamaz veya job RPC çalıştıramaz. Kaynak varlığı, güncel gönderen üyeliği/yetkisi, özel mesaj tarafı, alıcı üyeliği, arşiv/silme/süre ve opt-in token yeniden değerlendirilir. Aktif lease, `SKIP LOCKED`, eşsiz olay/token kimliği ve lease eşleşmeli bitirme aynı işi normal akışta iki worker'ın göndermesini engeller. Üyelikten çıkarılan alıcının işi iptal edilir; yeniden katılma eski iptali açmaz. Token sürümü sunucu saatindendir; eski token'ın geç gelen hatası yeni kaydı kapatmaz. İki hesaba bağlı aynı etkin token güvenli tarafta kalıp dışlanır.

`group-push` Edge Function: bağımsız bir servis yığını veya mobil bağımlılık eklenmeden mevcut Supabase içinde çalışır. Dedicated server secret ile POST çağrısı, service-role RPC, dar kapsamlı RS256 OAuth ve FCM HTTP v1 kullanır. Varsayılan `PUSH_SEND_MODE=disabled`; `test` modu açık test kullanıcı ve cihaz kayıt UUID allowlist'leri ister. Üretim modu ancak doğrulanmış hedef ve kullanıcı onayıyla açılmalıdır. 3 iş/çağrı, 8 saniye HTTP timeout, iki dakika lease, en çok beş deneme; HTTP 429/5xx/ağ hatasında en az 60 saniye üstel bekleme/jitter ve Retry-After uygulanır. 24 saat üzerindeki Retry-After gönderim penceresini aşarsa iş exhausted/RETRY_WINDOW_EXCEEDED olur; sağlayıcının istediği zamandan önce tekrar gönderilmez. UNREGISTERED token'ı kapatır; INVALID_ARGUMENT/payload, proje veya APNs yetki hatası sağlam token'ı iptal etmez, kalıcı iş hatası olarak tutulur. Yanıt/loglar credential, token, alıcı, sağlayıcı hata gövdesi veya mesaj taşımaz.

Bildirim metni yalnız “Kafilede yeni bir güncelleme var.”dır; mesaj metni, kişi, koordinat veya kaynak kayıt kimliği yoktur. Yönlendirme `kind/group_id` ve opak teslim olayını içerir. Mevcut istemci kafile üyeliğini yeniden sorgular; yetki/ağ hatasında ekran açılmaz. FCM cevabı `provider_accepted` olarak kaydedilir; telefona teslim kanıtı değildir.

**Dağıtık sistem sınırı:** Sağlayıcı kabulünden sonra worker ack yazamadan ölürse, lease sonunda sınırlı tekrar oluşabilir. FCM/APNs collapse kimliği yardımcıdır; tam exactly-once teslim garantisi vermez. Kontrol ile ağ isteği arasında gerçekleşen üyelik iptali, daha önce FCM'nin kabul ettiği bildirimi geri çağıramaz. Genel kilit ekranı metni ve istemci yeniden yetkilendirmesi bu aralıkta özel içerik açılmasını önler. Gerçek cihaz kabulünde bu yarış ayrıca denenmelidir.

`20261009091000_location_lifecycle.sql`: konum INSERT'i üyelik ve rıza satırlarıyla kilitlenir; iptal/üyelik çıkarılması ile eşzamanlı gönderim serileştirilir. Üyelik kaldırılması eski rızayı kalıcı durdurur; yeniden katılma koordinatı açmaz. Kafileyi oluşturan eski yöneticinin, üyelik kaldırıldıktan sonra konum okuması da kapanır. Saklama süresi biten koordinat cleanup gecikse bile RLS'den okunamaz. Temizleme indeksli saklama alanını kullanıp çağrı başına en fazla 100 koordinat siler; idempotent, SKIP LOCKED ve aktif kayıtları korur. Koordinatsız rıza geçmişi korunur; onun ayrı saklama kararı bekler.

**Saklama kararı:** Mevcut pilot istemcide `endsAt + 1 day` vardır; onaylı üretim politikası değildir. Yeni `location_retention_policy.seconds_after_end` başlangıçta NULL'dır: mevcut pilot sözleşmesini değiştirmez. Ürün/veri sorumlusu gerçek politikayı belirlediğinde sunucu değeri client talebinin yerine geçer. Üretim öncesi bu karar, kullanıcı açıklaması, mevcut pilot kayıtlarına uygulanacak geçiş ve koordinatsız rıza geçmişinin süresi belirlenmelidir. Sıfır, koordinatı paylaşım bitişinde silme hakkı verir; teknik ayar aralığı 0–30 gündür, önerilen üretim süresi değildir. Rıza geçmişi ile koordinat erişimi ayrıdır: sahibi kendi geçmiş koordinatını mevcut sözleşme gereği yalnız retention bitene kadar okuyabilir; yöneticinin erişimi iptal/endsAt anında kapanır. Yeni arka plan GPS veya otomatik ibadet tamamlaması eklenmedi.

## Çalıştırma ve geri dönüş

1. Ayrı test proje ref'i/URL'sini güvenli ortam ayarlarıyla eşleştir; üretim hedefinde fixture çalıştırma. Migration listesi ve şema yedeğini al; önce test projesinde iki migrasyonu uygula. Bu çalışma canlı veritabanında migrasyon uygulamadı.
2. Edge secret manager'a `SERVER_JOB_SECRET` (en az 32 karakter), `FCM_SERVICE_ACCOUNT_JSON`, `PUSH_SEND_MODE=test`, yalnız iki test hesabının `PUSH_TEST_USER_IDS` ve açık seçilen test cihaz kayıtlarının `PUSH_TEST_TOKEN_IDS` UUID değerlerini güvenli yerel dosyadan yükle. Secret değerini terminal loguna veya sohbete yazma. Mobil derleme yalnız Firebase istemci ayarlarını taşır; server secret/service-role/private key taşımaz.
3. İki fonksiyonu test projesine deploy et. JWT gateway yerine fonksiyon içi dedicated secret kontrolü aktiftir; kullanıcı JWT'si job çalıştıramaz. `supabase/functions/.env.example` yalnız boş yapılandırma şemasıdır.
4. pg_cron/pg_net ve Vault zaten varsa `supabase/operations/schedule_jobs.sql` ile iki adlandırılmış dakikalık işi kur. URL'nin ref'ini ayrıca kontrol et; Vault değerleri sadece çalışma sırasında çözülür. Bu script otomatik migrasyon değildir ve burada çalıştırılmadı. Kuyruk yükü/temizleme backlog'u sayım, en eski due timestamp ve job başarısıyla gözlenmeli; token/koordinat loglanmamalı.
5. Geri dönüş: adlandırılmış iki schedule'ı unschedule et, göndericiyi `disabled` yap, gerekirse yalnız yeni INSERT trigger'larını kaldırarak enqueue'yu durdur. Kuyruk, kişisel ilerleme veya katalog silinmez. Güvenlik/RLS ve konum iptal kilitlerini eski gevşek kurallara döndürme. Şema kaldırmak yerine bir sonraki ileri migrasyonu kullan; gerçekten schema rollback gerekirse doğrulanmış yedek/etki incelemesi ister.

Üretim hedefi, ücretli kaynak, gerçek kullanıcı bildirimi ve mağaza gönderimi bu dilimde yapılmadı. Test hesapları/telefonlar yapılandırılmadan hiçbir canlı push gönderilmedi.

## İçerik ve ses

Katalog hâlâ 18 Umre/35 Hac taslağı; 1 taslak dua ve 3 taslak ses kimliği. Onaylı gerçek yeni girdi bulunmadı. Mevcut paket/harita yaşam döngüsü tekrar yazılmadı; gerçek izinli harita, POI/rota, sunucu ve kayıtlar gelmeden dolu/offline saha kabulü verilemez.

`tools/verify_recording.py`: gerçek kayıt geldiğinde catalog/audio/text kimliği ve sürümü, güvenli dosya yolu/symlink, byte boyutu/SHA-256, açık beklenen süre/tolerans, tek AAC stream, decode bozulması, clipping/sessizlik kontrolünü yapar. Receipt alanları aracın docstring'inde. Kullanım: `python3 tools/verify_recording.py --catalog assets/content/umre_inventory.v1.json --receipt release-inputs/recording-receipt.json --recording-dir release-inputs/recordings`. Araç içeriği onaylamaz, declaredOrigin'i gerçek insan sesi kanıtı saymaz; telaffuz/eksik kelime/kırpılmış başlangıç-bitiş ve hak incelemesi zorunlu kalır. Sentetik fixture yalnız aracın regresyon testinde kullanılır, kullanıcı paketi değişmedi.

## Doğrulama

Yerel Linux: 39 önceki pgTAP fixture kontrolü, 43 yeni sunucu SQL fixture kontrolü ve 13 Node işleyici/OAuth testi geçti. Deno 2.5.6 iki Edge giriş noktasını type-check etti. 27 Python testi (23 önceki + 4 kayıt QA), katalog sayım/sürüm denetimi ve teknik AAC QA geçti; son genişletilmiş Python/sunucu kontrollerinin nihai sayısı CI sonuçlarıyla aşağıda güncellenecek. Yeni gerçek PostgreSQL concurrency testi iptal-önce, gönderim-önce, üyelik çıkarılması ve iki worker lease yarışlarını gözlenen DB lock ile doğrular; PGlite concurrency kanıtı sayılmaz.

Bu ortamda Flutter/Android SDK/Xcode veya canlı servis ayarı yoktur. Format/Flutter analiz-test, Android debug/split release, iOS simulator/no-codesign ve seçili native akışlar son kod commit'i için CI ile çalıştırılacak. İmzalı AAB/archive/TestFlight ve fiziksel cihaz profile/release performansı çalıştırılamaz. Build/CI sonucu bu belgeye ayrıca işlenecek.

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

Teknik test dağıtımı CI kapsamı geçerse önceki açık içerik sınırlamalarıyla değerlendirilebilir. Gerçek kullanıcı yayını için yukarıdaki sahip/girdi/kabul zinciri tamamlanmalıdır; `release_preflight` 155 eksik girdi/kanıt bildirir, uygulama hata sayısı değildir.
