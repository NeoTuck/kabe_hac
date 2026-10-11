# Teknik yayın adayı — 11 Ekim 2026

Durum: erişilebilir teknik uygulama tamamlandı; yeni native çalışma ve gerçek içerik/hizmet/yayın kabulü ayrı açık kapılardır. `LIVE_SERVICE_ACCEPTED` kapalı, 53 adım ve 54 sentetik ses taslaktır.

## İcra planı ve başlangıç

1. Uzak HEAD, PR #2, talimat ve mevcut paketleri doğrula; tamamlanmış hazırlık/indirme/favori/prova altyapısını koru.
2. Sunucunun seçtiği sürümlü koşul kabulü ve güvenilir hesap silme tamamlamasını uygula; RLS, güvenlik işlemleri ve outbox ile test et.
3. Ortak liste/harita filtresi, ölçülen harita çözme yükü, sürüm değişiminde ilerleme koruması ve kullanıcı ses kontrollerini tamamla.
4. Gerçek paketli anlatımlar için native regresyon ekle; boş rota/dil/saha teslimini somutlaştır. Gerçek dış veri/onay yoksa uydurma.
5. Yerel doğrulama, erişilebilir derleme, küçük commit ve force kullanmadan hedef dal/PR teslimi yap; yeni CI sonucunu ayrıca izle.

Başlangıç temiz hedef dal/uzak HEAD `df3f3f9370647469c4cf3df4412349dfb3a6f618`. PR #2 `f39d107bc041b5494cd2edf7e67624b1c9824d44` ata olarak doğrulandı ve merged/closed; ilk kullanım değişikliği korunuyor. Başlangıç [CI 38091307573](https://github.com/NeoTuck/kabe_hac/actions/runs/38091307573) completed/success; sekiz işin (Flutter, QA, veritabanı, Android paket/UI API28/API35, iki iOS işi) sonucu API'den kontrol edildi. Bu eski kodun sonucu yeni değişikliklerin native kabulü değildir. 16.4/26.2 Xcode sürümleridir.

## Uygulanan davranış

- Kafile koşullarının tam metni/sürümü sunucudan okunur; kabul kimliği Auth'tan, zaman sunucudan alınır. Yeni sürüm, hesap değişimi ve çevrimdışı hata yeniden kontrol gerektirir. Güncel kabul olmadan doğrudan tablo ve mevcut grup/davet RPC yazmaları trigger ile reddedilir. Güncel sürümü istemci seçemez, kabul tablosunu değiştiremez; yayımlanmış metin aynı sürümde değiştirilemez. RLS aktif üyeliği ayrıca denetler. Eski outbox kayıtları korunur; kullanıcı koşul kontrolüne yönlendirilir. Şikâyet, engel, token iptali, konum durdurma ve hesap silme kabulden bağımsız kalır. Gerçek koşul metni seed edilmedi; operatör teslimi `supabase/operations/SERVICE_TERMS.md`.
- Silme tamamlandı durumu yeni service-role RPC ile kayıt kilidi altında yalnız Auth hesabı artık yokken yazılır. Sunucu zamanı ve tekrar çalıştırma korunur. Silme isteği alındı, işlem hazırlanıyor ve hesap silindi farklı durumlardır; istemci tamamlayamaz. Mevcut sınırlı sayfalama, moderasyon audit/lease, sahiplik, şikâyet saklama ve konum iptal altyapısı korunur.
- Harita ve yer listesi aynı Türkçe/yerel ad araması ve kategori durumunu kullanır. Haritaya uygulama, sonuç sayısı, boş sonuç yönlendirmesi ve temizleme vardır. Native MapLibre POI filtresi listedeki aynı görünür kimliklerle kurulur; test verisi gizlenir. Harita canlı yol tarifi veya güvenli yürüyüş iddiası taşımaz.
- Hazırlık ekranı ve mevcut paket seçme/indirme/yerel hash kontrolü korunur. İptal, kesinti, alan, bozuk paket, yeniden açma ve önceki sürüme dönüş mevcut regresyonlarla doğrulanır. Hazırlık için native akış 08 eklendi; kurulu dosya, onaylı içerik ve cihazda açma ayrı durumlardır.
- Şehir geometrisini çözme ve style JSON üretimi tek worker içinde tamamlanır; büyük geometri iki kez ana isolate'a taşınmaz. Hash, şema, boyut ve açma güven kapıları korunur. Üretilen style önceki yol ile birebir test edilir. Ölçüm aşağıdadır.
- Profil/içerik sürümü değişince eski rehber kaydına yeni adım/işaret yazılmaz; kullanıcı açıkça ayrı sürüm kaydı açar. Eski konum, işaret ve sayaç kalır. Prova ve gerçek rehber ayrıdır. Test belleğindeki onaylı fixture ile Temettü 35, İfrad 34, Kıran 33 uygulanabilir adım ve bütün önceki/sonraki sırası doğrulandı; fixture kullanıcı kataloğuna eklenmedi. Gerçek taslak profiller onaylı yapılmadı.
- Kullanıcı sesinde hız seçimi, oynatma/duraklatma/devam ve seek bulunur. Native akış 03 gerçek paketli taslak anlatımı oynatır; ayrı teknik probe değildir. `integration_test/bundled_narration_test.dart` iki gerçek katalogdaki **her paketli dosyayı** native backend ve kullanıcı AudioControls üzerinden yükler, ilerleyen süre/duration, duraklatma/devam, seek/hız ve hızlı dosya değiştirmeyi doğrular. Android API28/API35 CI işi bu testi ayrıca çalıştırır ve kimlik başına log saklar. Çalıştırılmadan kabul verilmez.
- Gezi favorileri ve kullanıcı yer listesi zaten vardı, yeniden kurulmadı. Rota/dil/saha boş ekranlarında sonraki adım açıklandı. Somut veri ve Arapça kayıt teslimi `release-handoff/2026-10-10/DATA_DELIVERY.md` ve `route-field-delivery.csv`; kaynak, sürüm, lisans ve ayrı saha incelemesi gerekir.

