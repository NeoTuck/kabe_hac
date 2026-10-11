# Kalan yayın işleri: uygulama ve kabul planı — 11 Ekim 2026

Başlangıç: `b54f37a`, PR #1 taslak. Son CI `38132103096` 7/9 işte başarılıdır.
Bu plan güçlü MVP kapsamını ve mevcut yayın kapılarını korur. Kod tamamlanması,
uzman/hak kararı veya mağaza kabulü yerine geçmez.

## 1. Bu turda yapılacak teknik işler

1. Android API35 paketli ses testinde `A-H08.3-TR-01` sırasında oluşan hatayı
   artifact/JUnit/native log ile ayır. Ses dosyası, oynatıcı ve test zamanlamasından
   hangisinin sorumlu olduğunu gösteren en küçük düzeltmeyi yap. 54 kayıt, duraklatma,
   seek, hız ve devam assertion'larını koru.
2. Android API36/16 KB turunda ölçülen `PAGE_SIZE=16384`, UID0 ve compatibility
   readback kanıtını koru. Prova sırasında kopan emülatör/Maestro bağlantısı için
   cihaz günlüğü topla ve tam UI + 54 ses + teknik probe turunu yeniden çalıştır.
   Başarısız assertion'ı otomatik tekrar veya gevşetme ile geçirme.
3. Gerçek AAB türevi ve her 64-bit `.so` için ZIP, ELF LOAD ve GNU_RELRO bitiş
   hizasını ayrı kaydet. Google'ın 16 KB RELRO koşuluna uymayan kitaplıkları
   raporla; native tur bitmeden `runtime_16kb_tested` veya `store_ready` yazma.
4. Son commit üzerinde Android API28/API35/API36-16 KB, Xcode16.4/iOS18.5,
   Xcode26.2/iOS26.2, gerçek PostgreSQL yarışları, format, analiz ve Flutter
   testlerini doğrula. CI artifact/JUnit/session/hash ile sonucu bu belgeye ekle.

## 2. Gerçek teslim geldiğinde yapılacak kabul

| Teslim | Gerekli kanıt | Sonraki işlem |
| --- | --- | --- |
| Dinî içerik ve Hac profilleri | 53 adım, dua ve Temettü/İfrad/Kıran için sürümlü uzman kararları | İlk onaylı dilimi mevcut katalog kapısından geçir; ilerleme/favorileri koru. |
| Ses | 54 sentetik taslağın hak zinciri ve işitsel/telaffuz kararı; eksik Arapça telbiye kaydı | Kimlik/sürüm/hash/hak eşleştir; native ses turunu tekrarla. |
| Kafile | Yetkili Supabase/Firebase/APNs test projesi, iki hesap ve iki kafile | Auth/RLS/Realtime/outbox/push/rıza/şikâyet/hesap silmeyi cihazda kabul et. |
| İşletim | Dört gerçek HTTPS hizmet adresi, yasak içerik kuralları, moderasyon sorumlusu ve saklama süreleri | Sürümlü politikayı yetkili operatörle yayımla; canlı hizmet kapısını yalnız kabulden sonra aç. |
| Gezi, dil ve saha | Rota lisansı/kaynağı, insan incelemeli Arapça kartlar ve güncel saha kaynağı | Gerçek paket ve uçak modu kabulünü yap. |
| Mağaza | Yayın hesabı, üretim imzaları, veri/yaş/ülke beyanları, son ekran görüntüleri | İmzalı AAB/IPA ve Play türevi APK'ları tekrar denetle; iOS SDK gizlilik kapsamını doğrula. |
| Fiziksel iPhone | Gerçek cihaz ve test sorumlusu | İlk açılış, rehber, ses, sayaç, prova, harita, kapatıp devam; çevrimdışı ve büyük yazı turunu kaydet. |

Kafile filtresi, reddedilen mesaj akışı ve teknik AAB türev denetimi kod boşluğu
olarak kapalıdır. Üretim moderasyon politikası, imza ve gerçek servis kabulü açıktır.
`LIVE_SERVICE_ACCEPTED` kapalı kalır; taslak içerik ve ses onaylı gösterilmez.

## 3. Bu turda uygulananlar ve henüz açık kanıt

- Android API35'te `A-H08.3-TR-01` (47. kayıt) hata verdi. Dosyanın katalog hash'i
  eşleşiyor, AAC bütünüyle çözülebiliyor ve Android API28'de aynı dosya geçti.
  Oynatıcıdaki yutulan native hata, yalnız debug modunda hata türü/stack olarak
  yazılıyor; test süresince eşzamanlı logcat artifact'e alınacak. Kök neden ve
  bu kaydın yeni cihaz kabulü son CI'a bağlıdır.
