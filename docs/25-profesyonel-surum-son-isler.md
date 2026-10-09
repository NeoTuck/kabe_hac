# Profesyonel sürüm için kalan işler — 9 Ekim 2026

İncelenen kod: `876fb995c63f102a24d421c2a95a60a00c3b4897`. Bu belge kod, katalog, mevcut ekran görüntüsü ve yayın belgeleri üzerinden yapılan kapsam incelemesidir. Yeni test veya cihaz koşusu çalıştırılmadı. Kullanıcının 54 sentetik taslak sesi uygulamaya ekleme isteği açıktır; bu inceleme anında sesler hâlâ `release-inputs/local-review-audio-v2/` içindedir ve APK varlığı değildir.

## Hazır olan temel

Rehber seçimi, 18 Umre/35 Hac adım kimliği, manuel sayaçlar, yerel ilerleme/favoriler, ayrı prova oturumu, tek ses oynatıcısı, indirilebilir paketlerin hash denetimi, Mekke/Medine için 2.928 OSM yer kaydı ve çevrimdışı şehir haritası vardır. Bunlar yeniden yazılacak işler değildir. Kafile, push ve konum için istemci/sunucu kodu vardır; canlı servis kabulü yoktur.

## Öncelik sırası ve bitiş ölçütü

| Sıra | Somut iş | Neden gerekli / gözlenen durum | Bitti sayılması için | Bağımlılık |
| --- | --- | --- | --- | --- |
| 1 | **54 sentetik sesi adımlara bağla** | Kullanıcının açık isteği. 53 anlatım ve bir Türkçe anlam kaydı hazır; katalogda sadece üç taslak ses kaydı var, dosya bağlantıları yok. | 18 Umre + 35 Hac anlatımı ilgili adımda, Türkçe anlam telbiye kartında açılır; kayıtlar internetsiz oynar; metin kimliği/sürümü ve hash eşleşir. UI ve medya başlığı sentetik/taslak kökeni açıklar; hiçbir `approved`, inceleyen veya hak izni uydurulmaz. Provanın ses davranışı aynı kayıtlarla tutarlı olur. | Kodla başlanabilir. Arapça telbiye bu 54 kayıtta yoktur. Yayın hakkı ve uzman kabulü ayrı açık kalır. |
| 2 | **Rehberin gerçek anlatımını ve Hac profillerini tamamla** | Adımların tamamı taslak; kullanıcı çoğu ayrıntıda “İçerik hazırlanıyor” görüyor. Prova açıklamaları da onay filtresine bağlı. | 53 metin, mevcut dua ve Arapça/okunuş/anlam için tarihli uzman kararı; 35 Hac adımının üç profil için uygulanabilirliği belirlenir. Onaylanan sürüm kullanıcıya açılır; önceki ilerleme korunur. Seslerin tamamı metinle dinlenerek karşılaştırılır. | Dinî uzman, Arapça inceleyen, metin/ses kullanım hakkı. Sentetik kayıt kullanılabilir; insan kaydı diye sunulmaz. |
| 3 | **Ana ekranı ve gezinmeyi tamamlanmış ürün düzenine getir** | Ana ekranda Umre girişleri farklı bölümlerde tekrarlanıyor. Alt menü `selectedIndex: 0` ile yalnız ana ekranda ve hedefleri yeni sayfa olarak açıyor. | Rehber/Yolculuk/Kafile/Ayarlar için tutarlı seçili sekme, geri davranışı ve ekran durumu; ana ekranda kaldığı yer ve ana eylemler; adımda dinle/sayaç/önceki/sonraki anlaşılır sırada. Büyük yazı ve küçük ekranda temel eylemler erişilebilir. Gerekli taslak uyarıları kısa ve tutarlı kalır. | Kod ve tasarım. Mevcut özellikler korunur. |
| 4 | **Harita ve yolculuk verisini kullanıcı için düzenle** | Gerçek OSM verisi var; rota listesi ve dil kartları boş. Ham yer adlarının tümü Türkçe değil ve saha doğrulaması yok. | Kritik yerlerin Türkçe adları, kategorileri ve kaynak tarihleri editöryal kontrolden geçer. Yayımlanacak rota/dil kartları insan incelemesiyle eklenir. Paket boyutu/indirme durumu/çevrimdışı hazır bilgisi anlaşılır; uçak modunda yeniden açılır. Harita güvenli navigasyon veya canlı kapı durumu gibi sunulmaz. | Kodla düzenleme; doğrulanmış rota, Arapça dil ve saha girdileri. |
| 5 | **Kafile hizmetini gerçek ortamda aç** | Varsayılan derlemede bağlantı yok; kullanıcı “Kafile hizmeti hazırlanıyor” görüyor. | Gerçek test Supabase/Firebase/APNs yapılandırması; iki hesap/iki kafilede üyelik ve özel mesaj izolasyonu; offline mesajın tekrar bağlanınca tek teslimi; gerçek push; süreli GPS rızası/iptali; saklama ve temizleme işlerinin kabulü. Üretime geçiş ve geri alma adımları hazır olur. | Gerçek test hesapları/projeleri, cihazlar, saklama politikası kararı. |
| 6 | **Hesap/veri kontrolü ve sohbet güvenliğini ekle** | Ayarlarda gizlilik/destek bağlantısı yok. İncelenen istemci ve sunucu arayüzlerinde hesap silme, içerik şikâyeti ve kullanıcı engelleme akışı bulunmadı. | Hesap ve ilişkili verileri silme isteği uygulama içinde ve gerekli web sayfasında başlatılır; sunucuda yetki, token/konum iptali ve sonuç bildirimi vardır. Yerel kayıt silme seçimi açıklanır. Canlı sohbet için kullanım koşulları, şikâyet, engelleme ve sorumluya ulaşan moderasyon akışı işler. | Kodla başlanabilir; veri sorumlusu, destek adresi ve saklama kararları gerekir. |
| 7 | **Gerçek telefonlarda yayın kabulünü tamamla** | Simülatör/emülatör kanıtı fiziksel ses, pil, erişilebilirlik veya sahayı kanıtlamıyor. Yeni 54 sesin uygulama kabulü de henüz yok. | Son paket fiziksel Android/iPhone'da internetsiz kullanım, yeniden açma, ses kesintisi/kilit ekranı/Bluetooth, büyük yazı/TalkBack/VoiceOver, izin reddi ve hesap geçişi senaryolarından geçer. Düşük bellekli cihazda açılış, harita ve ses davranışı ölçülür. | Cihaz erişimi ve son içerik/servis. Kullanıcının mevcut isteği doğrultusunda bu planlama turunda test başlatılmadı. |
| 8 | **İmzalı dağıtım ve destek düzenini hazırla** | Masaüstü APK debug imzalıdır; mağaza metinleri taslak, gizlilik belgesi bazı eski paket/ses durumlarını anlatıyor. | Android üretim AAB/upload imzası; iOS archive/TestFlight; sürüm/build numarası; son uygulamadan mağaza görselleri; çalışan destek/gizlilik/hesap silme URL'leri; gerçek veri akışına uygun mağaza beyanları; içerik güncelleme ve sorun bildirme sorumluları. | Apple/Google geliştirici hesapları ve imzalar; gerçek işletme/kişi bilgileri. |