## Yerel doğrulama ve sınırlar

Flutter 3.47.6 / Dart 3.13.5; format ve analyze temiz. Tam Flutter **224/224**, Python **57/57**, Node push **13/13**, PGlite pgTAP **115/115**, bağımsız sunucu SQL **45/45** geçti. Koşul testleri hesabın değişmesi, eski sürüm, istemci sahteciliği, doğrudan/RPC yazma, üyelik iptali, güvenlik işlemleri ve silme bekleyen hesabı kapsar. Küçük ekran/%200 yazı, klavye, geri dönüş, ağsız hazırlık ve rehber widget regresyonları korunur. Test SQLite için sistemdeki gerçek libsqlite3.so.0 geçici geliştirme bağlantısıyla kullanıldı; assertion kaldırılmadı. Flutter ortam sorguları standart `CI=true` ile metadata servisine gitmeden çalıştırıldı.

54 dosya SHA-256, metin kimliği/sürümü ve tam AAC decode kontrolünden geçti. Arapça `A-P-U02.2-AR-01`, `P-U02.2-01-draft-2026-10-09-v1` metnine bağlı kayıt **eksik**. Bu teknik dosya kontrolü telaffuz, dinî doğruluk veya hak kararı değildir. Güncel gezi **2.928 POI / 0 rota**, güvenlik **6 sourceVerified iletişim / 0 dil kartı / 0 saha bilgisi**. Katalogdan kayıt silinmedi; gerçek uzman/hak belgesi bulunmadığı için evidence/approved üretilmedi.

Full preflight **blocked/158**, içerik **blocked/145**, MVP **blocked/546**. Bunlar yazılım hata sayıları değildir; aynı gerçek eksikler ve dış kabul kapıları korunur.

### Harita ölçümü

Gerçek Mekke/Medine paketleri, Linux host Flutter VM, süreç RSS; native ilk kare, mobil heap veya peak ölçümü değildir. İlk eski yol: Mekke decode 424,5 + style 575,7 ms, RSS 141,3→385,7 MB; Medine 279,7 + 350,6 ms. Yeni hedefli koşu: Mekke toplam 410,4 ms, RSS 135,9→222,8 MB; Medine 288,5 ms, RSS 222,8→209,2 MB. Tam test turunda Mekke 462,5 ms / 228,5 MB son RSS, Medine 347,6 ms / 210,2 MB; zaman ve süreç belleği koşuya bağlıdır. Büyük JSON'un worker içinde kalması ölçülen maliyeti düşürdü; fiziksel cihaz performansı kabul edilmedi. Tekrar: `flutter test test/map_performance_test.dart`.

### Çalıştırılmayan kabul

Bu Linux ortamında Xcode, fiziksel cihaz ve çalışan emulator yok. Yeni Maestro 03/07/08/09 ve bütün paketli ses integration testi yerelde cihazda çalıştırılmadı; statik kontrol/analyze cihaz sonucu sayılmaz. Yeni Android derlemesinin son sonucu aşağıdaki depo teslim kaydına işlenir. Gerçek PostgreSQL paralel yarış testleri, iOS yeni kod derlemesi/UI, gerçek arka plan/çağrı/Bluetooth kesintisi, uçak modu native harita ilk kare/bellek, TalkBack/VoiceOver ve gerçek iki hesap/iki kafile kabulü bu turda yerelde çalıştırılmadı. Önceki CI veya fake backend bunların yerine geçmez.

## Kalan kesin teslim

Teknik: yeni CI'nın gerçek PostgreSQL ve mobil derleme/UI/bütün paketli ses loglarını kontrol et; assertion hatasını düzelt. iOS'ta bütün anlatım native testi ve gerçek cihaz kesintisi/erişilebilirlik/performans kabulünü tamamla. Canlı migrasyon ve işletim uçtan uca testi yetkili test projesinde yapılmalı.

Dış girdiler: sürümlü gerçek koşul metni/HTTPS URL/hash/yürürlük ve saklama kararı; yalnız test hesaplarıyla yetkili Supabase/Firebase/APNs projesi ve moderasyon/silme sorumlusu; 324 uzman/dil/profil/hak/dinleme karar satırının gerçek belgeleri; bağlı Arapça AAC kayıt ve izin; gerçek rota/dil/saha kaynak-lisans-inceleme teslimi; son fiziksel Android/iPhone ve güvenli dağıtım imzaları/mağaza hesabı. Özel belge/service-role anahtarı Git'e veya mobil uygulamaya eklenmez. Devir listesinin ayrıntısı `release-handoff/2026-10-10/README.md`.

## Depo teslim kaydı

Yerel Android debug denemesi gerçek derleyiciye kadar başlatıldı; Gradle dağıtımı ve JDK21/SDK36/NDK/CMake hazırlandı. Son derleme Gradle Kotlin DSL 6.4.2 plugin artifact'ını uzak depodan çözemediği için başarısız; yeni APK üretildi veya geçti denmez. Eski a628064 APK sonucu bu kodun derleme sonucu değildir. Linux'ta iOS derlemesi çalıştırılmadı. Yeni native regresyonlar CI'ya teslim edilir; kesin son durum commit/PR açıklamasında ayrıca kaydedilir.
