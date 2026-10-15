# Gerçek çevrimdışı veri ve ses üretim hattı — 9 Ekim 2026

Bu dilim Linux çalışma ortamında `fdf7ca41` üzerinden uygulandı. Mac, fiziksel Android veya iPhone kullanıldığı iddia edilmez. 18 Umre / 35 Hac kimliği, ilerleme, favoriler, isteğe bağlı 3D olmayan prova ve dinî onay filtreleri korunur.

## Uygulananlar

- Geofabrik GCC OSM PBF dosyasından Mekke/Medine için 2.928 gerçek adlandırılmış yer kaydı ve yol/bina/su geometrisi çıkarıldı. PBF SHA-256: `37ddf4a1c62bf695297173744a9ff7524ae51cd4c421a75cfa5de110b80166eb`. Kaynak anı `2026-10-08T20:21:06Z`. Yeniden üretim aracı `tools/build_osm_travel.py`; sadece çıkarım sırasında osmium 4.2.0 gerekir.
- Mekke geometri dosyası 1.281.906 bayt / 40.971 şekil; Medine 889.330 bayt / 30.291 şekil. Paketlere kaynak kaydı ve tam ODbL-1.0 lisansı dahil edildi. Türetilmiş veri tabanı `offline_packages/osm-2026-10-08/` altında aynı lisansla yayımlandı. Küçük binalar ve multipolygon ilişkileri dahil değildir; kutsal sınır veya güvenli navigasyon ürünü değildir.
- Tam ODbL lisansı ve türetilmiş veri tabanının erişim adresi uygulamanın Lisanslar ve kaynaklar ekranından açılır.
- Veri dosyaları değişmez `fed9f97861081f67cb5844598667347787f96502` commit'inden indirilir. Üç manifestin güven özeti uygulamada sabittir. Katalog değişse bile başka manifest kabul edilmez. Başlangıçta ağ isteği veya şehir geometrisi açma yoktur; kullanıcı Paketler ekranından seçer.
- Yeni yerel MapLibre ekranı indirilen GeoJSON verisini 2D çizer. Harita stili dış tile, glyph, sprite ve GPS istemez. Kaynak atfı ve tarih görünür; yer araması vardır. Gzip açılmış veri 24 MB ile sınırlıdır; JSON ayrıştırma ve stil kodlama ayrı isolate'tadır. Gerçek gezi listesi binlerce kartı aynı anda oluşturmayan ListView.builder kullanır.
- Resmî MFA/MOH/SPA kaynaklarıyla altı iletişim kaydı eklendi. Kaynak kontrolü insan/dinî inceleme yerine geçmez. Ayrı `sourceVerified` durumu, resmî alan adı, telefon biçimi ve gelecekte olmayan tarih ister; Arapça dil kartını onaylamaz. Arama düğmesi kullanıcı seçimiyle numara çevirme ekranını açar.
- `tools/produce_narration.py` 55 ses kimliğini kaynak metin/sürüm/script SHA-256 ile eşleştirir. Google Cloud TTS ancak onaylı Türkçe metin ve gerçek sağlayıcı hak/hesap girdisiyle çağrılır; mevcut taslaklar için ücretli istek göndermez. Arapça otomatik üretilmez. Mono AAC 64 kbps çıktısı ffmpeg/ffprobe ve gerçek decoder QA ile sınanır. Üretim makbuzu sentetik kökeni ve bekleyen dinleme incelemesini açıkça kaydeder. Ana WAV dosyaları dağıtım kayıtlarından ayrı tutulur.
- Diyanet telbiye adaylarının hash/ölçüm ve izin durumu `docs/qa/source-registry.v1.json` içinde. Kullanım izni olmadığı için uygulamaya ses olarak eklenmedi. Ses üretim anahtarı burada yapılandırılmadı; gerçek kullanıcı ses dosyası üretilmedi.

## Kontroller ve sınırlar

