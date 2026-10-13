# Tek dal ve günlük kullanım dilimi — 13 Ekim 2026

## Tek çalışma noktası

Uzak `codex/mvp1-pilot` commit'i `218291b` doğrulandı. Temiz yerel aynı adlı dal bu commit'e fast-forward edildi. Tarihsel `codex/full-version-20261009` dalındaki tek özgün Umre taslak özet değişikliği `f311d26` olarak güncel dala cherry-pick edilip normal push edildi. Kullanıcı yolu ve paket durum düzeltmeleri `01f3ddf` commit'indedir. Çatışma olmadı. Eski dal silinmedi; `main` birleştirilmedi. PR #1 taslak kalır. İlk kullanım akışı PR #2 ile zaten birleşmişti; yeniden kurulmadı. iOS 26.2 kurulum süresi düzeltmesi ve kısa CI düzeni korundu.

## Kodda iyileştirilen kullanıcı yolu

- Umre başlık kartı kaynaklı mevcut özet ve ayrıntıyı doğrudan **“Taslak özet — dinî inceleme bekliyor”** etiketiyle gösterir. Hac profil uygunluğu, dua/Arapça ve onaylı ses kapıları değişmedi.
- Ana sayfa rehberin cihazda bulunduğunu ve Mekke, Medine ile yer paketlerinin **dosya doğrulama** sonucunu ayrı gösterir. Kurulum işaretçisi tek başına “hazır” sayılmaz; bozuk paket için doğrulama başarısız görünür. Paket yöneticisinden dönüşte durum yenilenir.
- Gezi sekmesinde harita paketleri ve eksik yer kayıtları için doğrudan paket yöneticisi açılır. Dönüşte yer listesi yeniden yüklenir. Boş harita ekranı ve harita yükleme hatası paket yönetimine götürür; yeniden okuma eski hata durumunu temizler.
- iOS görünen uygulama adı Android ile “Hac ve Umre Sesli Rehber” olarak eşlendi. Lisans ekranındaki sürüm `pubspec.yaml` içindeki `0.1.0+1` ile eşlendi.

## Kod ve veri incelemesi

İlk kullanım, Hac türü, kaldığı yer, açıklama/ses, manuel sayaçlar, prova, paket/harita, Kafile ve yerel veri ekranları kod üzerinden incelendi. Mevcut katalogdaki 18 Umre ve 35 Hac adımının **tamamında** özet, ayrıntı, kaynak ve metin sürümü alanı var; tamamı `draft`. Başlıktan ibaret boş adım bulunmadı, bu nedenle yeni dinî metin eklenmedi. 54 paketli sesin dosya SHA-256'sı ve bağlı metin sürümü eşleşti; Arapça telbiye ses dosyası yok. `release-inputs/local-review-audio-v2/review-index.json` bu iş ağacında bulunmadığından kaynak makbuzlarına bağımlı entegrasyon aracı burada çalışmadı. Bu durum mevcut paketli sesin hak onayı anlamına gelmez.

Kafile için mevcut `LIVE_SERVICE_ACCEPTED` kapısı, RLS/hesap sınırları, reddedilen outbox mesajları ve silme korumaları yerinde bırakıldı. Paket güvenliği, ses kesintisi, manuel ilerleme ve ayrı Hac/prova kayıtları değiştirilmedi. Gerçek servis ve hesap testleri yapılmadı.

## Yerel doğrulama

- `dart format --output=none --set-exit-if-changed lib test`: temiz.
- `flutter analyze`: 0 sorun.
- `flutter test`: 244 test geçti; yeni boş gezi/harita yolu, paket dönüşü ve yanlış çevrimdışı hazır iddiası regresyonları içerir.
- `TMPDIR=/private/tmp build/qa-venv/bin/python -m unittest discover -s tools -p 'test_*.py'`: 84 test geçti. İlk sistem Python denemesi yalnız PyYAML eksikliğinde durdu; `tools/qa-requirements.txt` geçici sanal ortama kurulduktan sonra tekrarlandı.
- `tools/content_audit.py`: 18/35 adımın tümü taslak; 1 dua, 55 ses kimliği. Paketli 54 ses için ayrıca yerel SHA-256/metin sürümü eşleşmesi geçti.
- `git diff --check` ve iOS `plutil -lint`: temiz.

Kullanıcının açık isteğiyle uzun GitHub CI, emülatör, cihaz, release APK/AAB veya native ses turu başlatılmadı. Önceki native kanıtlar tarihsel; bu commit'ler için fiziksel ya da mağaza kabulü yoktur.

## Dış girdiye bağlı kalanlar

1. 53 adım, dua ve üç Hac profil matrisi için gerçek dinî/dil uzmanının sürüm ve tarih bağlı kararları; ilk Umre dilimi teslim şablonu `docs/release-handoff/2026-10-10/` içindedir.
2. 54 sentetik sesin model/çıktı dağıtım hakkı ve metinle işitsel eşleştirme kararı; Arapça telbiye için ayrı izinli kayıt.
3. Yetkili Supabase/Firebase/APNs test projesi, iki hesap/iki kafile, dört gerçek hizmet URL'si, moderasyon ve silme sorumlusu, saklama kararı. Bunlar olmadan canlı Kafile kapalıdır.
4. Yer/rota/dil/saha insan incelemesi; fiziksel Android/iPhone çevrimdışı, ses, erişilebilirlik ve izin akışı kabulü; ARM64/16 KB son paket, üretim imzaları ve mağaza beyanları.

Bu teslim kullanılabilirliği artıran **teknik pilot kodudur**. Kullanıcı yayını ve mağaza kabulü yukarıdaki kanıtlar gelene kadar açık kalır.
