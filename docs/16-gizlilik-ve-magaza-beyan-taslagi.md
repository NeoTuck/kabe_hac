# Gizlilik ve mağaza beyanı çalışma taslağı

8 Ekim 2026. Bu metin yayınlanmış gizlilik politikası veya App Store/Play Console beyanı değildir. Ürün sorumlusu, canlı servis ve hukuk/gizlilik incelemesiyle tamamlanmalıdır. Uygulama sürümü `0.1.0+1` teknik pilottur.

## Kodda bugün görülen veri akışları

| Veri/izin | Yerel davranış | Sunucu/mağaza beyanında açık karar |
| --- | --- | --- |
| Rehber ve prova ilerlemesi, sayaç, favori, tema | `sqflite` ile cihazda tutulur; prova gerçek rehberden ayrıdır. | Yedekleme, cihaz aktarımı ve silme yordamı uygulama sahibi tarafından doğrulanmalı. |
| İsteğe bağlı paket | Yapılandırılırsa HTTPS katalog/dosya isteği ve doğrulanmış yerel dosya saklama vardır. Mevcut derlemede gerçek sunucu/güven kökü yok. | Sağlayıcı, sunucu log/IP saklama, lisans/atıf ve silme politikası belirlenmeli. |
| Ses | Paketli sentetik teknik kayıt veya onaylı paket dosyası cihazda çalınır; Android medya servisi ve iOS arka plan ses modu kullanılır. Mikrofon kaydı kodu yok. | Gerçek ses sahipliği ve izinleri gelince beyan güncellenmeli. |
| Kafile hesabı ve mesaj | URL/publishable key verildiğinde Supabase Auth/mesaj/üyelik adaptörü devreye girer; çevrimdışı mesaj outbox cihazda kalabilir. Varsayılan yapıda canlı servis yok. | Veri sorumlusu, barındırma bölgesi, saklama, erişim, hesap/veri silme ve alt işleyenler gerçek proje üzerinden kararlaştırılmalı. |
| Konum | Yalnız süreli/iptal edilebilir yerel rıza modeli var. GPS izin/okuma/gönderim akışı yok; manifestte konum izni yok. | Gelecek entegrasyon için ayrı açık rıza, izin reddi, sunucu saklama ve gizlilik beyanı gerekir. Şimdiden konum toplandığı iddia edilmez. |
| Bildirim | APNs/FCM token ve teslim entegrasyonu yok. | İzin, token yaşam döngüsü, kilit ekranı içeriği ve sağlayıcı beyanı entegrasyonla hazırlanmalı. |

Android manifestinde internet, wake lock ve foreground media playback izinleri bulunur; mikrofon/konum izni tanımlı değildir. iOS `Info.plist` arka plan ses modunu belirtir. Üçüncü taraf paketler arasında `supabase_flutter`, `maplibre_gl`, `just_audio` ve `sqflite` vardır; bunların gerçek veri kullanımı uygulama yapılandırmasıyla yeniden denetlenmelidir. Analitik/izleme SDK'sı doğrudan uygulama bağımlılıklarında görülmedi; bu ifade tüm transitive ağ trafiği veya ilerideki dağıtım için garanti değildir.

## Yayın öncesi doldurulacak alanlar

- Veri sorumlusu/ticari unvan, iletişim ve destek adresi; doğrulanmış politika URL'si.
- Canlı Supabase proje bölgesi, kullanılan Auth yöntemi, mesaj/konum saklama süresi, hesap ve veri silme isteği akışı.
- Paket/harita/ses sağlayıcıları, lisans ve atıf metinleri, varsa IP ve indirme loglarının süresi.
- Play Data safety ve App Store App Privacy formunda gerçek yapılandırmayla eşleşen veri toplama/paylaşma/izleme cevapları.
- Çocuk hedef kitle kararı, ülkeler ve uygulanacak mevzuat incelemesi.
- Uygulama içi silme/hesap kapatma kullanıcı akışı ve mağaza inceleme hesabı gereksinimleri.

Bu alanlar tamamlanmadan metin yayımlanmaz; `tools/release_preflight.py` içindeki `privacy_store_declarations` kanıtı kabul edilmiş sayılmaz.
