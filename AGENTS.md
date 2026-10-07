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

**Son doğrulama:** 7 Ekim 2026, MVP 1 teknik pilot; GitHub Android APK ve iOS debug/no-codesign build başarılı, fiziksel cihaz kabulü bekliyor

**Aktif paket:** MVP 1 teknik pilot ve P5 canlı kabul; P2–P4 dış girdileri bekliyor

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
- SQLite şema sürümü `8`. Gezi favorileri, mesaj outbox ve konum paylaşım rızası dinî ilerlemeden ayrı.

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

- Umre hazırlığı ve yolculuk için doğrudan girişler eklendi; mevcut Umre/Hac seçim akışları, kafile/gezi/güvenlik/paket/ayarlar ve teknik deneme korunur.
- Adım ekranında açıklama, ses ve manuel sayaç öne alınır; dua, kaynak, ayrıntı, önceki/sonraki ve kişisel işaretleme korunur. İçerik onayı veya veri şeması değişmez.
- Bu UI değişikliğinin CI, küçük ekran/büyük yazı ve APK kabulü henüz bekliyor. Ayrıntı: `docs/07-ozellikleri-koruyan-ux.md`.

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
- APNs/FCM, server push, GPS izin akışı ve arka plan konum takibi yok.
- Gerçek Android/iPhone cihaz testi ve imzalı iOS dağıtımı yok; GitHub iOS debug/no-codesign build geçti.

## 3. Sıradaki tek iş

### P5 canlı kabul ve gerçek içerik girdilerini doğrula

Mobil adaptör, OTP ekranı, davet/mesaj/program akışları ve kullanıcıya bağlı outbox kodlandı. P5 canlı credential ve gerçek Supabase RLS/Realtime kabulü olmadığı için tamamlandı sayılmaz. Önce `docs/06-mvp1-pilot.md` içindeki kalan girdileri ve test sınırlarını okuyun. Yeni dış girdi olmadan taslakları onaylı içerik haline getirmeyin.

Yeni bağımlılıklarla Android/iOS derlemesini ve iki gerçek test hesabıyla OTP, davet, üyelik iptali, özel mesaj ve Realtime davranışını doğrulayın. Önceki APK/emülatör kanıtını yeni build kanıtı saymayın. Uzun kesinti sonrası mesaj geçmişi sayfalama, şirket rota oluşturma/indirme, etkileşimli harita, push ve gerçek GPS gönderimi ayrı açık işlerdir.

## 4. Birleşik yol haritası

| Paket | Kapsam | Durum | Tamamlanma ölçütü |
| --- | --- | --- | --- |
| P0 | Kod, veri, araç ve kapsam incelemesi | Tamamlandı | Gap listesi, bağımlılıklar ve kişi-gün tahmini `docs/04` içinde. |
| P1 | Umre/Hac veri akışı ve üç sayaç | Teknik temel tamamlandı; veri bekliyor | 18/35 onaylı içerik ve Hac matrisi gelmeden ürün kabulü verilmez. |
| P2 | Ses ve çevrimdışı paketler | Teknik katman hazır; sağlayıcı/cihaz bekliyor | Gerçek güvenilir paket, arka plan/kesinti ve iki platform cihaz kanıtı. |
| P3 | Harita, POI ve rotalar | Adaptör ve modeller hazır; sağlayıcı bekliyor | İzinli bölgede gerçek uçak modu harita, durak, arama ve yeniden açma. |
| P4 | Güvenli gezi, dil, saha, adım | Veri modelleri hazır; içerik/sensör bekliyor | Kaynaklı yerel içerik, insan incelemesi ve cihaz sensör kanıtı. |
| P5 | Grup backend'i ve senkronizasyon | SQL/outbox taslağı; servis bekliyor | İki hesap ve iki grup ile RLS izolasyonu, Auth/Realtime ve offline senkronizasyon. |
| P6 | Konum ve push | Yerel rıza modeli; servis bekliyor | Rıza/iptal/son konum, saklama ve gerçek APNs/FCM teslim sınırları. |
| P7 | Bütünleşik mobil test ve yayın hazırlığı | Sırada | Gerçek cihaz matrisi, erişilebilirlik, güvenlik, mağaza ve final durum matrisi. |

