# Birleşik geliştirme programı

**Tarih:** 6 Ekim 2026

**Kapsam:** Umre ve Hac rehberi, ses ve çevrimdışı paketler, harita ve gezi, güvenli iletişim, kafile ve isteğe bağlı konum paylaşımı

Bu belge genişleyen ürünün teknik durumunu ve dış bağımlılıklarını kaydeder. Bir şema, adaptör veya boş durum ekranı ilgili modülün üretimde tamamlandığı anlamına gelmez.

## P0 — Kod ve araç incelemesi

İncelemede doğrulanan başlangıç:

- Flutter 3.47.6 ve Dart 3.13.5 kullanılıyor.
- Rehber çekirdeği hesap istemeden çalışıyor. Umre kataloğunda 18, Hac kataloğunda 35 sabit alt kimlik var.
- SQLite ilerlemesi kullanım biçimi ve Hac profili bazında ayrılıyor; eski Umre kimlik migrasyonu korunuyor.
- İçerik şeması kaynak, sürüm, inceleme, metin ve ses haklarını ayırıyor. Gerçek uzman onaylı içerik ve izinli insan sesi bulunmuyor.
- Android araç zinciri hazır. Tam Xcode ve CocoaPods bulunmadığı için iOS derlemesi yapılamıyor.
- Üretim backend'i, harita sağlayıcısı, paket dağıtım alan adı, APNs/FCM yapılandırması ve gerçek saha veri kataloğu yok.

## Durum matrisi

| Paket | Kodlandı | Otomatik test | Mobil doğrulama | Bekleyen veri / erişim |
| --- | --- | --- | --- | --- |
| P0 İnceleme | Evet | Uygulanamaz | Araçlar kontrol edildi | Yok |
| P1 Rehber ve sayaç | Teknik temel evet | Katalog, migrasyon, profil ve sayaç testleri var | Önceki Android 35 emülatör kanıtı var | 18/35 adım için uzman onaylı metinler; Hac profil matrisi; izinli sesler |
| P2 Ses ve paket | Kesinti, tek oynatıcı, kilit ekranı altyapısı, manifest, indirme, doğrulama, etkinleştirme ve geri dönüş var | Bozuk/eksik/fazla dosya, hash, güven, ağ kesintisi, az alan ve C1/C2 kapısı testli | Android 35 emülatörde medya bildirimi ve ekran kapalı duraklat/devam; gerçek cihaz kesinti testi yok | İmzalı veya sabit özeti güvenilen manifest, HTTPS paket sunucusu ve gerçek paketler |
| P3 Harita, POI, rota | MapLibre offline adaptörü; POI/rota modelleri; arama, filtre ve favori ekranı var | Kaynak, koordinat, sıra, boyut ve kamusal OSM sunucu yasağı testli | Gerçek offline bölge/uçak modu testi yok | Offline dağıtıma izinli sağlayıcı, stil/font/sprite/tile paketi ve doğrulanmış POI/rota |
| P4 Güvenli gezi ve dil | Kaynak/güncellik modelleri ve güvenli boş durum ekranı var | Onay, süre dolması ve kullanıcı bildirimi sınırları testli | Cihaz testi yok | Doğrulanmış numaralar, insan incelemeli Arapça kartlar, saha verisi; sensör işi yapılmadı |
| P5 Kafile backend'i | PostgreSQL şeması, RLS taslağı, davet RPC'si ve yerel outbox var | Flutter outbox testli; pgTAP dosyası hazır | Sunucu bağlantısı yok | Supabase projesi/credential; şema ve iki grup RLS testinin çalışan PostgreSQL'de yürütülmesi; mobil Auth/Realtime adaptörü |
| P6 Konum ve bildirim | Rıza, süre, durdurma ve eski konum modeli; sunucu tabloları/RLS taslağı var | Varsayılan kapalı, süre ve iptal testli | GPS ve push cihaz testi yok | Konum izin akışı, arka plan politikası, APNs/FCM, server gönderimi ve saklama politikası |
| P7 Bütünleşik teslim | Başlamadı | Başlamadı | Başlamadı | Gerçek Android/iPhone cihazları, veri ve servis bağımlılıkları |

