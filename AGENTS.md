# AGENTS.md

Bu dosya depoda çalışan insan ve AI geliştiriciler için ana çalışma talimatıdır. Kök dizinin tamamına uygulanır. Güncel kanıt, teknik sınırlar ve sıradaki tek iş burada tutulur.

## 1. Her çalışmanın başlama sırası

1. `git status --short --branch` çalıştır; kullanıcı değişikliklerini koru.
2. Bu dosyadaki **Mevcut durum** ve **Sıradaki tek iş** bölümlerini oku.
3. Değişecek kodu, testleri ve ilgili `docs/` belgesini incele.
4. Tamamlanmış teknik parçaları yeniden kurma. Sıradaki işi küçük, çalışan ve test edilen bir dilim halinde uygula.
5. Kod değiştiyse biçimlendirme, `flutter analyze` ve `flutter test` çalıştır. Yerel eklenti değiştiyse uygun platform derlemesini de çalıştır.
6. Durum gerçekten değiştiyse bu dosyadaki kanıtı, yol haritasını ve sıradaki işi aynı değişiklikte güncelle.

Yalnız plan bırakma. Erişilebilen bağımsız işi tamamla. Dinî içerik, uzman onayı, kullanım hakkı, saha verisi, credential veya cihaz erişimi eksikse bunları uydurma; bağımlı parçayı açıkça beklet.

## 2. Mevcut durum

**9 Ekim yayın hazırlığı dilimi:** `fe32ebb` uzak hedeften temiz fast-forward ile başlanıp kod/varlık commit'i `f9d8d3f` normal push edildi; PR #1 açık. Özgün Android/iOS ikonları, uygulama içi font/paket lisans ve kaynak ekranı, 30 yerel varlık/144 kilitli Dart paketi lisans dosyası envanteri, 55 taslak kayıt brifi ve 155 preflight engelinin somut gruplanması eklendi. Flutter format/analiz temiz; yerel 181 Flutter, 31 Python, 45 bağımsız sunucu SQL ve 13 Node kontrolü geçti. Android debug APK ve yalnız teknik/debug imzalı optimize AAB; iOS simülatör `.app` derlendi. Yeni iPhone 17 Pro/iOS 26.5 simülatöründe ilk beşli koşudaki scroll yönü hatası teşhis/düzeltme sonrası 5/5, lisans akışı ayrıca 1/1 geçti. Android API35 ARM64 emülatör/profil açılış-bellek ölçümleri sanal cihazla sınırlı kaydedildi. Son kod [CI 37912016969](https://github.com/NeoTuck/kabe_hac/actions/runs/37912016969) attempt 1 completed/success: yedi iş başarılı; Android API28/API35 ve iPhone16/iOS18.5 simülatörde altı uygulama akışı + ayrı teknik ses vakası JUnit/session, driver ve kurulu build hash kanıtıyla geçti. PR test merge ağacı kod commit'iyle aynı. İçerik 18/35 taslak, gerçek ses/harita/servis/imza ve fiziksel cihaz onayı yoktur. Ayrıntı `docs/21-yayin-hazirligi-dilimi.md`, mağaza teknik taslağı `docs/22-magaza-metinleri-ve-gorsel-taslak.md`.

**9 Ekim sunucu dilimi:** Uzak `10963fe` fetch ile doğrulandı; eski dirty worktree ve yerel commit'leri koruyan ayrı çalışma dalı kullanıldı. Yetkili sunucu push outbox/lease/FCM göndericisi, test hesap+cihaz allowlist'i, konum retention override/iptal kilitleri ve planlı sınırlı cleanup tamamlandı. Son kod `a4dee8d35f0b764373da3bdc4d313babc031cf67`, CI `37899499075` attempt 2 completed/success (7 iş) sonucu `docs/20-sunucu-bildirim-ve-konum-isleri.md` ve yeni sunucu kabul manifestinde izlenir. Yerel 39 pgTAP + 45 sunucu SQL + 13 Node + 30 Python, Deno check geçti. Gerçek PostgreSQL 16 yarış testleri CI'da 7/7 geçti. API28/API35 debug ve iPhone16/iOS18.5 simülatörde beş uygulama + ayrı ses vakası geçti; üç native arşiv bağımsız açıldı. iOS ilk hazırlık timeout'u yalnız bir ortam tekrarıyla geçti; assertion kaldırılmadı. İstemci/53 taslak içerik/ilerleme/favoriler korunur. Canlı servis ve fiziksel cihaz erişimi yok; schedule/deploy/migrasyon üretime uygulanmadı. Saklama süresi ürün kararı bekliyor; mevcut pilot +1 gün üretim politikası değildir.