Yerel format ve analiz temiz. Son birleşik Flutter koşusu 189/189 geçti; gerçek iki şehir paketinin kurulması/açılması/bozulmuş dosyanın reddi bu koşudadır. Tam ODbL metninin uygulamada açılması yeni widget testindedir. Üç yayımlanan paketin 11 dosyası uzak HTTPS bağlantılarından indirilip boyut/hash açısından doğrulandı. İlk kod commit b30a469 için CI 37928402985 araç ve database işleri başarılıdır; yeni son düzeltmenin native sonucu CI üzerinden ayrıca takip edilir. Python 42/42, Node 13/13 geçti. Teknik 30 saniye AAC dosyasının integrity/decoder kontrolü başarılı; bu insan anlatımı veya fiziksel cihaz sesi kabulü değildir. Paket ekranı dört regresyon kontrolü geçti. SQL kaynakları değiştirilmedi; önceki SQL sonuçları yeni çalıştırma sayılmaz.

Maestro yedinci akış gerçek Mekke paketinin indirilmesini ve native stilin hazır olmasını ister. Dördüncü akış artık kapalı katalog yerine gerçek katalog bekler. YAML/politika kontrolü yedi dosyada başarılıdır; bu cihaz çalıştırma kanıtı değildir. Android API28/API35 ve macOS iOS simülatör işlerinin bu commit'e ait sonucu GitHub Actions'ta ayrıca kontrol edilmelidir. Yerel Linux ortamında Android SDK ve Xcode bulunmadığı için native derleme çalıştırılmadı.

`release_preflight` hâlâ blocked/155: 53 dinî adım taslak, gerçek ses/inceleme/üretim hakları, Hac profil incelemesi, canlı backend ve bildirim kabulü, gizlilik/saklama kararı ve üretim imzaları tamamlanmadı. Lisanslı OSM kaynağı ve resmî iletişim gerçek girdidir; uçak modu/native render/fiziksel saha kabulünün veya kapsamlı güncel rotanın yerine geçmez. Yayın kanıtları tamamlanmadan engeller silinmez.

## Tekrar üretim

```sh
python3 tools/produce_narration.py --help
python3 tools/build_osm_travel.py --help
python3 -m unittest discover -s tools -p 'test_*.py' -v
flutter analyze
flutter test
python3 tools/verify_mobile_qa.py
python3 tools/release_preflight.py --evidence-dir release-inputs
```

Sıradaki gerçek içerik işi: ilk Umre metni ve telbiye için gerçek uzman kararı, buna bağlı kayıt hakkı/hesap erişimi ve dinlenmiş kayıt dosyasını katalogla eşleştirmek. İnceleyen adı, lisans izni, insan sesi, hesap veya mağaza imzası AI tarafından varsayılmaz.

## Native inceleme sonrası düzeltme

`557a339` / CI `37929037091`: Android debug/optimize ve iOS imzasız/simülatör derlemeleri geçti. API28 kurulu APK hash'i eşleşti, yedi akıştan altısı geçti; gerçek indirme + harita akışı dahil. Dördüncü akışın paket başlığı native ağacında açıklamayla birleştiğinden tam başlık eşleşmesi başarısızdı; gerçek erişilebilirlik metnine uygun regex ve regresyon kontrolü eklendi. API35 ilk launchApp adımında 600 saniye zaman aşımıyla blocked; JUnit/başarılı akış yok, geçirilen test sayılmaz. Başarısız koşuya salt okunur ekran/aktivite/app logcat tanısı eklendi; otomatik UI tekrar yok.

API28 harita ekran görüntüsünde bölge orta noktasının boş araziye denk geldiği görüldü. İlk görünüm gerçek OSM kayıtlarından şehir merkezi çevresine taşındı, yakınlaştırma 14 yapıldı. Her iki ilk görünümde 100'den fazla gerçek geometri bulunduğu test edilir. Harita hazır etiketi yalnız stil olayına değil, native sorguyla gerçekten çizilmiş yol/bina/su nesnesi bulunmasına bağlıdır. Yeni native kabul yeniden çalıştırılmalıdır. Önceki API28 sonucu bu değişen kodun kabulü değildir. Ek yerel 8 ekran kontrolü gerçek 2.928 yer kaydıyla 320/390 piksel, %100/%200 yazı ve açık/koyu temada geçti; Arapça adlar gerçek font fallback ile görsel olarak incelendi.


## c4b9435 native tanısı ve yeni düzeltme

