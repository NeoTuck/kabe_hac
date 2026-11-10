# 48. İçerik Kapısı, Rota/Ses Temizliği, Bozuk Akışlar ve Ölçüm Doğrulaması (10 Kasım 2026)

## Amaç ve Kapsam

Bu dilimde kullanıcının belirlediği 5 iş eksiksiz olarak uygulanmış ve doğrulanmıştır:

1. **İçerik kapısı**: `lib/guide_sections_screen.dart` ve `lib/prayers_screen.dart` ekranlarındaki sabit kodlanmış dinî metinler onaylı katalog akışına bağlandı. Normal derlemede (`LocalContentRepository.load()` ile gelen boş/onaysız katalog) kullanıcıya onaysız dinî metinler sunulmaz; dürüst boş durum ("Onaylı rehber içeriği henüz bulunmuyor", "Onaylı dua kaydı henüz bulunmuyor") gösterilir. İnceleme derlemesi (`KABE_AUDIO_REVIEW_BUILD=true` / `catalog.isPreview`) ayrı tutulur ve taslak adımları inceleme uyarısıyla listeler.
2. **Yanıltıcı rota ve sesler**: `lib/group_screen.dart` içindeki uydurma otel lobisi duyurusu, sahte "1.4 km · 18 dk" yürüyüş rotası, çalışmayan "Rotayı Haritada Aç" snackbar'ı ve uydurma sohbet mesajları temizlendi; yerine dürüst boş durumlar ("Kafile duyurusu henüz bulunmuyor") getirildi. `guide_sections_screen.dart`'taki hardcoded `review-male-v1` ses referansları kaldırıldı; ses düğmeleri yalnız katalogda doğrulanmış, onaylı veya inceleme sürümünde oynatılabilir kayıtlarda gösterilir; aksi halde sahte play butonu sunulmaz.
3. **Bozuk akışlar**:
   - `lib/guide_sections_screen.dart`: Hardcoded `_activeSessionId = 1` kaldırıldı; nullable yapıldı. Oturum veritabanından yüklenene kadar sahte işlem engellendi. Sessiz `catch (_) {}` yutması kaldırılarak kullanıcıya hata bildirimi ve UI rollback mekanizması eklendi.
   - Cemarat anahtarı: `JamaratCounterHubScreen` açılışı `counterKey == 'jamarat' || counterKey == 'cemarat'` durumunda sağlanarak `ProgressStore`'un `ArgumentError` fırlatması engellendi.
   - Kontrol listesi kimlikleri: Checklist kayıtları deterministik `stepId:check_N` kimliğiyle kaydedilir ve `stepId` de `step_marks` tablosuna işlenir.
   - Hac profili seçimi: Hac rehberi ekranında başlık altına Hac türü (Temettü, İfrad, Kıran) seçici dropdown eklendi; `_switchProfile` ile oturum doğru profille güncellenir. `lib/selection_screens.dart` üzerinden `_openHajjGuide({HajjProfile? profile})` bağlantısı kuruldu.
4. **Ölçüm ve animasyon**:
   - `lib/qibla_compass_screen.dart`: Sensör varlığı (`_hasSensor`) kontrol edildi. Sensör yokken "Kıbleye yöneldiniz" denmez; "Görsel Simülasyon (Sensör Yok)" rozeti ve sensörsüzlük bilgilendirmesi gösterilir; haptic feedback engellendi.
   - `lib/prayer_times.dart`: `timeZoneOffsetHours` desteğiyle vakitler evrensel UTC olarak üretilir (`makeDateTime`). Geri sayım ve vakit hesaplaması anlık UTC zamanı ile karşılaştırılarak cihazın yerel saat dilimi farklarından bağımsız tutarlı hale getirildi.
5. **Kabul ve Paket Denetimi**: Normal APK ve `.review` APK ayrı derlendi, hash'leri ve varlık içerikleri doğrulandı.

---

## Yapılan Değişiklikler

### 1. `lib/guide_sections_screen.dart`
- Sabit `_buildUmrahSections()` ve `_buildHajjSections()` kaldırıldı; katalogdaki adımlar (`widget.catalog.steps`) üzerinden dinamik bölümler oluşturulur.
- Normal modda (`!cat.isPreview`) yalnızca `step.isApproved` olan adımlar listelenir. Boş veya onaylanmamış katalogda dürüst boş durum ekranı gösterilir.
- `_resolvePlayableAudio()` eklendi: Ses kaydı yalnız adım onaylı ve ses kaydı onaylıysa (veya inceleme derlemesinde `isSyntheticDraftPreview` ise) oynatılabilir kabul edilir.
- `_buildAudioBar()` güncellendi: Onaylı ses kaydı bulunmayan adımlarda çalışmayacak sahte play düğmesi yerine "Bu başlık için onaylı ses kaydı henüz yok" bilgilendirmesi gösterilir.
- `_activeSessionId = 1` varsayılanı kaldırıldı; oturum açılışı beklenir. Hata durumunda snackbar ile bildirim verilir.
- Hac için banner altında profil seçici dropdown (`HajjProfile.temettu`, `HajjProfile.ifrad`, `HajjProfile.kiran`) eklendi.
- Cemarat için `JamaratCounterHubScreen` yönlendirmesi eklendi.
- Kontrol listesi kayıtları `stepId:check_N` kimliğiyle kaydedilir.

