# Rota, dil, saha ve Arapça kayıt teslimi

Bu şablonlar uygulama varlığı değildir. Boş alanlar gerçek veri sahibi tarafından
kaynak ve inceleme belgeleriyle doldurulur; doldurulmuş sayılmaz.

- Rota: `route-field-delivery.csv`, `TravelRoute` şemasına uyan JSON (id, sürüm,
  bölge, kaynak, kontrol tarihi, lisans, sıralı duraklar, varsa lisanslı geometri).
  Koordinat zinciri yürünebilirlik değildir. Yürünebilirlik/giriş/saha iddiası için
  ayrı kanıt ve geçerlilik süresi gerekir. Mevcut ODbL atfı korunur.
- Dil kartı: mevcut `dil-kartlari-taslak.csv`; Türkçe metin, insan tarafından incelenmiş
  Arapça, isteğe bağlı okunuş, kaynak/lisans, inceleyen/tarih, sürüm ve belge özeti.
  Otomatik çeviri ile `approved` verilmez.
- Saha: kaynak, doğrulama tarihi, geçerlilik bitişi, kapsam/konum ve gerçek
  inceleyen. Çalışma saati, açık giriş, kalabalık ve güvenlik birbirinin kabulü değildir.
- Arapça telbiye: `inventory.json` içindeki `A-P-U02.2-AR-01` ve bağlı
  `P-U02.2-01` metin sürümüne birebir bağlı m4a/AAC kayıt. `verify_recording.py`
  makbuz alanları: audioId, textId, textVersion, file, sizeBytes, sha256,
  durationSeconds, durationToleranceSeconds, declaredOrigin; gerçek izin/kayıt sahibi ve dinleme/telaffuz incelemesi ayrıca
  `decisions.csv` ve evidence makbuzuna bağlanır. Metin düzelirse sürüm yükseltilir
  ve kayıt yeniden eşlenir. Dosya veya izin yokken alanlar boş kalır.

Teslimden sonra mevcut katalog parser'ları, paket manifest/hash ve evidence
kapıları çalıştırılır. Test fixture'ları kullanıcı paketine eklenmez.