- API36/16 KB önceki turda `PAGE_SIZE=16384`, UID0 ve compatibility readback'i
  doğruladı, dört UI akışı geçti; prova sırasında emülatör/ADB bağlantısı koptu.
  Optimize paket UI ve debug paket 54 ses/probe, ayrı temiz emülatörlerde
  çalışacak. Her iki işte 16 KB gerçek sayfa ve compatibility kontrolü korunur.
- Kaynak AAR incelemesi: DataStore `1.2.1` ve MapLibre OpenGL `13.5.3`
  arm64/x86_64 için 16 KB ELF LOAD ve sıfır RELRO bitiş kalanı taşıyor.
  Gradle bunlara sabitlendi. Flutter 3.47.7 arm64 motorunda hâlâ 12.288 bayt
  RELRO bitiş kalanı bulundu; uygulamanın son paketinde gerçek sonuç ve runtime
  kabulü olmadan 16 KB uyumu ilan edilmez. AAB türevi rapor, statik RELRO
  bulgusunu ELF LOAD/ZIP sonucundan ayrı gösterecek.
- `jni` eklentisinin CMake'i yalnız maksimum sayfa boyutunu veriyordu. Proje
  Gradle ayarı bu eklentinin native bağlantısına ortak sayfa boyutu 16 KB
  bayrağını da ekliyor; pub cache veya üçüncü taraf kaynak değiştirilmedi.
  Yeni debug APK'da `libdartjni.so` arm64/x86_64 RELRO bitişi hizalandı.
- Yerel doğrulama: Dart biçim kontrolü (92 dosya, 0 değişiklik), Flutter analiz
  (0 sorun), 238 Flutter testi ve 86 Python testi başarılı. Android debug APK
  yeni bağımlılıklarla derlendi.
  Gradle çözümlemesinde DataStore core Android `1.2.1`, MapLibre OpenGL `13.5.3`
  seçildi. Debug APK'daki dokuz native kitaplığın LOAD/ZIP denetimi geçti;
  JNI düzeltmesi sonrası yalnız `libflutter.so` arm64/x86_64 RELRO uyarısı
  kaldı. Optimize split APK'ler de derlendi: arm64 SHA-256
  `cbbdac6c2ecca8a226f8bec65213b735103d3a95d4351879872633df1320a353`,
  x86_64 SHA-256 `5cc4eb1825cf2f5d257deaacf6cff07368e3ce0f35492de6f20ac82b79fe6e2f`.
  Her birinde beş native kitaplık için LOAD/ZIP denetimi temiz; x86_64 RELRO
  bitişleri de temiz. Arm64 `libflutter.so` RELRO kalanı 12.288 bayt.
  Bunlar teknik pilot paketlerdir; 16 KB runtime veya mağaza kabulü değildir.

**Sonraki kanıt:** yeni commit'in CI işlerini, API28/35/36 ve iki iOS simulator
artifact'ini, gerçek PostgreSQL yarış sonuçlarını, AAB türevi `.so` raporunu
ve JUnit/session/kurulu APK hash'lerini incele. Bulgu varsa düzelt ve tekrar
çalıştır; cihaz veya dış onay yoksa yayın kapılarını açık bırak.

## 4. CI `38139991882` tanısı ve sonraki düzeltme

`5c3ce35` için on CI işinin sekizi başarılı, ikisi başarısızdır. Flutter
biçim/analiz/238 test, QA/86 Python, veritabanı (45 sunucu SQL, 13 Node,
gerçek PostgreSQL yarışları), teknik AAB, Xcode16.4/iOS18.5 ve
Xcode26.2/iOS26.2 işleri başarılı tamamlandı. iOS işlerinin artifact kabulü
ayrı incelenir: iş günlüğünde UI/ses/probe aşamaları sıfır çıkışla geçti,
ancak bu turda JUnit/session arşivleri bağımsız indirilemedi ve iOS kurulu
`.app` hash'i üretilmiyor. AAB türevi universal APK'nin ZIP hizası geçti; arm64
`libflutter.so` GNU_RELRO bitiş uyarısı sürer. AAB/Play veya gerçek üretim
imzası kabulü verilmedi.

Android API36/16 KB iki ayrı emülatör işi geçti. Optimize paket için gerçek
`PAGE_SIZE=16384`, UID0 ve uyumluluk özellikleri okundu; 9/9 Maestro ekran
akışı, JUnit/session ve kurulu APK hash'i eşleşti. Ayrı debug pakette 54/54
gerçek paketli ses, duraklatma/seek/hız/devam ve teknik probe 1/1 geçti;
session/kurulu APK hash'i eşleşti. Bu, 16 KB x86_64 emülatör runtime kanıtıdır;
arm64 `libflutter.so` RELRO ve gerçek dağıtım imzasını kapatmaz.

