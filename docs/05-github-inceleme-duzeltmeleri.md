# GitHub incelemesi sonrası düzeltmeler — 7 Ekim 2026

Başlangıç: `main` / `b3ae97d17a6d57b6d55c2c57b02f705b982b485c`. Bu değişiklik Supabase mobil adaptörünü veya gerçek dinî/saha içeriğini eklemez; incelemede bulunan erişim açıklarını ve paket kullanım bağlantısını düzeltir.

## Mesaj ve konum erişimi

`20261006220000_harden_messages_and_location.sql`, ilk migrasyondan sonra uygulanır. Mevcut ilk migrasyon değiştirilmedi; önceden kurulmuş test projeleri de yeni migrasyonu uygulamalıdır.

- Mesaj UPDATE izni yalnız `body` ve `deleted_at` sütunlarına verilir. Alıcı, tür, grup, gönderen, istemci kimliği, sunucu zamanı ve mesaj kimliği değiştirilemez. Gönderenin güncel üyeliği RLS ile kontrol edilir.
- Konum rızası UPDATE izni yalnız `status` ve `stopped_at` içindir; süre uzatma, gruba taşıma ve yeniden etkinleştirme engellenir.
- Yönetici okumaları aktif/iptal edilmemiş rıza, başlangıç/bitiş, saklama süresi ve paylaşan kişinin güncel üyeliğini gerektirir. Durdurulmuş rızanın eski koordinatları da yöneticiden gizlenir.
- Yeni konum için güncel üyelik, geçerli rıza, saklama süresi ve ölçüm zamanı kontrol edilir. Sahip kendi koordinatlarını yalnız saklama süresi içinde okuyabilir; rıza geçmişi kendisine açık kalır.
- Bu değişiklik fiziksel veri temizleme zamanlayıcısı kurmaz. Üretimde saklama süresi dolan verilerin sunucuda silinmesi ayrıca kurulmalı; mobil önbellek/Realtime aboneliklerinin rıza iptalinde temizlenmesi P5/P6 kabul testlerine dahildir.

## İndirilen rehber ve sesin kullanılması

Manifest şeması/türü değiştirilmedi. `audio` paketleri sesleri ve isteğe bağlı tam rehber kataloğunu birlikte taşıyabilir:

- Umre kataloğu: `content/umre_inventory.v1.json`.
- Hac kataloğu: `content/hac_inventory.v1.json`.
- Paket JSON'unda `audioRecords[].asset`: `audio/...` biçiminde paket içi göreli yol. Ses dosyası aynı manifestte listelenmiş olmalıdır. Ağ URL'si, cihazın mutlak yolu veya başka paket başvurusu kabul edilmez.
- Dosya kullanılmadan önce aktif sürüm, manifest kimliği, güven özeti, tür, şema, dosya listesi, boyut, hash ve sembolik bağ/yol sınırları kontrol edilir.
- Katalog mevcut kaynak/onay/hak/metin-ses sürüm doğrulamasından geçer. 18/35 sabit adım kimliği korunur. Dinî onay koşulları gevşetilmez.
- Geçerli katalogdaki ses yolları bellekte `package:<packageId>/audio/...` başvurusuna bağlanır. Oynatıcı bunu aktif yerel dosyaya çözer; paket sesi bulunamazsa ağa veya rastgele gömülü dosyaya geçmez.
- Paket ekranından dönüşte katalog yenilenir; güncelleme, geri dönüş ve silme için uygulamayı yeniden başlatmak gerekmez. Her normal ekran dönüşünde paket dosyaları yeniden hash'lenmez.
- Bozuk/uyumsuz paket veya aynı rehber için birden fazla geçerli paket varsa gömülü rehber kullanılır. İndirme/kurulum doğrulaması, dinî içerik onayı değildir. SQLite ilerlemesine dokunulmaz.

## Bu çalışmanın doğrulama kanıtı

Linux üzerinde Flutter 3.47.6 / Dart 3.13.5 ile:

- `dart format --output=none --set-exit-if-changed lib test`: temiz.
- `flutter analyze --no-pub`: sorun yok.
- `flutter test --no-pub`: 53 test geçti (45 mevcut + 8 yeni).
- `git diff --check`: temiz.
- PGlite 0.5.8 (WASM PostgreSQL), pgcrypto ve pgTAP 1.3.2 ile minimal Auth/Realtime fixture'ında 28 SQL kontrolü geçti. Aynı yeni testler yalnız eski migrasyonla çalıştırıldığında 9 kontrol başarısız oldu; regresyonlar düzeltmeyi doğruluyor.

Araç ayarları: Flutter `CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`, `DASH__SUPPRESS_ANALYTICS=true` ile çalıştırıldı; CI ayarı gereksiz Azure metadata sorgusunu atlar. Linux SDK arşivleri `TAR_OPTIONS=--no-same-owner` ile açıldı. SQLite FFI testlerinde sistemdeki `libsqlite3.so.0` için geçici `.so` bağlantısı kullanıldı; bunlar uygulama kodu/bağımlılık değişikliği değildir.

Bağımsız SQL testinin kurulumu ve sınırları `supabase/tests/README.md` içinde. Gerçek Supabase Auth/HTTP/Realtime veya `supabase test db` doğrulanmadı. Android/iOS derlemesi, gerçek cihazda paket sesi ve arka plan oynatma bu çalışmada çalıştırılmadı; önceki APK/emülatör kanıtı yeni değişikliğin platform kanıtı sayılmaz.

## Sonraki iş

Ayrı test Supabase ortamında iki migrasyonu ve pgTAP senaryolarını çalıştır; ardından AGENTS.md'deki P5 mobil repository/Auth/Realtime/outbox dilimini uygula. Gerçek paket sunucusu, onaylı içerik/kayıtlar, harita verisi ve mobil cihaz kabulü hâlâ bekliyor.