## Bu geliştirme parçasında eklenen teknik temel

### Rehber ve sayaç

- Cemarat sayacı Hac yolculuğu içinde kullanıcı tarafından girilen gün ve hedef bağlamına ayrıldı. Her sayaç 0–7 aralığında, işlem kimliğiyle yinelenmeye dayanıklı ve başka yolculuktan erişilemez.
- Hac profili filtrelemesi yalnız bütün uygulanabilirlik kayıtları onaylandığında çalışıyor. Onaysız katalog 35 başlığın tamamını önizleme olarak tutuyor.
- Gezi favorileri, mesaj kuyruğu ve konum rızası dinî ilerleme tablolarından ayrıldı. SQLite şema sürümü 7 oldu.

### Ses ve paketler

- `audio_session` çağrı/odak ve kulaklık çıkışı kesintisinde sesi duraklatıyor; otomatik devam etmiyor.
- `just_audio_background` ve `audio_service` aracılığıyla Android medya servisi ve iOS audio background modu yapılandırıldı. Kilit ekranı ve fiziksel kulaklık davranışı gerçek cihaz kanıtı bekliyor.
- Paket manifesti tür, C0/C1/C2 sınıfı, şema aralığı, dosya yolu, SHA-256, boyut ve HTTPS adresi taşıyor.
- Paketler geçici klasöre iner; tam dosya kümesi, boyut ve hash doğrulanmadan etkinleşmez. Durum işaretçisi geçici dosya ve yedekle değiştirilir; önceki sürüme dönüş vardır.
- C1/C2 güncellemesi açık bir migrasyon kapısı verilmedikçe mevcut sürümün üstüne etkinleşmez. Uygulamadaki varsayılan güven politikası uzak manifestleri reddeder.
- Paket katalog ağı yalnız `PACKAGE_CATALOG_URL`, `PACKAGE_ALLOWED_HOSTS` ve `PACKAGE_MANIFEST_DIGESTS` derleme zamanı değerleri birlikte ve geçerliyse açılır. Katalog yönlendirmeleri, izin verilmeyen dosya hostu ve güvenilmeyen manifest reddedilir. Kullanıcının tekrar denemesi aynı manifest staging dosyasından devam eder.

### Harita ve gezi

- MapLibre offline bölge adaptörü eklendi. İstek; HTTPS stil, açık offline sağlayıcı izni, atıf, geçerli sınır ve yakınlaştırma aralığı istiyor.
- `tile.openstreetmap.org` ve `vector.openstreetmap.org` şehir paketi kaynağı olarak reddediliyor. MapLibre motorunun lisansı ile tile/stil/font verisinin kullanım hakkı ayrı kabul ediliyor.
- POI ve rota kayıtları sabit kimlik, bölge, kaynak, doğrulama zamanı, test verisi etiketi, görünürlük ve moderasyon bilgisi taşıyor. Geometri yoksa uygulama turn-by-turn iddiasında bulunmuyor.

### Kafile ve konum

- `supabase/migrations/` altında şirket, grup, üye, davet, mesaj, duyuru, program, rota, konum ve cihaz token tabloları ile RLS taslağı var.
- Mesaj outbox kaydı `client_id` ile tekrar göndermede çift mesajı engelliyor ve bekliyor/gönderildi/başarısız durumlarını ayırıyor.
- Konum paylaşımı yerelde varsayılan kapalı. Kullanıcı grup, mod ve süreyle başlatıyor; durdurabiliyor. Ölçüm zamanı ile gönderim zamanını ayıran ve eski konumu belirleyen model var.
- Uygulamada Supabase SDK'sı veya credential yok. SQL ve pgTAP dosyaları Docker çalıştırılmadan statik olarak hazırlandı; PostgreSQL üzerinde çalıştırıldığı iddia edilmez. Docker mobil uygulamanın çalışma bağımlılığı değildir.

## Mimari kararlar ve veri izinleri

