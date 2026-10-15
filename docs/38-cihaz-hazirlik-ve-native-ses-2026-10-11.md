# Cihaz hazırlığı ve gerçek paketli native ses — 11 Ekim 2026

Uzak HEAD `38b176a` fetch ile doğrulandı; çalışma ağacı temizdi. Plan: son native artifactları doğrula; gerçek kullanıcı hatalarını regresyonla düzelt; hazırlıkta yerel/taslak/izinli durumunu açıklaştır; ilk sınırlı Umre incelemesi ve fiziksel cihaz devrini somutlaştır; yerel test/derleme ve normal GitHub kayıtlarını tamamla. Yeni özellik ve 3D eklenmedi.

## Gerçek son native kanıt

[CI38125787320](https://github.com/NeoTuck/kabe_hac/actions/runs/38125787320) Flutter/debug APK, optimize Android, veritabanı ve QA başarılı. API28 ekran **8/9**, API35 **6/9**, Xcode16.4/iOS18.5/iPhone16 simülatör **8/9**. Üç ZIP digest, JUnit/commands/hiyerarşi, tüm anlatım logları ve aşama exit kodları okundu. Android kurulu ve beklenen APK özeti eşleşti. PR merge `346b5429` tree `584a6c2ed22faa950397f257b984a3ef83f51272` dal HEAD ağacıyla aynı. Xcode26.2 işi gözlemde sürüyordu; sonucu uydurulmadı. [Makine okunur kanıt](qa/2026-10-11-cihaz-hazirlik-ve-native-ses.json).

**54 gerçek paketli anlatımın tamamı üç ortamda native oyuncuyla geçti:** dosya yükleme, ilerleyen konum/süre, pause, seek, hız, resume, stop; hızlı dosya değiştirme ve eşzamanlı seek/pause/replace. Ayrı teknik probe da üçünde geçti. Bunlar konuşmacı/telaffuz/dinî/hak veya fiziksel telefon onayı değildir. Bütün anlatım integration testi artık ekran testi başarısız olsa da yürür; eski atlama açığı kapandı.

Harita çizimi/ortak Eczane filtresi üç ortamda geçti. Hazırlık ve Kıran ilerleme akışı API28 ve iOS18.5'te geçti; API35'te bu iki akış launchApp öncesi ADB device offline nedeniyle çalışamadı. Assertion başarısızlığı yeniden çalıştırılıp gizlenmedi. Bu tur düzeltilmiş yeni HEAD'in tam native kabulü değildir.

## Uygulanan kullanıcı düzeltmesi

Ses hız seçicisi önce kart başlığı/konumuyla tek erişilebilirlik metnine birleşiyordu; görünür olduğu halde Android/iOS Maestro bulamıyordu. Yeni bağımsız Semantics container/button düğmeyi ayrı label ve gerçek tap action ile sunar. Regresyon önce yanlış birleşik label ile başarısızdı; şimdi semantic tap menüyü açıp hızı değiştirebilir. Oynatma durumunu değiştirmez.

API28'de kısa ses pause komutu 13,7 s sürmüştü; resume sonrası kalan süre bittiği için Duraklat assertion'ı düştü. Native akış pause sırasında iki 10 sn geri ile gerçekten sıfıra seek yapıp 0:00 konumunu doğrular, sonra resume/play assertion'ını yürütür. Dosya uzatılmadı, assertion/kapsam kaldırılmadı.

Hazırlıkta yalnız onaylı dosya sayısı vardı; mevcut taslak dosyaların fiziksel varlığı görünmüyordu. Yerel SHA-256 kontrolü şimdi iki ayrı sonucu verir: Umre **19/20 cihaz dosyası, 19 taslak, 1 eksik, 0/20 izinli**; Hac **35/35 cihaz dosyası, 35 taslak, 0/35 izinli**. Onaylı metin/ses ve reviewOnly kapıları aynı kalır; taslak varlığı yolculuk hazır durumunu açmaz. Eksik/bozuk dosya fiziksel hazır sayılmaz. Ağ katalog çağrısı yok. 320px/yüzde200 yazı, gerçek varlıklar ve izinli sayılmama regresyonları geçti; native08 de pozitif gerçek cihaz ses sayısını kontrol eder.

## Yerel doğrulama ve erişim sınırı

Tam Flutter **234/234**, Python **66/66**, format **92 dosya/0 değişiklik**, analyze **0 sorun**, dokuz YAML politika ve diff kontrolleri geçti. İlk paralel Flutter invocation ortak SDK engine.stamp dosyasında yarıştı; bu ortam hatası kaydedildi ve Flutter komutları sıralı yeniden çalıştırılarak yukarıdaki sonuç alındı. Bu hata uygulama test geçişi sayılmadı.

Yeni Android debug denemesi Gradle Kotlin DSL6.4.2 plugin ağ çözümlemesinde exit1 / yaklaşık7,5s ile blocked. Önceki HEAD CI derlemesi başarılıdır; yeni yerel APK kabulü değildir. Linux'ta Xcode yok, adb devices listesi boş; kullanıcı Mac/iPhone'una erişim yoktur. Fiziksel iPhone kullanım turu, çağrı/kulaklık/arka plan ve son binary uçak modu kanıtı açıktır.

## İlk Umre ve gerçek hizmet devri

[İlk Umre inceleme dilimi](release-handoff/2026-10-10/FIRST_UMRAH_SLICE.md) üç mevcut adım, telbiye metni ve bağlı beş ses kimliği için mevcut tam tablodan seçilmiş **19 boş karar satırı** içerir. Kişi/tarih/imza/approved üretilmedi; dört Türkçe kayıt sentetik taslak, Arapça telbiye dosyası eksiktir. Metin sürümü ve record/asset özetleri korunur. Dar dilimin kabulü tam Umre veya Hac profili kabulü değildir.

Yetkili servis test projesi/hesapları, gerçek koşul metni/sürümü, push cihazları ve operasyon/saklama sorumlusu yok; iki hesap/iki kafile canlı kabulü yapılamadı. Somut teslim ve fiziksel cihaz kanıt formatı aynı belgede. LIVE_SERVICE_ACCEPTED kapalı; taslak içerik, yayın kapıları, main ve kullanıcı kapsamı korunur.
