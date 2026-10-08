# Gizlilik ve mağaza beyanı çalışma taslağı

9 Ekim 2026. Bu metin yayınlanmış gizlilik politikası veya App Store/Play Console beyanı değildir. Ürün sorumlusu, canlı servis ve hukuk/gizlilik incelemesiyle tamamlanmalıdır. Uygulama sürümü `0.1.0+1` teknik pilottur.

## Kodda bugün görülen veri akışları

| Veri/izin | Yerel davranış | Sunucu/mağaza beyanında açık karar |
| --- | --- | --- |
| Rehber ve prova ilerlemesi, sayaç, favori, tema | `sqflite` ile cihazda tutulur; prova gerçek rehberden ayrıdır. | Yedekleme, cihaz aktarımı ve silme yordamı uygulama sahibi tarafından doğrulanmalı. |
| İsteğe bağlı paket | Yapılandırılırsa HTTPS katalog/dosya isteği ve doğrulanmış yerel dosya saklama vardır. Mevcut derlemede gerçek sunucu/güven kökü yok. | Sağlayıcı, sunucu log/IP saklama, lisans/atıf ve silme politikası belirlenmeli. |
| Ses | Onaylı paket dosyası varsa cihazda çalınır; Android medya servisi ve iOS arka plan ses modu kullanılır. Sentetik teknik kayıt APK/IPA varlığı değildir ve yalnız QA fixture'ıdır. Mikrofon kaydı kodu yok. | Gerçek ses sahipliği ve izinleri gelince beyan güncellenmeli. |
| Kafile hesabı ve mesaj | URL/publishable key verildiğinde Supabase Auth/mesaj/üyelik adaptörü devreye girer; çevrimdışı mesaj outbox cihazda kalabilir. Varsayılan yapıda canlı servis yok. | Veri sorumlusu, barındırma bölgesi, saklama, erişim, hesap/veri silme ve alt işleyenler gerçek proje üzerinden kararlaştırılmalı. |
| Konum | Android/iOS yalnız kullanım sırasında konum izni tanımlı. Kafile hesabı ve açık onay varsa bir GPS ölçümü alınır, Supabase'e gönderilir ve 15 dakikalık paylaşım kaydı açılır; otomatik arka plan takibi yok. Durdurma yerel kaydı hemen kapatır, sunucu iptali ağ yoksa doğrulanamaz ve UI bunu belirtir. Varsayılan derlemede canlı Supabase yoktur. | Alıcı rolü, sunucu saklama ve silme, izin reddi, ağ kesintisi ve gerçek cihaz kabulü gerekli. |
| Bildirim | Firebase projesi derleme zamanı yapılandırılmışsa kullanıcı izniyle FCM token'ı Supabase'e kaydedilir; yenilemede eski token kaldırılır, çıkışta bu cihazın token'ı silinir. Varsayılan derlemede yapılandırma yok ve izin istemi yok. Bildirime dokunma yalnız doğrulanmış kafile üyeliğine gider. | APNs/FCM kimlikleri, sunucu göndericisi, anonim kilit ekranı şablonu ve iki cihazlı teslim kabulü gerekli. |

Android manifestinde internet, wake lock, foreground media playback ve coarse/fine konum izinleri vardır. Firebase otomatik bildirim kaydı varsayılan kapalıdır; son birleşmiş manifest ayrıca incelenmelidir. iOS `Info.plist` yalnız kullanım sırasında konum açıklaması ve arka plan **ses** modu belirtir; konum arka plan modu yoktur. Üçüncü taraf paketler arasında `supabase_flutter`, `maplibre_gl`, `just_audio`, `geolocator`, `firebase_core`, `firebase_messaging` ve `sqflite` vardır. Firebase Analytics uygulama bağımlılığı eklenmedi; Firebase SDK'larının ve gerçek servis yapılandırmasının veri akışı mağaza formlarında ayrıca denetlenmelidir.

## Yayın öncesi doldurulacak alanlar

- Veri sorumlusu/ticari unvan, iletişim ve destek adresi; doğrulanmış politika URL'si.
- Canlı Supabase proje bölgesi, kullanılan Auth yöntemi, mesaj/konum saklama süresi, hesap ve veri silme isteği akışı.
- Paket/harita/ses sağlayıcıları, lisans ve atıf metinleri, varsa IP ve indirme loglarının süresi.
- Play Data safety ve App Store App Privacy formunda gerçek yapılandırmayla eşleşen veri toplama/paylaşma/izleme cevapları.
- Çocuk hedef kitle kararı, ülkeler ve uygulanacak mevzuat incelemesi.
- Uygulama içi silme/hesap kapatma kullanıcı akışı ve mağaza inceleme hesabı gereksinimleri.

Bu alanlar tamamlanmadan metin yayımlanmaz; `tools/release_preflight.py` içindeki `privacy_store_declarations` kanıtı kabul edilmiş sayılmaz.
