# Gizlilik ve mağaza beyanı çalışma taslağı

9 Ekim 2026. Bu metin yayınlanmış gizlilik politikası veya App Store/Play Console beyanı değildir. Ürün sorumlusu, canlı servis ve hukuk/gizlilik incelemesiyle tamamlanmalıdır. Uygulama sürümü `0.1.0+1` teknik pilottur.

## Kodda bugün görülen veri akışları

| Veri/izin | Yerel davranış | Sunucu/mağaza beyanında açık karar |
| --- | --- | --- |
| Rehber ve prova ilerlemesi, sayaç, favori, tema | `sqflite` ile cihazda tutulur; prova gerçek rehberden ayrıdır. | Yedekleme, cihaz aktarımı ve silme yordamı uygulama sahibi tarafından doğrulanmalı. |
| İsteğe bağlı paket | Yapılandırılırsa HTTPS katalog/dosya isteği ve doğrulanmış yerel dosya saklama vardır. Mevcut derlemede gerçek sunucu/güven kökü yok. | Sağlayıcı, sunucu log/IP saklama, lisans/atıf ve silme politikası belirlenmeli. |
| Ses | Onaylı paket dosyası varsa cihazda çalınır; Android medya servisi ve iOS arka plan ses modu kullanılır. Sentetik teknik kayıt APK/IPA varlığı değildir ve yalnız QA fixture'ıdır. Mikrofon kaydı kodu yok. | Gerçek ses sahipliği ve izinleri gelince beyan güncellenmeli. |
| Kafile hesabı ve mesaj | URL/publishable key verildiğinde Supabase Auth/mesaj/üyelik adaptörü devreye girer; çevrimdışı mesaj outbox cihazda kalabilir. Varsayılan yapıda canlı servis yok. | Veri sorumlusu, barındırma bölgesi, saklama, erişim, hesap/veri silme ve alt işleyenler gerçek proje üzerinden kararlaştırılmalı. |
| Konum | Android/iOS yalnız kullanım sırasında konum izni tanımlı. Kafile hesabı ve açık onay varsa bir GPS ölçümü alınır, Supabase'e gönderilir ve 15 dakikalık paylaşım kaydı açılır; otomatik arka plan takibi yok. Durdurma yerel kaydı hemen kapatır, sunucu iptali ağ yoksa doğrulanamaz ve UI bunu belirtir. Sunucu RLS/cleanup kodu vardır ancak canlı projeye uygulanmadı. Varsayılan derlemede canlı Supabase yoktur. | Veri sorumlusu koordinat ve koordinatsız rıza geçmişi saklama süresini seçmeli; açıklama, geçiş ve gerçek iki hesap/cihaz kabulü aynı kararla uyumlu olmalı. |
| Bildirim | Firebase projesi derleme zamanı yapılandırılmışsa kullanıcı izniyle FCM token'ı Supabase'e kaydedilir; yenilemede eski token kaldırılır, çıkışta bu cihazın token'ı silinir. Varsayılan derlemede yapılandırma yok ve izin istemi yok. Bildirime dokunma yalnız doğrulanmış kafile üyeliğine gider. Sunucu outbox/FCM gönderici kodu test modunda dar allowlist ister; canlı projeye deploy edilmedi. | APNs/FCM kimlikleri, açık test hesap/cihaz listesi ve gerçek teslim kabulü gerekli. Sağlayıcının kabulü cihaz teslimi değildir. |

9 Ekim yerel debug APK'sının birleşmiş manifesti `aapt dump permissions` ile okundu: `INTERNET` paket/servis istekleri; `ACCESS_COARSE_LOCATION`/`ACCESS_FINE_LOCATION` kullanıcı başlatmalı tek GPS ölçümü; `WAKE_LOCK`/`FOREGROUND_SERVICE`/`FOREGROUND_SERVICE_MEDIA_PLAYBACK` arka plan medya oynatımı; `POST_NOTIFICATIONS` opt-in FCM ve medya bildirimi; `ACCESS_NETWORK_STATE`/`ACCESS_WIFI_STATE` ağ eklentileri; `com.google.android.c2dm.permission.RECEIVE` FCM; `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` AndroidX iç alıcısı için vardır. Son alt izinlerin hangi native SDK tarafından eklendiği sürümlü birleşmiş manifestte ayrıca doğrulanır; kullanıcıya işlevsiz izin eklenmemelidir. Firebase otomatik bildirim kaydı varsayılan kapalıdır. iOS `Info.plist` yalnız kullanım sırasında konum açıklaması ve arka plan **ses** modu belirtir; konum arka plan modu yoktur. Üçüncü taraf paketler arasında `supabase_flutter`, `maplibre_gl`, `just_audio`, `geolocator`, `firebase_core`, `firebase_messaging` ve `sqflite` vardır. Firebase Analytics uygulama bağımlılığı eklenmedi; Firebase SDK'larının ve gerçek servis yapılandırmasının veri akışı mağaza formlarında ayrıca denetlenmelidir.

Saklama kararı için üç ayrı seçenek ürün/veri sorumlusuna sunulur: (A) paylaşım bitişinde koordinatı silme; (B) mevcut pilot sözleşmesindeki 24 saatlik teknik saklama; (C) kayıtlı iş gerekçesi ve açık kullanıcı metniyle daha uzun, en fazla sunucu ayarının izin verdiği 30 günlük süre. Veri azaltımı açısından öneri A'dır; bu bir politika kararı değildir. Paylaşım bitince yönetici erişimi saklama süresinden bağımsız kapanır. Koordinatsız rıza geçmişinin süresi ayrıca belirlenir; karar gelince sunucu ayarı, istemci süresi, geçmiş kayıt geçişi ve kullanıcı açıklaması birlikte değiştirilir.

## Yayın öncesi doldurulacak alanlar

- Veri sorumlusu/ticari unvan, iletişim ve destek adresi; doğrulanmış politika URL'si.
- Canlı Supabase proje bölgesi, kullanılan Auth yöntemi, mesaj/konum saklama süresi, hesap ve veri silme isteği akışı.
- Paket/harita/ses sağlayıcıları, lisans ve atıf metinleri, varsa IP ve indirme loglarının süresi.
- Play Data safety ve App Store App Privacy formunda gerçek yapılandırmayla eşleşen veri toplama/paylaşma/izleme cevapları.
- Çocuk hedef kitle kararı, ülkeler ve uygulanacak mevzuat incelemesi.
- Uygulama içi silme/hesap kapatma kullanıcı akışı ve mağaza inceleme hesabı gereksinimleri.

Bu alanlar tamamlanmadan metin yayımlanmaz; `tools/release_preflight.py` içindeki `privacy_store_declarations` kanıtı kabul edilmiş sayılmaz.
