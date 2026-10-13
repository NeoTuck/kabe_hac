# Tam paket uygulaması — 13 Ekim 2026

Başlangıç uzak commit: `a730baf9b3675e333d1f02787052eba99c72c0e2`.
Hedef dal: `codex/mvp1-pilot`; PR #1 taslak. Mevcut kullanıcı verisi,
53 sabit adım kimliği, ayrı Hac profilleri ve prova kayıtları korunur.

## Bu dilimde uygulanan düzeltmeler

- Hac'ın mevcut özet ve ayrıntısı taslak etiketiyle yeniden gösterilir.
  Üç profilin uygulanabilirlik/akış uyarısı korunur; uzman onaysız profil
  kişisel tamamlanma işareti veya onaylı plan açmaz.
- Umre ve Hac adımlarının mevcut kaynak adı, konumu, bağlantısı, erişim tarihi
  ve metin sürümü görüntülenir. Kaynak bilgisi uzman onayı yerine geçmez.
  Dua/Arapça ve onaylı ses kuralları değiştirilmez.
- Açık haritada paket yönetiminden dönüş haritaları ve yer kataloğunu yeniden
  okur. Silinen yerler eski overlay'e taşınmaz; seçili şehir varsa korunur.
  Okuma başarısızsa yeniden deneme güncel kataloğu tekrar ister.
- Paket listesinden açılan harita ve gezi ekranları da paket yönetimine erişir.
  Bağımsız gezi ekranı kendi kataloğunu yeniler; paket hatası favori hatasından
  ayrı gösterilir. Paket yönetiminde yinelenen dokunuşlar engellenir.
- Hac Maestro beklentisi yeni taslak başlığıyla eşlenir; profil sınırı
  assertion'ı korunur. Native tur bu dilimde çalıştırılmaz.

## Tam ürün için sıralı kabul planı

| İş | Mevcut durum | Sıradaki somut teslim | Tamamlanma kanıtı |
| --- | --- | --- | --- |
| Rehber ve ilk kullanım | Kod ve 18/35 taslak metin mevcut; bu dilimde görünürlük düzeltildi | Sürümlü metin ve üç Hac profil matrisi için gerçek kararlar | Gerçek uzman/dil incelemesi ve son katalog bağına ait kabul |
| Ses | 54 sentetik taslak dosya var; Arapça telbiye dosyası yok | Dinleme/metin eşleşmesi, model/çıktı dağıtım hakkı, ayrı izinli telbiye | Her kaydın metin sürümü, dosya özeti, hak ve inceleme kararı |
| Çevrimdışı paket ve harita | Güven, hash, alan, indirme, iptal, geri dönüş ve yer arama kodu var | Yer/saha/dil verisinin insan incelemesi ve son paketlerle uçak modu turu | Harita açılışı, arama, favoriler, güncelleme/silme ve tekrar açılış |
| Kafile | Auth/RLS/outbox/moderasyon/konum/push teknik hattı mevcut; canlı kabul kapalı | Yetkili test projesi, iki hesap/iki kafile, gerçek URL ve operasyon kararları | İzolasyon, davet iptali, offline teslim, silme, konum iptali ve FCM/APNs teslimi |
| Mobil kullanım | Kaynak/birim testleri var; eski native kanıtlar tarihsel | Son binary ile fiziksel Android/iPhone turu | Küçük ekran/büyük yazı, ekran okuyucu, ses kesintisi, izin reddi ve veri korunması |
| Android dağıtımı | Üretim imzası ve ARM64/16 KB kabulü açık | Son imzalı AAB ve final native kitaplık/paket denetimi | Paket hash'iyle bağlı fiziksel cihaz ve dağıtım kabulü |
| iOS dağıtımı | Minimum 15.0; üretim imzası/fiziksel cihaz kabulü açık | Yetkili Apple hesabı, imzalı build ve TestFlight | Son build'e bağlı gerçek cihaz ve TestFlight kurulum kanıtı |
| Mağaza | Metadata, beyan ve devir taslakları mevcut | Gerçek kamu URL'leri, veri kararları, final ekran görüntüleri ve hesap bilgileri | Son binary ile eşleşen mağaza formları ve gönderim kaydı |

