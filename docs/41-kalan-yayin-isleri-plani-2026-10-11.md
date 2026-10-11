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
- Yerel doğrulama: Dart biçim kontrolü (92 dosya, 0 değişiklik), Flutter analiz
  (0 sorun), 238 Flutter testi ve 86 Python testi başarılı. Android debug APK
  yeni bağımlılıklarla derlendi (SHA-256 `583d0cd232e01691f420d48fec855ceaaa5fbe6577065fa8b7eb85b3eff45a1b`).
  Gradle çözümlemesinde DataStore core Android `1.2.1`, MapLibre OpenGL `13.5.3`
  seçildi. Debug APK'daki dokuz native kitaplığın LOAD/ZIP denetimi geçti;
  `libdartjni.so` arm64 RELRO kalanı 12.288, `libflutter.so` arm64 4.096 ve
  x86_64 12.288 bayt. Bu teknik/debug imzalı paket 16 KB runtime veya
  mağaza kabulü değildir.

**Sonraki kanıt:** yeni commit'in CI işlerini, API28/35/36 ve iki iOS simulator
artifact'ini, gerçek PostgreSQL yarış sonuçlarını, AAB türevi `.so` raporunu
ve JUnit/session/kurulu APK hash'lerini incele. Bulgu varsa düzelt ve tekrar
çalıştır; cihaz veya dış onay yoksa yayın kapılarını açık bırak.