Android API28'de 54/54 ses ve probe geçti, ekran akışı 8/9 kaldı. Harita
ekranında POI çizildi ama yol/bina katmanı hazır işareti gelmedi; cihaz
günlüğünde MapLibre `std::bad_alloc` var. CI emülatör RAM'i 4 GB'tan
2 GB'a düşürülmüştü. API28 ve API35 tam akış cihazları 4 GB'a döndürüldü;
harita assertion'ı korunur.

Android API35'te 9/9 ekran ve probe geçti; 54 ses turunun 45. kaydı
`A-H02.1-TR-01` yüklenirken `PlayerInterruptedException: Connection aborted`
verdi. Eşzamanlı logcat, SystemUI'nin bir önceki medya oturumuna `stop`
gönderdiğini ve yeni ExoPlayer'ın yükleme sırasında kapandığını gösteriyor.
Dosya bozulması olarak değerlendirilmedi. `playAsset`, yalnız bu tam native
bağlantı kesilmesinde, aynı kullanıcı isteği hâlâ güncelse bir kez oynatıcıyı
sıfırlayıp yeniden yükler; ikinci kesinti veya diğer hatalar görünür hata
kalır. Eski istek ve kullanıcının durdurması yeniden oynatma başlatmaz.
Bu davranış için üç yeni yarış/limit testi eklendi; yerel 241 Flutter testi,
biçim ve analiz temiz geçti. Yeni native CI sonucu beklenir.

`b85809d` ilk CI'sında QA işi, emülatör RAM'ini eski 2 GB değeriyle birebir
karşılaştıran test yüzünden düştü. Beklenti 4 GB'a güncellendi; harita testi
ve yeni native ses sonucunu doğrulamak için sonraki CI gereklidir. Kanonik
`/private/tmp` geçici diziniyle yerel 86 Python testi de geçti; macOS'un
`/var` sembolik yolu altında iki dosya sınırı fixture'ı yalancı kırmızı olur.

Gerçek kararlar için hazır teslim kaydı
`docs/release-handoff/2026-10-10/README.md`, karar satırları ve ilk Umre
dilimidir. Bu dosyalar gerçek uzman imzası, ses hakkı, üretim saklama kararı,
canlı proje erişimi, fiziksel cihaz veya mağaza imzası yerine geçmez.

## 5. Sonraki native koşu ve iOS kurulum tanısı

`4acd08a` / CI `38142992091` koşusunda Flutter, QA, veritabanı, teknik AAB,
Android API28/API35 ve iki ayrı API36/16 KB işi başarılıdır. API35 arşivinde
9/9 uygulama akışı, paketli 54 ses ve teknik probe 1/1; optimize 16 KB
x86_64 arşivinde 9/9 UI; ayrı 16 KB debug arşivinde paketli 54 ses ve
probe 1/1 geçti. Bu Android arşivlerinde JUnit başarısızlık sayısı sıfır,
oturum `device_tests_run=true`, sürücü hazır ve kurulu APK hash'i beklenen
hash ile eşleşiyor. Her iki 16 KB cihazı `PAGE_SIZE=16384` ölçtü. API28
arşivinde de 9/9 UI, 54/54 paketli ses ve probe 1/1 geçti; JUnit sıfır hata,
oturum ve kurulu APK hash'i doğrulandı. Emülatör 4 GB RAM ile çalıştı.

Xcode26.2/iOS26.2 işinde no-codesign debug, unsigned release ve simülatör
derlemeleri geçti; native akış başlamadan ilk `simctl install` 120 saniyede
zaman aşımına uğradı. Bu sonuç UI veya ses assertion başarısızlığı değildir,
ancak iOS26 native kabulü de değildir. İlk kurulum sınırı 300 saniyeye
çıkarıldı ve hata türü/süresi artifact'e yazılıyor; assertion'lar ve gerçek
hata için kırmızı çıkış korunuyor. Yeni CI sonucunda yeniden doğrulanmalı.
Xcode16.4/iOS18.5 işi `completed/success` oldu; JUnit/session arşivi ayrı
indiriliyor ve bağımsız kabul için incelenmeli. İş günlüğünde uygulama UI,
paketli anlatım, probe kurulumu ve teknik ses probe aşamalarının her biri
sıfır çıkış koduyla tamamlandı. Son yerel tekrar: 92 Dart dosyasında biçim
değişikliği yok, `flutter analyze` sıfır sorun, 241 Flutter ve 86 Python
testi başarılı. Bu tekrar iOS26 native kurulum sonucunun yerini tutmaz.
Arm64 Flutter `libflutter.so` RELRO uyarısı ve gerçek yayın kapıları açıktır.