Yeni dinî metin, uzman kararı, ses hakkı veya canlı servis kabulü uydurulmaz.
Dış girdiler beklenirken mevcut çalışan özellikler yeniden kurulmaz.
Uzun CI/native turu geliştirmeyi bloke eden otomatik bir adım değildir;
son mobil/yayın kabulü gerektiğinde ayrı, sürüme bağlı bir teslimdir.

## Gerçek girdilerin teslim noktaları

- İçerik/hak: `docs/release-handoff/2026-10-10/README.md`,
  `FIRST_UMRAH_SLICE.md`, adım/dua/kayıt çalışma CSV'leri ve `decisions.csv`.
- Yer/saha/dil: aynı dizindeki `DATA_DELIVERY.md`, kritik OSM yer incelemesi,
  dil kartları ve rota teslim CSV'si.
- Canlı Kafile: `MODERATION_POLICY.md`, sürümlü şartlar ve gerçek test
  projesi; `ServiceReadiness` gerektirdiği dört gerçek HTTPS URL.
- Cihaz ve imza: son commit/build/hash ile fiziksel kabul ve mevcut
  `tools/release_preflight.py` kanıt manifestleri. Gizli anahtarlar Git'e girmez.

## Yayın kapısının mevcut sonucu

Bu çalışma ağacında full `release_preflight` **blocked / 158** döndü:
53 adım, 1 dua, 55 ses kaydı, 35 Hac profil incelemesi, eksik Arapça telbiye
dosyasından 1 bütünlük engeli ve 13 dış kanıt manifesti. Bunlar 158 farklı
kod hatası değildir; kayıt bazında eksik yayın kabulü denetimleridir.
54 mevcut dosyanın fiziksel varlığı ve teknik özeti hak/onay yerine geçmez.

## Bu dilimin doğrulaması

- Flutter 3.47.6 / Dart 3.13.5: `flutter analyze --no-pub` **0 sorun**.
- `flutter test --no-pub`: **252/252 geçti**; önceki 244 teste 8 regresyon eklendi.
  Üç Hac profili, Umre kaynakları, açık haritada yer ekleme/silme, katalog okuma
  hatasından kurtarma, bağımsız gezi yenilemesi ve paket hatası kurtarması kapsanır.
- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  **92 dosya temiz**; `git diff --check` temiz.
- Python araç turu **84/84**; değişen mobil akış için hedefli politika turu
  **14/14**, dokuz Maestro YAML biçim kontrolü geçti.
- Ayrı teknik QA sesinin AAC decode/bütünlük kontrolü geçti; bu teknik dosya
  kullanıcı paketine eklenmedi. Full yayın denetimi **blocked/158**.

Yeni kaynak alanları nedeniyle bir navigasyon testinde düğme viewport altına
  düştü; assertion korunup düğmenin tamamını görünür yapan kaydırma eklendi.
İlk tam Flutter turundaki 21 hata ortamda `libsqlite3.so` yükleme adının eksik
olmasından kaynaklandı. Sistem `libsqlite3.so.0` kitaplığına geçici test dizininden
bağlantı ve `LD_LIBRARY_PATH` verilerek tekrar edildi; uygulama/veritabanı kodu
bu ortam hatası için değiştirilmedi. Flutter arşivi açılırken sahiplik engeli
`TAR_OPTIONS=--no-same-owner` ile giderildi. İlk eşzamanlı Flutter başlangıcındaki
cache stamp yarışı son test/analiz komutları sırayla çalıştırılarak giderildi.

Uzun CI beklenmedi; yeni native derleme/emülatör, fiziksel cihaz, canlı servis,
üretim imzası veya mağaza turu çalıştırılmadı. Bu sonuçlar kaynak/birim/widget
kabulüdür; tam ürün yayını için tablodaki dış girdiler hâlâ gerekir.