3D bu planın kapsamı değildir. Bir paketi yalnız kabul ölçütü kanıtlandığında tamamlandı yaz.

## 5. Teknoloji ve çalışma ortamı

- **İstemci:** Flutter 3.47.6, Dart 3.13.5, Material.
- **Yerel veri:** `sqflite`, şema sürümü 8.
- **İçerik:** `assets/content/` altında sürümlü JSON, içerik şeması 1.
- **Ses:** `just_audio`, `audio_session`, `just_audio_background`/`audio_service`; tek konuşma kanalı.
- **Paket:** SHA-256, sabit güven özeti, geçici indirme ve atomik durum işaretçisi.
- **Harita:** `maplibre_gl`; sağlayıcı verisi yapılandırılmadı.
- **Backend adayı:** Supabase Auth/PostgreSQL/Realtime/Storage; supabase_flutter 2.18.0 ve mobil adaptör eklendi, canlı credential/kabul yok.
- **Test:** `flutter_test`, `sqflite_common_ffi`; backend için 35 pgTAP kontrolü bağımsız PostgreSQL motorunda geçti; gerçek Supabase testi bekliyor.
- **Android:** En düşük API 28; SDK/build-tools 36; Android 35 emülatör kanıtı.
- **iOS:** Proje dosyaları var; tam Xcode ve CocoaPods gerekiyor.

Paket yükseltmesini ayrı ve test edilen değişiklik olarak yap. Özellik değişikliği sırasında ilgisiz toplu paket yükseltmesi yapma.

## 6. Kod ve veri haritası

- `lib/main.dart`: başlangıç, bağımlılık kurulumu ve kapalı varsayılan kataloglar.
- `lib/selection_screens.dart`: ana sayfa ve seçim akışları.
- `lib/guide_catalog.dart`, `lib/guide_screens.dart`: rehber modelleri, onay filtresi, liste/ayrıntı/dua.
- `lib/progress_store.dart`: SQLite şeması, ilerleme, sayaç, favori, outbox ve konum rızası.
- `lib/counter_screen.dart`: tavaf, sa‘y ve cemarat sayaçları.
- `lib/narration_service.dart`, `lib/audio_controls.dart`: tek ses, medya oturumu ve kontroller.
- `lib/offline_package.dart`, `lib/package_downloader.dart`, `lib/package_screen.dart`: çevrimdışı paket yaşam döngüsü.
- `lib/offline_map_adapter.dart`: MapLibre offline bölge sınırı.
- `lib/travel_catalog.dart`, `lib/travel_screen.dart`: POI/rota ve gezi ekranı.
- `lib/safety_catalog.dart`, `lib/safety_screen.dart`: iletişim, dil ve güncel saha bilgisi.
- `lib/group_sync.dart`: mesaj outbox ve konum güncellik modelleri.
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

iOS yalnız tam Xcode ve CocoaPods hazır olduğunda:

```sh
$FLUTTER --no-version-check build ios --debug --no-codesign
```

Backend testi isteğe bağlı yerel Supabase çalışma ortamı veya ayrı test projesi ister. Çalıştırılmadıysa geçti yazma. Derleme, emülatör ve gerçek cihaz sonuçlarını ayrı raporla.

## 9. Tamamlanma ve devir kuralı

Bir parça ancak çalışan kod, anlamlı test, temiz analiz ve ilgili platform kanıtıyla tamamlanır. Gerçek içerik, uzman onayı, hak, sağlayıcı, credential, push veya cihaz iddiası yalnız kanıt kadar yazılır. Durum değiştiyse bu dosyayı ve ilgili `docs/` belgesini güncelle. Derleme çıktısı, `.dart_tool/`, credential, imza anahtarı veya kişisel hesap verisi commitlenmez. Zorla push yapma ve kullanıcı değişikliklerini silme.