## Hemen başlanabilecek dilim

İlk kod işi 54 sesin açık taslak etiketiyle rehbere ve ilgili prova kullanımına bağlanmasıdır. Ardından gezinme düzeni, destek/gizlilik erişimi, yerel veri kontrolü, hesap silme ve sohbet güvenliği hazırlanabilir. Kaynak metni taslak kalırken ses eklemek metne uzman onayı vermez; mağaza yayını için gereken incelemeler ayrıca tamamlanır.

İçerik/servis sahipleri aynı sırada uzman incelemesi, ses kullanım hakkı, test projesi erişimi, veri saklama süresi ve dağıtım hesabı bilgilerini sağlamalıdır. Bunlar gelmeden sahte onay veya canlı başarı kaydı yazılmaz.

Yeni 3D, ses klonlama, otomatik ibadet sayımı, çok dil veya gelişmiş navigasyon bu bitirme listesine eklenmedi. Mevcut ürünün temel eylemlerini tamamlamak önce gelir.

## Yayın ölçütlerinin dayanağı

- [Apple uygulama bütünlüğü](https://developer.apple.com/app-store/review/): son metinler, çalışan bağlantılar ve tamamlanmış işlevler beklenir.
- [Apple hesap silme](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion/): uygulamada hesap oluşturan kullanıcılar silme işlemini uygulamadan başlatabilmelidir.
- [Google Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en-en): uygulama içi yol ve uygulama dışından erişilebilir web kaynağı gerekir.
- [Apple kullanıcı içerikleri kuralları, 1.2](https://developer.apple.com/app-store/review/guidelines/uk/): sohbet açıldığında içerik bildirimi, kullanıcı engelleme, uygun moderasyon ve yayımlanmış iletişim bilgileri değerlendirilir.

Eski `docs/qa/2026-10-09-release-blockers.json` dosyasındaki 155 sayısı geçmiş bir içerik/kanıt denetimidir; 155 yazılım hatası veya tüm kalan ürün işlerinin eksiksiz sayısı değildir. Dosyanın tabanı `fe32ebb` olduğu için bu rapordaki güncel kod işleriyle karıştırılmaz.

Bu inceleme sırasında `876fb99` için [CI 37946894099](https://github.com/NeoTuck/kabe_hac/actions/runs/37946894099) devam ediyordu: Flutter, QA, veritabanı ve Android release boyut işleri başarılı; iki iOS ve iki Android UI işi sürüyordu. Bu anlık durum son native kabul değildir.