| Veri / yetki | Yerel davranış | Uzak davranış için koşul |
| --- | --- | --- |
| Dinî ilerleme | SQLite, hesap gerekmez | Sunucuya gönderilmez |
| Ses/paket | Güvenilir manifest ve hash doğrulaması | İzinli dosya barındırma ve sabit güven kökü |
| Harita | Sağlayıcı izni olmadan indirme başlatılmaz | Offline dağıtım lisansı ve atıf |
| POI/rota | Kaynak, doğrulama zamanı ve test etiketi zorunlu | Moderasyon/yayın rolü ve sürüm farkı |
| Kafile mesajı | Outbox teslim edilmemiş mesajı “gönderildi” göstermez | Auth, RLS, kalıcı tablo ve Realtime özel kanal |
| Konum | Varsayılan kapalı; süreli ve iptal edilebilir | Grup yetkisi, açık rıza, saklama/silme politikası |
| Push | Yerel Realtime push sayılmaz | APNs/FCM platform kaydı ve server gönderimi |
| Arapça/dinî metin | Taslak olabilir, onaylı diye sunulmaz | İnsan incelemesi ve kullanım hakkı kanıtı |

Teknik araştırma dayanakları:

- [MapLibre Flutter paketi ve offline bölge desteği](https://pub.dev/packages/maplibre_gl)
- [OpenStreetMap kamusal raster tile kullanım politikası](https://operations.osmfoundation.org/policies/tiles/)
- [OpenStreetMap kamusal vector tile kullanım politikası](https://operations.osmfoundation.org/policies/vector/)
- [audio_service arka plan ve kilit ekranı kurulumu](https://pub.dev/packages/audio_service)
- [audio_session kesinti yönetimi](https://pub.dev/packages/audio_session)
- [Supabase özel Realtime kanalı yetkilendirmesi](https://supabase.com/docs/guides/realtime/authorization?language=dart&queryGroups=language)
- [Supabase yerel geliştirme ve migrasyon akışı](https://supabase.com/docs/guides/local-development/cli-workflows)

## Revize emek tahmini

Bu değerler üretim mağazası teslimi için kaba kişi-gün aralığıdır; süre taahhüdü değildir.

| Paket | Mühendislik / QA kişi-gün |
| --- | ---: |
| P0 inceleme ve mimari | 4–6 |
| P1 rehber, üç sayaç ve profil akışları | 22–35 |
| P2 ses ve çevrimdışı paketler | 25–40 |
| P3 harita, POI ve rotalar | 30–50 |
| P4 güvenli gezi, dil, saha ve sensör | 20–35 |
| P5 Auth, grup backend'i, sohbet ve senkronizasyon | 40–65 |
| P6 konum ve gerçek push | 25–45 |
| P7 bütünleşik cihaz, güvenlik ve yayın hazırlığı | 25–45 |
| **Toplam** | **191–321** |

Paralel dış üretim ayrıca yaklaşık 45–90 kişi-gün dinî içerik/uzman incelemesi, 25–50 kişi-gün ses/hak yönetimi ve 20–40 kişi-gün harita/POI/saha doğrulaması gerektirebilir. Dört etkin tam zamanlı rol varsayımında mühendislik 16–27 takvim haftasına yayılabilir; sağlayıcı, uzman, cihaz ve mağaza beklemeleri bu aralığa dahil değildir.

## Güncel araç ve test notu

6 Ekim 2026 kontrolünde biçimlendirme temiz, `flutter analyze` hatasız ve 45 test başarılıdır. Android debug APK derlendi; 227319901 bayt ve SHA-256 değeri `5ad14fc9e1dd369df42379cbaaaf9c8f900aacaee044c6cfe05cb1c59e2b3b4a` oldu. Android 35 emülatörde uygulama açıldı, teknik ses için medya bildirimi üretildi ve ekran kapalı sistem medya komutlarıyla duraklatma/devam durumu görüldü. Emülatör sessiz olduğundan işitsel kalite, çağrı, Bluetooth ve kulaklık doğrulanmadı.

iOS için tam Xcode ve CocoaPods; gerçek arka plan sesi için Android/iPhone cihazı; offline harita için izinli sağlayıcı bölgesi gerekir. Backend SQL ve pgTAP dosyaları Docker kullanılmadan hazırlandı ve çalışan PostgreSQL üzerinde henüz yürütülmedi.
