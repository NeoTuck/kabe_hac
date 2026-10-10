# Profesyonel sürüm uygulama durumu — 9 Ekim 2026

Başlangıç kodu `876fb995c63f102a24d421c2a95a60a00c3b4897` idi. Bu belge `docs/25-profesyonel-surum-son-isler.md` içindeki altı teslimi izler. Teknik tamamlanma yayın/onay anlamına gelmez. Başlangıç incelemesi dosyası tarihsel durum olarak korunur.

| İş | Bu turda yapılan | Kabul için açık kalan |
| --- | --- | --- |
| 1. Sesleri bağla | 18 Umre, 35 Hac anlatımı ve telbiyenin Türkçe anlam kaydı `assets/audio/draft-v2/` içine eklendi. Kaynak inceleme fişi, metin kimliği/sürümü, dosya SHA-256 ve katalog bağlantısı `tools/integrate_review_audio.py --check` ile doğrulanıyor. Rehber ve prova aynı ses kaydını kullanıyor; arayüz ve medya başlığı “sentetik taslak” diyor. Android debug APK içinde 54 dosya/hash doğrulandı. | Dinî/Arapça uzman dinleme kararı, sentetik sesin kullanım hakkı, fiziksel cihazda çevrimdışı/medya kabulü. Arapça ses mevcut değil. |
| 2. Gezinmeyi düzenle | Dört sekme seçimi ve sekmeden geri dönüş korundu; yinelenen Umre ana ekran girişleri kaldırıldı. Kaldığı yer, dinle, sayaç ve geçiş akışları kod/test kapsamında güncellendi. | Küçük ekran, büyük yazı ve erişilebilirlik için fiziksel Android/iPhone kabulü. |
| 3. Veri ve sohbet güvenliği | Ayarlara gizlilik/destek/hesap silme bağlantısı ve cihazdaki ilerleme/favori/kuyruk/konum durumunu silme eklendi. Giriş yapan kullanıcı hesap silme isteğini kaydedip kaydın alındığını görebilir; istek sunucuda açık konum paylaşımını durdurur ve bildirim tokenını siler. Şikâyet ve kullanıcı engelleme istemcisi ile RLS tablosu eklendi; engellenen kişinin kuyruktaki mesaj bildirimi de teslim öncesi yeniden denetlenir. Canlı servis, üç HTTPS bağlantı ve `LIVE_SERVICE_ACCEPTED=true` derleme işareti birlikte verilmedikçe kapalı. | Doğrulanmış gerçek bağlantılar; isteği işleyip hesabı/veriyi silen ve sonucu bildiren sorumlu süreç; moderasyon görevlisi, şikâyet yanıtı ve saklama kararı; gerçek sunucuda migration ve iki hesap kabulü. İstek kaydı hesabı kendiliğinden silmez. |
| 4. İçerik ve gezi | 1.284 kritik OSM yer kaydı için `docs/content-review/2026-10-09-kritik-osm-yer-incelemesi.csv` inceleme kuyruğu çıkarıldı; gezi ekranında ham yer verisinin inceleme durumu açıklanıyor. | 53 metin, telbiye, üç Hac profili, ses/metin dinleme, rota/dil ve yer adları için gerçek uzman/yerel inceleme ve sürümlü karar. Boş inceleme alanları onay değildir. |
| 5. Kafile canlı kabul | Engelleme/şikâyet şeması yerel PostgreSQL işleminde yüklendi ve örnek mesaj/görünürlük denemesi geçti. | Test Supabase/Firebase/APNs projeleri, iki hesap/iki kafile uçtan uca test, çevrimdışı tek teslim, gerçek push, konum rızası/iptali, saklama/temizleme ve geri alma kaydı. pgTAP paketi bu makinede çalıştırılmadı. |
| 6. Paket/dağıtım | Android debug APK üretildi ve ses varlıkları doğrulandı. | Fiziksel Android/iPhone matrisi, iOS simülatör/cihaz derleme, imzalı AAB ve TestFlight, canlı bağlantılar ile mağaza beyanları. Mevcut debug APK dağıtım paketi değildir. |

## Bu turdaki kanıt

- `flutter analyze`: temiz.
- `flutter test --reporter expanded`: 196 test geçti.
- `python3 tools/integrate_review_audio.py --check`: 54 ses/metin/hash bağı geçti.
- `flutter build apk --debug`: başarılı; APK ZIP içindeki 54 taslak sesin hash'i kaynak fişleriyle eşleşti.
- Tüm migration'lar yerel PostgreSQL işleminde yüklendi; sohbet engeli/görünürlük, engel öncesi/sonrası push uygunluğu ve hesap silme isteğinde konum/token iptali örnekleri geçti. İşlemler geri alındı. pgTAP 55 iddiası yerel kurulumda çalıştırılmadı. Bu, canlı Supabase testi değildir.
- Xcode 26.6 ile iOS simülatör derlemesi denendi; `objective_c` native asset hook'u Xcode betiği içinde SDK yolunu alamadığı için başarısız. Uygulama kodunun iOS üzerinde kabul edildiği anlamına gelmez.
- `tools/release_preflight.py`: taslak içerik ve eksik dış kabul kanıtları nedeniyle `blocked`, 157 açık girdi döndürdü. Sayı yalnız bu turun yeni kusurları değildir.

## Yayın kapısı ve sahipleri

Ürün/veri sorumlusu gerçek gizlilik, destek ve hesap silme URL'lerini; tek yönetici hesabı silindiğinde kafile mülkiyeti için kararı; mesaj/konum saklama süresi ve şikâyet sorumlusunu sağlamalıdır. Dinî ve Arapça uzmanlar sürümlü metin/ses kararlarını, hak sahibi sentetik ses lisansını, saha ekibi rota/dil/yer kabulünü vermelidir. Canlı proje, test hesapları, fiziksel cihazlar ve imza/dağıtım hesaplarıyla kalan kabul çalıştırılmalıdır. Bu girdiler olmadan `LIVE_SERVICE_ACCEPTED` verilmez ve profesyonel sürüm yayımlanmaz.