**9 Ekim ilk kullanıcı kabul turu — son teknik doğrulama:** Kod `2fbaaf5e091858fae36b4c810b930d6a51c130ca`, PR test ağacı `4139051b604f4df6a46712f12a5813bb06bbdf14`, [CI 37856131455](https://github.com/NeoTuck/kabe_hac/actions/runs/37856131455) attempt 3 completed/success; yedi iş başarılı. 180 Flutter, 23 Python, 39 bağımsız SQL fixture; format/analiz temiz. Android API28/API35 ve iOS18.5/iPhone16 simulator'de beş uygulama akışı + ayrı native ses vakası passed. İlk NDK bozuk arşiv ve API35 test-öncesi ADB blocked durumları yalnız ortam işi olarak tekrarlandı; başarısız UI assertion yeniden denenmedi. iOS prova başlığı birleşik erişilebilirlik etiketine uyan selector ile doğrulandı. Açılış yerel ilk kare/çevrimdışı rehberden sonra online servis kurar; medya ilk ses isteğinde bir kez başlar. Native playback UI eşleme, push aç/kapat ve konum iptal regresyonları eklendi. QA fixture'ı kullanıcı APK'sından ayrı. ARM64 optimize teknik pilot 36,262,857 bayt (~36.3 MB); debug imzalıdır. `release_preflight`: blocked/155; 53 adım taslak, onaylı insan sesi ve gerçek saha/servis/cihaz/imza kabulü yok. Tam son kullanıcı yayınına hazır değildir. Ayrıntı `docs/19-ilk-kullanici-kabul-incelemesi.md`, kapsam/manifest `docs/qa/2026-10-09-kabul-ozeti.json`.

**9 Ekim güncel kod dilimi:** Başlangıç yerel/uzak HEAD `0853ad123ab0756a108220088c7274192e88b54a`; ilk kod commit'i `15df0b6` hedef dala normal push edildi. 53 sabit kimlikli Umre/Hac adımına kaynaklı özgün Türkçe **taslak** açıklama, uzman çalışma CSV'si, offline manifest aracı ve yerel paket regresyonu eklendi. İlmihal bölüm/sayfa konumları adım bazında düzeltildi; kaynaklı telbiye Arapçası/okunuşu/anlamı **taslak** kaydedildi ve onay gelmeden kullanıcı ekranında gizli kaldı. Kafilede açık rızalı tek GPS ölçümü/15 dakika paylaşım ve yöneticiye son 5 dakikalık “son bilinen” görüntüsü; izinli FCM cihaz token kaydı/yenileme/çıkış/yönlendirme kodu eklendi. Son format/analiz temiz, 174 Flutter/19 Python/39 bağımsız SQL fixture kontrolü ve yerel Android debug derlemesi geçti. İlk CI'da Android API 28 dört akış geçti; API 35 SDK imajı bozuk indirilince cihaz çalışmadı. Yerel iOS derlemesi `objective_c`/Xcode seçim ortamında durdu. Canlı Supabase/Firebase, gerçek cihaz, uzman, hak veya mağaza kabulü değildir. Ayrıntı `docs/17-icerik-veri-ve-paket-arastirmasi.md` ve `docs/18-09-ekim-gelistirme-dogrulama.md`.

**8 Ekim kullanıcı ekranı temizliği:** Teknik örnek kartı ve `DEMO-001` ana ekran girişi kaldırıldı. Sentetik `teknik_demo.m4a` QA dosyası repoda kalır, ancak `pubspec.yaml` varlığından çıkarıldığı için yeni APK'ye paketlenmez. `isTestData=true` gezi yeri/rotası kullanıcı listesinde ve doğrudan ayrıntıda gösterilmez; kayıtlı favoriler silinmez. Ses düğmesinin duraklatma/bitirme etiketleri düzeltildi. Yerel format/analiz, 161 Flutter, 15 Python, ses dosyası QA ve Android debug build geçti; API35 emülatöründe dört güncel pilot akış JUnit 4/4 geçti. APK SHA-256 `adf6d619f8a29e1c31eef4b1d82d04b9a15daef91c4357aeb2428dc08846b118`. Ayrıntı `docs/15-son-kullanici-ve-simulasyon-hazirligi.md` başındadır. Üretim içerik, insan sesi, lisans ve mağaza kabulü hâlâ bekliyor.

**8 Ekim isteğe bağlı prova dilimi:** `f59c8ef9` tabanındaki yerel `codex/mvp1-pilot-desktop` dalında ana akışa 3D'siz “Simülasyonu dene” girişi eklendi. Prova oturumu, adım işaretleri ve sayaçları SQLite sürüm 9'da gerçek rehberden ayrıdır. Paket tercihi, duraklatma/devam, katalog sürümü değişince eski kaydı koruyarak yeni prova ve taslak metni gizleme eklendi. Manuel prova sayacı yalnız uzman onaylı adımda ve onaylı `counterTarget` ile açılır; mevcut 53 adım taslak olduğu için kapalıdır. Yerel format/analiz, 159 Flutter, 15 Python, 39 bağımsız SQL fixture, teknik ses QA ve Android debug build geçti. Android API35 emülatörde mevcut dört pilot ve ayrı prova akışı geçti. Xcode/iOS runtime kuruldu ama bu Mac'te iOS derlemeleri başarısız; ayrıntı `docs/15-son-kullanici-ve-simulasyon-hazirligi.md`. Üretim kabulü değildir.

**GitHub kabul durumu:** `bf1a14c34c26b5795cd182fab491f7e163e9fb65` için PR CI [37824311139](https://github.com/NeoTuck/kabe_hac/actions/runs/37824311139): format/analiz/159 Flutter, 15 Python QA, 39 SQL fixture, Android debug/split release, iOS no-codesign/simulator derlemeleri ve Android API28/API35 dört pilot akışı başarılı. iOS UI işi Maestro `--version` 30 sn zaman aşımında `blocked`, `device_tests_run=false`; iOS ekran akışı geçmedi. Çalıştırıcı sürüm sorgusu 120 sn ile sınırlandı, yeni CI kabulü bekleniyor. Fiziksel cihaz/üretim kabulü değildir.

**8 Ekim Mac kod/log incelemesi:** `origin/codex/mvp1-pilot` commit'i `f59c8ef9b609dc11b2c94d9d34bd3cc1042ef514` temiz yerel dala fast-forward ile alındı. Bu Mac'te 153 Flutter ve 14 Python testi, format/analiz, teknik ses QA ve Android debug derlemesi geçti. Sayaç çift sıfırlama regresyonundaki kaçan ikinci dokunuş testi düzeltildi. Android pilot oturumu `blocked` / `device_tests_run=false`; iOS, Xcode lisansı/developer directory/CocoaPods nedeniyle çalıştırılmadı. Kapsam kullanıcı isteğiyle kod/log incelemesine sınırlandı. Ayrıntı `docs/14-mac-inceleme.md`.

**Önceki CI doğrulaması:** 8 Ekim 2026; kod `67335ffb`, CI `37769687931` yedi iş başarılı: 153 Flutter/39 bağımsız fixture SQL/14 QA, format/analiz, teknik AAC ses, Android debug/split release ve iOS no-codesign/simulator. Android API28/API35 ve iOS18.5/iPhone16 simulator'de dört pilot akış geçti. JUnit/session, Android driver_prepared ve APK hash eşleşmesi ile native duraklatma ekranları incelendi. Fiziksel cihaz/canlı servis/dinî içerik/mağaza kabulü değildir.

**Aktif paket:** 9 Ekim kaynak/kod hazırlığı ve native/CI doğrulaması. Gerçek uzman kararı, insan sesi hakkı, lisanslı saha verisi, canlı Supabase/Firebase ve sunucu göndericisinin canlı kabulü, üretim imzası ve fiziksel cihaz kabulü açık. 18/35 içerik kaydı hâlâ taslaktır.

**Depo:** `https://github.com/NeoTuck/kabe_hac`

**Ana dal:** `main`

### Çalışan çekirdek

- Ana sayfa, öğrenme/yolculuk biçimleri, Umre/Hac seçimi, Hac türü, liste ve ayrıntı ekranları çalışıyor.
- Sürümlü yerel kataloglarda 18 Umre ve 35 Hac alt kimliği var.
- SQLite ilerlemesi kullanım biçimi, rehber türü ve Hac profiline göre ayrılıyor. Eski Umre kimlik migrasyonu korunuyor.
- Tavaf ve sa‘y sayaçları ile Hac yolculuğuna bağlı gün/hedef bazlı cemarat sayaçları manuel çalışıyor.
- Ses, kart, GPS, gezi durağı veya sayaç olayı dinî ilerlemeyi otomatik işaretlemiyor.
- Metin/dua/ses şeması kaynak, sürüm, inceleme ve kullanım hakkını ayırıyor. `U02.2` taslak hattı ve dua kartı çalışıyor.
- Hac profil filtrelemesi yalnız uygulanabilirlik verisinin tamamı onaylandığında etkinleşiyor; mevcut Hac akışı önizleme kalıyor.
- SQLite şema sürümü `9`. Gezi favorileri, mesaj outbox, konum paylaşım rızası ve prova kayıtları dinî ilerlemeden ayrı.

### Geniş ürün için eklenen teknik temel

- `audio_session` kesinti ve kulaklık çıkışında sesi duraklatıyor. `just_audio_background`/`audio_service` Android medya servisi ve iOS audio background yapılandırmasını sağlıyor.
- Çevrimdışı paket manifesti tür, C0/C1/C2, içerik şema aralığı, dosya yolu, hash, boyut ve HTTPS bağlantısı taşıyor.
- Paket indirme; alan kontrolü, sunucu allowlist'i, kesintide destekleniyorsa HTTP Range, tekrar deneme, tam dosya kümesi/hash doğrulaması, atomik etkinleştirme ve geri dönüşü destekliyor.
- Paket kataloğu yalnız derleme zamanı HTTPS URL, sunucu allowlist'i ve sabit manifest özetleri eksiksizse açılıyor. Yapılandırma yoksa paket ağına istek yapılmıyor.
- Güven kökü yapılandırılmadan manifest reddediliyor. C1/C2 güncellemesi açık migrasyon kapısı olmadan etkinleşmiyor.
- MapLibre offline bölge adaptörü, harita sağlayıcı izin kontrolü, POI/rota modelleri, arama/filtre/favori ekranı var.
- Güvenli iletişim, dil ve saha bilgileri için kaynak/güncellik/onay modelleri ve dürüst boş durum ekranı var.
- `supabase/` altında grup backend'i için migrasyon ve pgTAP RLS testi taslağı var. Flutter'da yinelenmeye dayanıklı yerel mesaj outbox bulunuyor.
- Konum paylaşımı yerelde varsayılan kapalı, süreli ve iptal edilebilir. Ölçüm zamanı/gönderim zamanı/güncellik modeli var.

### 7 Ekim inceleme düzeltmeleri

- Yeni migrasyon mesaj güncellemelerini metin/silme zamanına sınırlar; konum okumalarında rıza iptali, süre, saklama ve üyelik kontrol edilir.
- İndirilen `audio` paketindeki tam Umre/Hac katalogları ve yerel sesler rehbere/oynatıcıya bağlandı. Güven/hash/yol/onay kontrolleri korunur; geçersiz/çakışan katalogda gömülü rehbere dönüş vardır. Paket ekranından dönüşte içerik yenilenir.
- Flutter 3.47.6/Dart 3.13.5 Linux ortamında format/analyze temiz; 53 test geçti.
- PGlite 0.5.8 + pgTAP 1.3.2 minimal Auth/Realtime fixture'ında 28 SQL testi geçti; eski migrasyonda yeni testlerin 9'u başarısızdır. Gerçek Supabase Auth/Realtime/HTTP veya `supabase test db` kanıtı değildir.
- Android/iOS derlemesi ve gerçek cihaz bu değişiklik için çalıştırılmadı. Ayrıntı ve paket dosya sözleşmesi: `docs/05-github-inceleme-duzeltmeleri.md`.

### Özellikleri koruyan kullanım düzenlemesi

- Umre hazırlığı ve yolculuk için doğrudan girişler eklendi; Umre/Hac seçim akışları, kafile/gezi/güvenlik/paket/ayarlar korunur. O tarihteki teknik deneme ekranı sonraki kullanıcı ekranı temizliğinde kaldırıldı.
- Adım ekranında açıklama, ses ve manuel sayaç öne alınır; dua, kaynak, ayrıntı, önceki/sonraki ve kişisel işaretleme korunur. İçerik onayı veya veri şeması değişmez.
- `8e87120` commit CI çalışması 37590553180: format/analyze, 87 Flutter testi, ses QA, database ve Android/iOS debug build başarılı. 320/390 piksel ve %100/%200 yazı matrisi geçti; gerçek Flutter ana ekran renderı incelendi. APK 210197775 bayt; SHA-256 `75e8e7c9afc6f966ba2651833ae2e0f0acede6b65a5e73e5dce55f284ee19ca4`. Fiziksel cihaz kabulü bekliyor. Ayrıntı: `docs/07-ozellikleri-koruyan-ux.md`.

### Kafile yenileme ve hesap geçişi incelemesi

- Gönderimden sonra sohbet listesi okunur; Realtime bildirimi olmadan teslim teyitli mesaj görünür. Başarısız gönderim bekleyenler arasında kalır.
- Eski hesap liste/ayrıntı isteğinin hatası yeni hesap verisini veya oturum değişimi uyarısını ezmez. Ekran/hesap değişiminden sonra yeni ayrıntı isteği başlatılmaz.
- Flutter 3.47.6 yerel format/analiz temiz; tüm 91 Flutter testi geçti. Yeni 4 testten 3'ü eski uygulama kodunda başarısızdır. Teknik ses dosyası QA geçti. Güncel kod için CI mobil build, fiziksel cihaz ve gerçek Supabase kabulü ayrı doğrulanır. Ayrıntı: `docs/08-kafile-yenileme-duzeltmeleri.md`.

### Tam sürüm için QA ve içerik hazırlığı

- `6d02270` CI 37669070487 başarılı: Android debug APK, iOS debug/no-codesign, Flutter analiz/test/ses QA ve database. Yerel kanıt 91 Flutter testidir; gerçek cihaz kabulü değildir.
- Dört Maestro pilot akışı ve açık test cihazı seçen çalıştırıcı eklendi. YAML/araç biçim kontrolleri geçti; Android preflight Maestro/adb eksikliğiyle `blocked` döndü. Android ve iOS simülatör dry-run cihaz testi değildir. Fiziksel iPhone bu çalıştırıcının hedefi değildir.
- 18 Umre / 35 Hac envanter satırı denetlendi; tamamı taslak. Kaynak/hak/uzman alanları boş editöryal CSV'lere taşındı. Mevcut editöryal dosyalar dışa aktarımda ezilmez; bunlar uygulama yayın katalogları değildir.
- Yedi aşama ve alan bazlı kabul matrisi `docs/09-tam-surum-gelistirme.md`; cihaz yönergeleri `docs/qa/MOBIL_TEST.md`. Yeni CI qa-foundation işi yalnız statik QA/kimlik denetimidir; mobil cihaz başarısı sayılmaz.

### Kafile mesaj geçmişi

- Son 100 mesajın öncesi 50'şer yüklenir; görünür üst sınır 500 mesajdır. UTC zaman/UUID cursor, tekrar ayıklama, hesap/üyelik ve bekleyen istek kontrolleri eklendi.
- Yenileme açılmış sayfaları tekrar okur; silme/düzenleme günceldir. 8 widget, 3 SDK ve 4 SQL regresyonu eklendi. `2e5f38b` CI 37683617681: format/analiz, 102 Flutter testi, teknik ses QA, Android debug APK, iOS debug/no-codesign, 39 SQL kontrolü ve qa-foundation başarılı. 390×844 Flutter renderı incelendi; 320×568/%200 yazı akışı geçti. Cihaz/canlı servis kanıtı değildir. Ayrıntı: `docs/10-kafile-mesaj-gecmisi.md`.
- Önceki QA temeli CI 37680799787: Flutter, Android debug, iOS debug/no-codesign, database ve qa-foundation başarılı.

### GitHub devir durumu

- 7 Ekim 2026: entegrasyonla dal oluşturma başarılı; önceki 403 erişim engeli giderildi. MVP devir dalı `codex/mvp1-pilot`. CI sonucu ve main birleşmesi ayrı doğrulanmalıdır.

### MVP 1 teknik pilot değişiklikleri

- Ortak tema, navigasyon, Türkçe/Arapça paketli fontlar ve kalıcı açık/koyu tema eklendi. Küçük ekran/büyük yazı taşması düzeltildi; gerçek Flutter UI render'ları `docs/mvp-ui/` içindedir.
- Ses yükleme/iptal yarışları, seek/ileri/geri, süre/konum ve yeniden deneme testleri eklendi. İlk dinlemeye kadar cihaz ses başlatılmaz.
- Supabase mobil repository ve kafile UI; hesap bağlı outbox; atomic grup bootstrap RPC; mock SDK HTTP testleri eklendi. Gerçek proje ve cihaz kabulü bekliyor.
- GitHub Actions ilk çalışması Android SDK action varsayılanındaki bulunamayan `tools` paketi ve SQL işindeki eksik `rg` nedeniyle durdu. SDK paketleri açıkça seçildi, ripgrep kurulumu eklendi. İkinci çalışmada 87 test, SQL ve iOS debug build geçti; Android MapLibre Java 21 istediği için CI JDK 21 olarak düzeltildi. JDK düzeltmesi sonrası `f4b8435` commit çalışmasında Android debug APK, iOS debug/no-codesign, analiz/87 test/ses QA ve database işleri başarılı. APK: 210197211 bayt; SHA-256 `a361a626b1a3855adf16c88b6258c51dad6ce6d1d5a226c8428802a033c4b046`. Run: https://github.com/NeoTuck/kabe_hac/actions/runs/37588125442 . Fiziksel cihaz testi yapılmadı.
- Analiz/format temiz; 87 Flutter testi geçti. Ayrıntı `docs/06-mvp1-pilot.md` içindedir. 35 bağımsız pgTAP testi geçti; yeni Android build denemesi SDK eksikliğiyle durdu. iOS bu Linux ortamında çalıştırılamadı.

### Önceki doğrulama kanıtı (6 Ekim, bu değişiklik için tekrar edilmedi)

- `dart format --output=none --set-exit-if-changed lib test`: temiz.
- `flutter analyze`: hata yok.
- `flutter test`: 45 test başarılı.
- `flutter build apk --debug`: başarılı.
- Debug APK: `227319901` bayt; SHA-256 `5ad14fc9e1dd369df42379cbaaaf9c8f900aacaee044c6cfe05cb1c59e2b3b4a`.
- Android 35 `FaceGuard_Test` emülatöründe uygulama açıldı. Teknik ses medya bildirimi oluşturdu; ekran kapalıyken sistem medya komutuyla duraklatma ve yeniden oynatma durumu doğrulandı.
- Emülatör sessiz çalıştığı için işitsel kalite, çağrı, Bluetooth ve fiziksel kulaklık testi yapılmadı.
- `flutter doctor -v`: Android SDK 36 ve lisanslar hazır. Flutter SDK `PATH` içinde değil; depo komutlarında tam Flutter yolu kullanılabilir.
- iOS doğrulanmadı: tam Xcode/xcodebuild ve CocoaPods yok. Yalnız Command Line Tools var.
- 6 Ekim çalışmasında Supabase SQL/pgTAP testi çalıştırılmadı. Yerel Supabase testi Docker gerektiriyordu; Docker bu uygulamanın çalışma bağımlılığı değildir ve bu çalışmada kullanılmadı.

### Kanıtlanmamış veya eksik üretim girdileri

- Uzman onaylı gerçek dinî metin, Arapça metin, telaffuz veya Hac profil matrisi yok.
- İzinli gerçek insan sesleri yok; `teknik_demo.m4a` yalnız teknik test kaydıdır.
- Güvenilen gerçek paket manifesti, paket sunucusu ve indirilebilir üretim paketi yok.
- Offline dağıtım izni bulunan harita sağlayıcısı/stili/bölgesi yok. Gerçek POI ve rota kataloğu yok.
- Doğrulanmış acil durum/kurum numarası, insan incelemeli Arapça dil kartı veya güncel saha akışı yok.
- Supabase mobil adaptörü ve mock HTTP testleri var; proje URL/publishable key ve gerçek Supabase Auth/Realtime/RLS kabulü yok.
- 9 Ekim diliminden önce APNs/FCM ve GPS izin akışı yoktu. Güncel dilimde foreground GPS ve FCM cihaz kayıt kodu vardır; sunucu push gönderimi, gerçek APNs/FCM teslimi ve arka plan konum takibi yoktur.
- Gerçek Android/iPhone cihaz testi ve imzalı iOS dağıtımı yok; GitHub iOS debug/no-codesign build geçti.

### 8 Ekim kullanıcı kalite turu

- Sabit klavye üstü sohbet editörü; paket/favori/rehber/sayaç işlem korumaları; sıralı ayar yazmaları ve ses hızı hata düzeltmesi eklendi. Özel alıcı kafileden ayrıldığında yeniden seçim gerekir. Davet/yayın işlemleri hesap değişimine karşı korunur.
- HTTP dosya ve katalog indirmeleri zaman/boyut/Range sınırlarına bağlıdır. Geri dönüşte manifest güveni ve aktivasyon yolları doğrulanır; yedek işaretçi listelenir. Kaynak/güncellik ayrıntısı, inceleme bekleyen numaranın gizlenmesi ve konum zaman kontrolleri eklendi.
- Gezi yer/rota ayrıntıları açılır; favori filtresi ve Türkçe arama vardır. Gerçek veri hâlâ sağlanmadı; POI/rota paketini gezi kataloğuna bağlama ayrı eksiktir.
- İlk dilim `123ccbc4` CI `37710748385`: 113 Flutter/39 SQL, analiz, teknik ses QA ve Android/iOS debug build başarılı. Tüm güncel kod `82708e1e` CI `37713783433`: analiz/format, 143 Flutter/39 SQL, teknik ses QA, Android debug APK ve release/split paketler başarılı. Mobil ekran testleri geçti sayılmaz: Android birleşmiş erişilebilirlik etiketi ve iOS SDK/runtime uyumsuzluğu yakalandı. `bd89c83a` düzeltmesi CI `37715121386` ile tekrar kabul bekliyor. Önceki run iki gezi senaryosunda hata yakaladı; favori dokunma ve test kaydırma hedefi düzeltildi. Android API 28/35 ve iPhone simulator UI; release/split boyut raporu yeni CI hattında. Fiziksel cihaz/TestFlight/canlı backend kabulü değildir. Ayrıntı: `docs/11-kullanici-kalite-turu.md`.

## 3. Sıradaki tek iş

**Güncel tek iş:** Gerçek uzman, Arapça uzmanı ve ses hakkı sahiplerinden ilk Umre metni/dua ile metin sürümüne bağlı insan kaydı için tarihli inceleme ve dağıtım iznini al; `docs/content-review/2026-10-09-kayit-metni-calisma.csv` ve `docs/content-review/kayit-ve-hak-talebi.md` hazır teslim dosyalarıdır. Gerçek karar ve dosyalar geldikten sonra ilk onaylı dilimi mevcut katalog/ses paketine bağlayıp format/analiz/test ve Android/iOS simülatör kabulünü tekrarla. Onay gelmeden `approved` veya ses hakkı yazma; canlı servis, harita, saklama politikası ve üretim imzası ayrı dış girdiler olarak açık kalır.

**Önceki sunucu önceliği (dış girdi bekliyor):** Kod CI kabulü kapandı; doğrulanmış gerçek test projesinde iki hesap/iki kafile, yalnız test telefonlarıyla Auth/RLS/Realtime/outbox/FCM/APNs ve GPS kabulü yapılmalı. `PUSH_SEND_MODE` varsayılan disabled; canlı onay yok. Koordinat/rıza saklama politikasını ürün sahibinden alıp server ayarını ve scheduled işleri doğrula. Ayrıntı, rollback ve dış girdi sahipleri `docs/20-sunucu-bildirim-ve-konum-isleri.md`. Aşağıdaki önceki işler tarihsel bağlamdır.

**Önceki içerik önceliği (tarihsel):** Teknik ilk kullanıcı incelemesi kapandı; doğrulanan kod ve kapsam `docs/19` içinde. Gerçek uzman incelemesini ve metin sürümlerine bağlı izinli insan kayıtlarını mevcut onay/güven/paket hattına bağla. Gerçek Supabase/Firebase ve lisanslı saha verisi gelmeden canlı servis/harita kabulü verme. Sunucu push göndericisi, konum saklama/silme otomasyonu, iki hesaplı servis testi ve fiziksel cihaz matrisi ayrı açık işlerdir. Beş native pilot ve ayrı ses vakasını bütün ürün testi sayma. Yeni içerik/servis bağlanınca tam native akışları yeniden kabul et; insan/cihaz/imza/onay alanlarını uydurma.

Doğrulanmış POI/rota paketini geziye bağlama dilimi tamamlandı: güven/hash/tür/yol, bozulma/symlink/çakışma, güncelleme/geri dönüş/silme ve ana ekran yenileme testleri geçti. Bu dilimi yeniden kurma. Son kabul `67335ffb` / CI `37769687931`; ayrıntı `docs/13-yayin-hazirligi.md`.

Sıradaki içerik işi gerçek uzman incelemesinden geçmiş ilk Umre metni, dua ve izinli insan sesini mevcut sürüm/kimlik/hak hattına bağlamaktır. Kaynak kontrollü özgün öneriler `docs/content-review/umre-kaynakli-oneri.md` içinde; uzman onayı değildir. Girdi gelmeden approved, gerçek inceleyen veya ses hakkı uydurma. Katalog yenilenirken kullanıcı ilerlemesi ve favorileri korunur.

Önceki Mac kod/log incelemesi `docs/14-mac-inceleme.md` içinde tarihsel kanıttır; sonraki prova geliştirmesi ve cihaz sonuçları `docs/15-son-kullanici-ve-simulasyon-hazirligi.md` içinde ayrı tutulur.

Canlı servis kabulü için gerçek Supabase proje URL/publishable key ve test hesapları gerekir. RLS/Auth/Realtime, offline outbox ve hesap/üyelik sınırları gerçek ortamda ayrıca denenir. GPS izin/ölçüm/gönderim ile FCM token/yönlendirme kodu 9 Ekim diliminde eklendi; gerçek konum paylaşımı, sunucu push gönderimi ve APNs/FCM teslimi kabul edilmedi. Harita/iletişim/dil verileri gerçek lisans ve insan incelemesi ister.

Teknik pilot APK debug imzalıdır; üretim Android derlemesi gerçek key.properties ister. TestFlight için gerçek Apple dağıtım imzası ve fiziksel cihaz gerekir. `tools/release_preflight.py` mevcut eksik girdilerle blocked döner; bu kontrol bağımsız uzman veya mağaza onayı değildir. Mevcut rehber, sayaç, sohbet/özel mesaj/outbox/duyuru/program/rota ve kaynak/güncellik kontrollerini koru.

## 4. Birleşik yol haritası

| Paket | Kapsam | Durum | Tamamlanma ölçütü |
| --- | --- | --- | --- |
| P0 | Kod, veri, araç ve kapsam incelemesi | Tamamlandı | Gap listesi, bağımlılıklar ve kişi-gün tahmini `docs/04` içinde. |
| P1 | Umre/Hac veri akışı ve üç sayaç | Teknik temel tamamlandı; veri bekliyor | 18/35 onaylı içerik ve Hac matrisi gelmeden ürün kabulü verilmez. |
| P2 | Ses ve çevrimdışı paketler | Teknik katman hazır; sağlayıcı/cihaz bekliyor | Gerçek güvenilir paket, arka plan/kesinti ve iki platform cihaz kanıtı. |
| P3 | Harita, POI ve rotalar | Adaptör ve modeller hazır; sağlayıcı bekliyor | İzinli bölgede gerçek uçak modu harita, durak, arama ve yeniden açma. |
| P4 | Güvenli gezi, dil, saha, adım | Veri modelleri hazır; içerik/sensör bekliyor | Kaynaklı yerel içerik, insan incelemesi ve cihaz sensör kanıtı. |
| P5 | Grup backend'i ve senkronizasyon | SQL/outbox taslağı; servis bekliyor | İki hesap ve iki grup ile RLS izolasyonu, Auth/Realtime ve offline senkronizasyon. |
| P6 | Konum ve push | Foreground GPS/FCM istemci kodu; canlı servis ve cihaz kabulü bekliyor | Rıza/iptal/son konum, saklama/silme otomasyonu ve gerçek APNs/FCM teslim sınırları. |
| P7 | Bütünleşik mobil test ve yayın hazırlığı | Teknik otomasyon genişletildi; gerçek cihaz/yayın bekliyor | Gerçek cihaz matrisi, erişilebilirlik, güvenlik, mağaza ve final durum matrisi. |

3D bu planın kapsamı değildir. Bir paketi yalnız kabul ölçütü kanıtlandığında tamamlandı yaz.

## 5. Teknoloji ve çalışma ortamı

- **İstemci:** Flutter 3.47.6, Dart 3.13.5, Material.
- **Yerel veri:** `sqflite`, şema sürümü 9; sürüm 9 yalnız gerçek rehberden ayrı prova tabloları ekler.
- **İçerik:** `assets/content/` altında sürümlü JSON, içerik şeması 1.
- **Ses:** `just_audio`, `audio_session`, `just_audio_background`/`audio_service`; tek konuşma kanalı.
- **Paket:** SHA-256, sabit güven özeti, geçici indirme ve atomik durum işaretçisi.
- **Harita:** `maplibre_gl`; sağlayıcı verisi yapılandırılmadı.
- **Backend adayı:** Supabase Auth/PostgreSQL/Realtime/Storage; supabase_flutter 2.18.0 ve mobil adaptör eklendi, canlı credential/kabul yok.
- **Test:** `flutter_test`, `sqflite_common_ffi`; backend için 39 pgTAP kontrolü bağımsız PostgreSQL motorunda geçti; gerçek Supabase testi bekliyor.
- **Android:** En düşük API 28; SDK/build-tools 36; Android 35 emülatör kanıtı.
- **iOS:** Minimum 15.0; tam Xcode/iOS SDK gerekir. Mevcut eklenti hattı Swift Package Manager kullanır. Simulator derlemesi ayrı; imzalı fiziksel dağıtım ayrıca gerekir.

Paket yükseltmesini ayrı ve test edilen değişiklik olarak yap. Özellik değişikliği sırasında ilgisiz toplu paket yükseltmesi yapma.

## 6. Kod ve veri haritası

- `lib/main.dart`: başlangıç, bağımlılık kurulumu ve kapalı varsayılan kataloglar.
- `lib/selection_screens.dart`: ana sayfa ve seçim akışları.
- `lib/guide_catalog.dart`, `lib/guide_screens.dart`: rehber modelleri, onay filtresi, liste/ayrıntı/dua.
- `lib/practice_screen.dart`: isteğe bağlı 2D eğitim provası ve gerçek rehberden ayrı akış.
- `lib/progress_store.dart`: SQLite şeması, ilerleme, sayaç, favori, outbox ve konum rızası.
- `lib/counter_screen.dart`: tavaf, sa‘y ve cemarat sayaçları.
- `lib/narration_service.dart`, `lib/audio_controls.dart`: tek ses, medya oturumu ve kontroller.
- `lib/offline_package.dart`, `lib/package_downloader.dart`, `lib/package_screen.dart`: çevrimdışı paket yaşam döngüsü.
- `lib/offline_map_adapter.dart`: MapLibre offline bölge sınırı.
- `lib/travel_catalog.dart`, `lib/travel_screen.dart`: POI/rota ve gezi ekranı.
- `lib/safety_catalog.dart`, `lib/safety_screen.dart`: iletişim, dil ve güncel saha bilgisi.
- `lib/group_sync.dart`: mesaj outbox ve konum güncellik modelleri.
- `lib/location_share_service.dart`, `lib/push_service.dart`: tek seferlik GPS paylaşımı ve opt-in cihaz token akışı; gerçek servis/cihaz kabulü ayrı.
- `assets/content/umre_inventory.v1.json`, `hac_inventory.v1.json`: 18/35 envanter.
- `supabase/migrations/`: backend şeması ve RLS.
- `supabase/tests/database/`: pgTAP erişim izolasyonu taslağı.
- `docs/03-icerik-ve-mobil-dogrulama.md`: ilk içerik hattı ve önceki cihaz kanıtı.
- `docs/04-birlesik-gelistirme-programi.md`: geniş kapsam, kararlar, izinler ve tahmin.

## 7. Değişmez ürün ve güvenlik kuralları

- Dinî metin, Arapça, anlam, telaffuz, inceleyen kişi veya onay tarihi uydurma.
- Kaynak bulunmasını uzman onayı sayma. Kaynak kullanım koşulu ile ses kullanım hakkını ayır.
- Taslak/bekleyen içeriği onaylı yayın içeriği gibi gösterme.
- Onaylı sesin metin kimliği ve sürümü birebir eşleşmeli. Arapça, Türkçe anlatım ve anlam sesleri ayrı kimlikte olmalı.
- Aynı anda tek ses çalsın. Ekran/adım değişince önceki ses dursun. Ses olayı ilerlemeyi değiştirmesin.
- GPS, rota durağı, adım sensörü veya sayaç ibadet geçerliliği üretmesin.
- İçerik sürümü değişince eski ilerlemeyi silme veya sessizce başka adıma taşıma.
- Kamusal OSM raster/vector tile sunucularından offline şehir paketi indirme. Sağlayıcı izni ve atıf zorunlu.
- Test POI, rota, numara ve saha verisini gerçek veri gibi sunma.
- Konum paylaşımı varsayılan kapalı, açık rızalı, süreli ve durdurulabilir olmalı. Eski konumu canlı gösterme.
- Realtime bağlantısını push bildirimi sayma. Çevrimdışı mesajı teslim edilmiş gösterme.
- Service-role anahtarını veya başka gizli bilgiyi mobil uygulamaya, Git'e ya da dokümana koyma.
- Grup yetkisini yalnız UI ile gizleme; sunucuda RLS/policy ile uygula.
- Docker'ı mobil uygulama çalışma bağımlılığı yapma. Yalnız isteğe bağlı yerel backend test aracı olabilir.

## 8. Doğrulama komutları

Flutter bu makinede `PATH` içinde değil. Gerekirse `FLUTTER=/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/flutter` kullan.

```sh
$FLUTTER --no-version-check pub get
$FLUTTER --no-version-check analyze
$FLUTTER --no-version-check test
$FLUTTER --no-version-check build apk --debug
```

Biçim kontrolü:

```sh
/Users/mustafasenoglu/.local/share/flutter-3.47.6/bin/dart format --output=none --set-exit-if-changed lib test
```

Mevcut iOS projesi FlutterGeneratedPluginSwiftPackage / Swift Package Manager kullanıyor. Tam Xcode, Flutter ve gerekli iOS SDK/simülatör çalışma ortamı hazır olduğunda:

```sh
$FLUTTER --no-version-check build ios --debug --no-codesign
```

Backend testi isteğe bağlı yerel Supabase çalışma ortamı veya ayrı test projesi ister. Çalıştırılmadıysa geçti yazma. Derleme, emülatör ve gerçek cihaz sonuçlarını ayrı raporla.

## 9. Tamamlanma ve devir kuralı

Bir parça ancak çalışan kod, anlamlı test, temiz analiz ve ilgili platform kanıtıyla tamamlanır. Gerçek içerik, uzman onayı, hak, sağlayıcı, credential, push veya cihaz iddiası yalnız kanıt kadar yazılır. Durum değiştiyse bu dosyayı ve ilgili `docs/` belgesini güncelle. Derleme çıktısı, `.dart_tool/`, credential, imza anahtarı veya kişisel hesap verisi commitlenmez. Zorla push yapma ve kullanıcı değişikliklerini silme.
