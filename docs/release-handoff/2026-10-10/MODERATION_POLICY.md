# Gerçek Kafile içerik politikası teslimi

Sunucu hattı `20261011110000_preposting_moderation.sql` ile hazırdır. Hiçbir gerçek
kural, yayın kararı veya kişi bu migrasyonda üretilmez. Testlerdeki QA işaretleri
yalnız disposable fixture'dır; üretime taşınmaz.

Veri/operasyon sorumlusu şu gerçek teslimi sağlamalıdır:

| Alan | Teslim |
| --- | --- |
| Koşul | Sunucunun `current` kullanım koşulu sürümü ve yasak içerik metni; hizmetin gerçek HTTPS belgesi. |
| Politika | Benzersiz sürüm, bu koşul sürümüne bağlı `terms_version`, gerçek HTTPS politika URL'si ve dosya byte'larının SHA-256 özeti. |
| Kurallar | 1–200 gerçek literal ifade, her biri 1–160 karakter. Yasak içerik politikasından türetilmiş, yanlış pozitifleri incelenmiş liste. Boş liste sohbeti açmaz. Regex veya SQL değildir. |
| İnsan incelemesi | Gerçek sorumlu/inceleyen, tarih, karar belgesi, yanlış pozitif düzeltme ve itiraz kanalı. Bunlar sunucu zamanının veya teknik hash'in yerini tutmaz. |
| İşletim | Yetkili moderatör, şikâyet müdahale süresi, destek iletişimi, rapor/audit saklama ve hesap silme ilişkisi. |

Yayın yalnız yetkili test projesindeki SQL/operatör yoluyla yapılır. Mobile
`authenticated` role kural tablosunu okuyamaz veya yazamaz. Service-role anahtarı
uygulamaya/Git'e eklenmez.

Atomik işlem sırası:

1. Transaction aç; gerçek güncel `service_terms` satırını `FOR UPDATE` kilitle.
2. Yeni politika sürümünü doğru `terms_version`, gerçek belge/hash ve kurallarla
   `current=false` olarak ekle. Aynı sürümün metin/rule/hash/zamanı değiştirilemez.
3. Eski current policy'yi kapat; yeni satırı current yap; transaction'ı commit et.
4. İki test hesabı/iki kafilede benign ve gerçek politikadan seçilmiş reddedilecek
   örnekleri, özel sohbet/duyuru/gövde güncellemesi, eski koşul/offline outbox,
   üyelik iptali ve şikâyet/engel/silme davranışlarını doğrula.

Filtre NFKC, küçük harf, boşluk ve belirtilen zero-width karakter normalizasyonuyla
literal alt dizi eşler; kaynak mesaj değişmez. Her dil, gizlenmiş ifade veya bağlam
için kusursuz tespit iddiası yoktur. Bu hat insan moderasyonunun yerine geçmez.
Yeni politika eski mesajları otomatik insan onaylı yapmaz. Kabul edilen yeni/güncellenen
mesajlarda yalnız teknik `moderation_policy_version` ve sunucu
`moderation_checked_at` kaydedilir; bunlar `approved` değildir.

Politika yoksa veya güncel koşulla eşleşmiyorsa yeni sohbet/duyuru yazması reddedilir.
Reddedilen metin mesaj/notification tablosuna eklenmez, hata içinde tekrar edilmez.
Outbox içerik reddini kalıcı `rejected` olarak saklar; kullanıcı metni değiştirerek
yeni mesaj yazabilir veya kendi yerel kaydını kaldırabilir. Politika geçici olarak
kullanılamıyorsa gönderim retryable kalır. Trusted moderasyon/hesap silme işlemleri
ve mevcut rapor/engel RLS altyapısı korunur.

Bu teslim ve gerçek servis/cihaz kabulü olmadan `LIVE_SERVICE_ACCEPTED` açılmaz.