### 2. `lib/prayers_screen.dart`
- Sabit 8 dua listesi (`_allPrayers`) kaldırıldı.
- `PrayersScreen({super.key, this.catalog})` yapısına geçirildi; dualar `GuideCatalog.prayerRecords` üzerinden onaylı kayıtlardan (`isApproved`) çekilir.
- Dua yoksa veya onaylı dua bulunmuyorsa dürüst boş durum ekranı gösterilir ("Onaylı dua kaydı henüz bulunmuyor").

### 3. `lib/selection_screens.dart`
- `PrayersScreen` çağrısı `PrayersScreen(catalog: _catalogs[GuideType.umrah])` şeklinde katalogla ilişkilendirildi.
- `_openHajjGuide({HajjProfile? profile})` eklendi; profil seçilerek Hac rehberi başlatılabilir.

### 4. `lib/group_screen.dart`
- Sabit uydurma demo duyurular (`_announcements`), grup mesajları (`_groupChatMessages`) ve özel mesajlar (`_privateChatMessages`) boşaltıldı.
- Çalışmayan ve yanıltıcı "Rotayı Haritada Aç" ve "Materyali İncele" butonları kaldırıldı.
- Duyuru ve sohbetler boşken dürüst boş durum ("Kafile duyurusu henüz bulunmuyor") mesajları eklendi.

### 5. `lib/qibla_compass_screen.dart`
- `isAligned = _hasSensor && (relativeAngle < 4.5 || relativeAngle > 355.5)` yapıldı.
- Sensörsüz cihazlarda simülasyon rozeti gösterilir, "Kıbleye yöneldiniz" mesajı ve titreşim engellenir.

### 6. `lib/prayer_times.dart`
- `makeDateTime` fonksiyonu `DateTime.utc` ile vakitleri üretir.
- Karşılaştırmalar anlık `DateTime.now().toUtc()` üzerinden yapılarak saat dilimi kaymaları giderildi.

---

## Test ve Doğrulama

### Testler
- **Yeni Test Dosyaları**:
  - `test/content_gate_and_audio_test.dart` (4 test): Boş rehber, boş dua, grup ekranı temizliği, Hac boş durumu.
  - `test/measurement_and_animation_test.dart` (3 test): Namaz saat dilimi UTC eşzamanlılığı, sensörsüz pusula uyarısı, animatör adım seçimi.
- **Flutter Test Sonucu**: 269/269 test başarıyla geçti (`All tests passed!`).
- **Flutter Analyze**: 0 hata, 0 uyarı (`No issues found!`).
- **Dart Format**: Bütün dosyalar formatlandı.

### APK Doğrulama ve Karşılaştırma

| Özellik | Normal Teknik APK | Ses İnceleme APK'si (.review) |
|---|---|---|
| **Dosya Yolu** | `build/app/outputs/flutter-apk/app-release.apk` | `build/review/Kabe_Hac_Ses_Inceleme.apk` |
| **Boyut (Bayt)** | 95.910.300 bayt | 108.567.772 bayt |
| **SHA-256** | `39335ebb2936d42248a52f990ec6a737b4a6212b9a774d8b69a97d582e4bcd2d` | `d3c8c6a5af635950d435a43802dbea3e790fd347ff7302701afc769568a87c0a` |
| **Paket Kimliği** | `com.neotuck.kabehac` | `com.neotuck.kabehac.review` |
| **Varlık İçeriği** | 0 taslak ses, 0 envanter JSON (`PASS production fixture exclusion`) | 54 erkek sentetik ses (M4A) + taslak kataloglar (Doğrulandı) |
| **İmza** | Debug sertifikası (`KABE_TECHNICAL_PILOT=true`) | Debug sertifikası |

---

## Kalan Dış Sınırlar (Açık Kapılar)

1. **Uzman Dinî Metin Onayı**: Kataloglar boş ve güvenlidir; gerçek uzman onaylı metinler geldikçe hash bazlı paketlenecektir.
2. **Ses Lisansı ve İnsan Dinleme Onayı**: 54 erkek ses yalnızca `.review` APK'sinde inceleme amacıyla dinlenebilir; normal sürümde sesler açık değildir.
3. **Canlı Servis ve Üretim İmzası**: Canlı Supabase/Firebase servis kabulü ve Google Play üretim keystore imzası henüz yapılmamıştır.
