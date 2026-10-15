# İlk Umre inceleme dilimi

Bu teslim **onay isteğidir**, onaylı içerik veya tam Umre rehberi değildir. Yeni içerik ya da kişi/tarih/imza üretilmedi. Katalog sürümü `inventory-2026-10-09-draft2-audio`; tam dosya özeti ana `inventory.json` içindedir.

İlk sınırlı inceleme: U01.1 Kullanım biçimi seçimi, U01.2 Hazırlık, U02.1 İhram ve mikat bağlamı; P-U02.2-01 telbiye metni ve bu dört metne bağlı beş ses kimliği. [19 boş karar satırı](first-umrah-slice-decisions.csv) mevcut tam 324 satırlı tablodan değiştirilmeden seçildi. Üç adım için dinî/kaynak hakkı, dua için dinî/dil/kaynak hakkı, beş ses için dinleme/dağıtım hakkı kararları ayrı istenir.

Dört Türkçe dosya sentetik taslaktır; uzman dinlemesi ve model/veri/çıktı hak zinciri gerekir. A-P-U02.2-AR-01 eksiktir: izinli özgün veya kullanım izni belgeli kayıt P-U02.2-01-draft-2026-10-09-v1 metnine birebir bağlı teslim edilmeli. Dosya, SHA-256, gerçek konuşmacı/kayıt sahibi, dağıtım kapsamı/izin belgesi ve insan telaffuz/dil incelemesi birlikte gerekir. Dosya yokken assetSha256 veya dinleme kararı doldurulmaz.

İnceleyen düzeltme isterse metin sürümü ve recordSha256 yenilenir; eski imza yeni metne taşınmaz. Gerçek kararlar ana README'deki KABE_RELEASE_EVIDENCE_DIR/JSON makbuz hattına bağlanır. İnceleme dosyaları ve özel belgeler uygulama varlıklarına eklenmez; katalogların approved durumu değiştirilmedi. Bu dar dilimin kabulü kalan 15 Umre başlığını, Hac profillerini veya tam yayın kapısını tamamlamaz.

## Son fiziksel iPhone kullanım turu için teslim

Bu Linux ortamından Mac/iPhone'a erişim yoktur. Mac'te hedef dalın son HEAD'i ve temiz/kullanıcı değişikliklerini koruyan çalışma ağacı doğrulanmalı; bağlı telefon, Xcode signing ve Team ID gerçek kullanıcı hesabıyla sağlanmalı. Gizli imza ve service-role bilgileri Git'e konmaz.

Son binary ile ilk açılış → Umre öğrenme → gerçek paketli ses oynat/duraklat/devam/seek/hız → sayaç → ayrı prova → harita/kategori → kapatıp devam. Paketler indirildikten sonra uçak modu, büyük yazı, küçük ekran, geri tuşu, gelen çağrı/kulaklık çıkarma ve yeniden açılış kontrol edilir. Her sonuç için gerçek cihaz modeli/iOS, build/commit, tarih, senaryo, beklenen/gözlenen ve ekran/video/log kanıtı kaydedilir. Emülatör başarıları bu fiziksel kabul alanlarına taşınmaz.

Kafile fiziksel servis turu ayrıca yetkili test projesi, iki test hesabı/iki kafile, push cihazı ve gerçek hukuki koşul sürümü ister; mevcut sunucu kabul manifesti doldurulur. Bu girdiler yokken LIVE_SERVICE_ACCEPTED kapalıdır.
