# Hac ve Umre sesli rehber: ana yapı

Bu belge 5 Ekim 2026'da uygulanan ana yapı dilimini açıklar. Dinî içerik veya profil uygulanabilirliği için onay belgesi değildir.

## Çalışan akış

Ana sayfadan Umre veya Hac seçilir. Her ikisinde öğrenme/yolculuk biçimi vardır. Hac için ayrıca Temettü, İfrad veya Kıran seçilir. Gruplanmış listeden ayrıntı açılır, önceki/sonraki başlığa gidilir. Ana sayfa en son güncellenen oturumu `Kaldığım yerden devam` ile açar. Liste, içerik sürümünde olmayan kayıtlı bir kimliği açıkça bildirir; kullanıcı geçerli bir başlık seçince o oturumun son konumu güncellenir. Eski veri otomatik silinmez.

Umre'de kullanıcı işareti ve tavaf/sa‘y manuel sayaçları korunur. Kartı açmak, sıradaki karta geçmek ve sesin bitmesi işaretleme yapmaz. Hac türlerinin hangi adımlardan geçeceği doğrulanmadığından üç profil ayrı oturumlara sahip birer **35 başlık önizlemesi** olarak açılır; Hac'ta işaretleme ve profil bazlı yönlendirme kapalıdır. Öğrenme modu liste içinde serbest gezinir.

Teknik demo kartı (`DEMO-001`) gerçek dinî içerikten ayrı ekranda durur. Arapça örnek RTL gösterilir; sentetik yerel ses oynatılır. Bu kartın eski `last_step_id` kaydı korunur. Onaylı ses varsa `NarrationService` tek oyuncu ile oynat/duraklat/tekrar sağlar; başlık değişiminde ses durur. Olmayan veya bozuk ses anlaşılır hata verir, başlık kullanılabilir kalır. Ses hızı ve yazı boyutu ayarı SQLite `app_state` içinde saklanır.

## İçerik şeması ve kimlikler

`assets/content/umre_inventory.v1.json` ve `assets/content/hac_inventory.v1.json` çevrimdışı kataloglardır. `schemaVersion: 1`, `contentVersion`, `guideType`, `steps`, `audioRecords`, `prayerRecords` zorunludur. Adımın `id`, `groupId`, `order`, `title`, `status` alanları zorunludur. Açıklama (`summary`, `details`), `arabic`, `transliteration`, `meaningTr`, `sourceReference`, `reviewedBy`, `audioId`, `prayerIds` isteğe bağlıdır. Hac adımlarında `profileApplicability` üç profili de belirtir; değerler `unverified`, `applicable`, `notApplicable` olabilir. Ses ve dua kendi kimlik kayıtlarına sahiptir. Onaylı adım, dua ve ses için kaynak/inceleme/dosya alanları doğrulanır. Kırık kayıt kimliği, tekrar eden kimlik, eksik alan, sıra ve bilinmeyen şema reddedilir.

Ana Plan 2.3 bu çalışma alanında olmadığından, sesli rehber planının 4–5. bölümlerindeki grup sırası ve alt adım sayılarıyla sabit `U01.1`…`U10.2` (18) ve `H01.1`…`H10.3` (35) kimlikleri üretildi. Grup adetleri Umre için `2,3,1,1,1,3,2,1,2,2`; Hac için `3,5,3,4,3,4,3,4,3,3`. Sıra ve kimlik ilişkisi doğrulayıcıda sabittir. Eski `draft-uGG-NN` Umre kimlikleri yalnız migrasyon sırasında `UGG.N` biçimine çevrilir. Başlıklar envanter taslağıdır; açıklama, dua, Arapça metin, çeviri veya profil hükmü üretilmedi. Bütün Hac uygulanabilirliği `unverified` durumundadır.

## Kalıcı kayıt ve migrasyon

SQLite şema sürümü 4'tür. `guide_sessions` oturum kimliği, tür, kullanım biçimi, Hac profili, son adım, içerik sürümü ve zamanları tutar. `step_marks` kullanıcı işaretlerini, mevcut `counter_state`/`counter_events` sayaçları, `app_state` teknik demo ve ayarları tutar. Öğrenme/yolculuk ve her Hac profili ayrı oturum açar. Yeni yolculuk eskiyi silmeden yeni satır oluşturur. `readSession` ile ayrıntıdan dönüldüğünde güncel adım yeniden okunur.

v1 teknik demo `app_state` korunarak yeni tablolar oluşturulur. v2/v3 veritabanında profil sütunu eklenir; Umre oturumlarının son adım ve işaretlerindeki `draft-uGG-NN` kimlikleri dönüştürülür. Sayaçlar ve diğer alanlar yerinde kalır. İçerik sürümü otomatik değiştirilmez; kayıt hangi içerikle açıldıysa o sürüm saklanır. Bilinmeyen eski kimlik listeden seçilince kurtarılır.

## Sınırlar ve sonraki parça

Gerçek kaynaklı metin, dua, Arapça ve Türkçe incelemesi, ses hakları ve Hac profil matrisi henüz yoktur. Arka plan sesi ve kilit ekranı kontrolü de eklenmedi. Sonraki **tek geliştirme parçası**, uzman onaylı ilk Umre metin/dua/ses paketini kaynak, ses hakkı ve inceleme alanlarıyla kataloğa ekleyip ilgili kartlarda doğrulamaktır. Hac matrisi ayrı onay girdisiyle daha sonra yapılmalıdır.

`flutter analyze` ve `flutter test` ile kod doğrulanır. 5 Ekim 2026 `flutter doctor -v`: Android SDK bulunamadı; tam Xcode/xcodebuild ve CocoaPods yok. Android/iOS derlemesi ve gerçek cihazda ses, erişilebilirlik, yaşam döngüsü doğrulanmadı. Telefonlarda hazır olduğu iddia edilmez.