CI 37931892776 tüm derlemeleri, Flutter/QA/veritabanı işlerini geçti; üç native iş başarısızdır. API28 ilk altı akış geçti. Yedinci akış ekran görüntüsünde gerçek yol/bina ve “Harita hazır” gösterirken driver viewHierarchy çağrısı StackOverflowError verdi. Pinned MapLibre 0.27.1 varsayılan Virtual Display yerine Android texture composition seçildi; erişilebilirlik sorguları/assertion korunur, yeni native doğrulama beklenir.

API35 uygulama görünürken sistem “Pixel Launcher isn’t responding” penceresi yedi akışı engelledi. Test imajı API35 default/x86_64 AOSP olarak değiştirildi; API28 google_apis korunur. Bu değişiklik Google Play/FCM teslim kabulü değildir. iOS ilk altı akıştan yalnız prova başarısızdı; gerçek harita indirme/render dahil diğer altı geçti. Prova yeniden açılışında kayıt düğmesi asenkron eklenince erken erişilebilirlik ağacı eskidi. Ana ekran başlığı kayıt yüklenme durumunu semantik olarak belirtir; prova testi kayıt okuması tamamlandıktan sonra kaydırır. Sabit uyku veya assertion kaldırma kullanılmadı. Yeni CI ve ayrı teknik ses vakası sonucu bekleniyor.


## ddc8a8a teknik doğrulama ve mağaza SDK kapsamı

Kod ddc8a8a0c39dc474d7d71896fa0f5c0e319584d1; PR test merge 8c6bcf787f9d671d27f3866ee8923cef9bc68ab9 ile Git tree farkı yoktur. CI 37935382604 içinde Android API28/google_apis ve API35/default AOSP yedi uygulama + ayrı teknik ses vakası 8/8 geçti. İki platformun artifact ZIP'leri bağımsız açılıp JUnit/session/driver_prepared ve kurulu APK hash eşleşmesi doğrulandı. Uygulama debug APK hash'i 98dce3807c3bae78c8a9910221775cac40d971c569456bd4fb26f771437061b0; ayrı teknik ses APK hash'i b47c6a1c5c73c441a294e3eb5f5453590a169ca9a684d0a4ab240d8682f05a94. Bu, duyma/telaffuz veya gerçek telefon kabulü değildir. Yerel 190 Flutter, bu kod için 44 Python geçti. Ek mağaza SDK yapılandırması 45 Python testini geçti. Aynı CI 39 pgTAP, 45 sunucu SQL, 7 gerçek PostgreSQL yarış testi ve 13 Node kontrolünü geçti. iOS18.5/iPhone16 simülatörde de yedi uygulama + ayrı teknik ses vakası passed; üçüncü native artifact ZIP/JUnit/session bağımsız açıldı. Üç platformda 24/24 native vaka geçti. iOS çalıştırıcısı kurulu .app hash sözleşmesini uygulamıyor; Android hash kanıtı iOS için iddia edilmez.

Optimize ARM64 APK 36.615.861 bayt; SHA-256 14a24d84e27793b036d52e2e5e9ecaa2a8e9da5a086002ba8a3116201091ab14. Artifact arşivinin SHA-256 değeri GitHub digest ile aynı; paket teknik demo sesini içermiyor. Debug anahtarıyla imzalı teknik pilot; mağaza paketi veya cihaz hız ölçümü değildir.

Apple güncel yükleme şartı 28 Nisan 2026'dan beri Xcode26+/iOS26+SDK: https://developer.apple.com/news/upcoming-requirements/ . macos-15 varsayılan Xcode16.4 / SDK18.5 testi bu şartı karşılamaz. Resmî runner envanterinde bulunan Xcode26.2 ile ek CI matrisi hazırlanmıştır; 16.4 uyumluluk matrisi korunur, minimum kullanıcı iOS15 değişmez. Seçilen toolchain/SDK loglanır, artifact adları sürümle ayrılır. Xcode26.2 matrisi imzasız release derlemesini de çalıştırır. İki SDK için yeni CI sonucu ayrıca beklenir. İmzasız build üretim imzası veya App Store kabulü değildir.
