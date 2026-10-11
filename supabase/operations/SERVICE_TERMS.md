# Sürümlü Kafile kullanım koşulları

Canlı kabul kapısı kapalı kalır. Migrasyon hiçbir hukuki metin veya gerçek kullanıcı kabulü üretmez.

Yetkili veri sorumlusu: tam metin, sürüm kimliği, gerçek HTTPS belge URL'si,
UTF-8 belge SHA-256 özeti, yürürlük kararı ve saklama/silme politikası teslim eder.
Operatör tek transaction içinde eski `current` satırını false yapar ve **yeni**
metni/sürümü `current=true` ile ekler. Aynı sürümün metni/URL/hash/tarihi
sonradan değiştirilemez. İstemci bu tabloya yazamaz.

`current_service_terms()` yalnız sunucunun güncel sürümünü ve oturumun kabul
zamanını verir. `accept_service_terms(displayed_version)` gösterilen sürümü
sunucunun sürümüyle eşler, kimliği Auth'tan ve zamanı sunucudan alır.
Tekrar kabul aynı satırı/tarihi korur; eski sürüm ya da silme bekleyen hesap reddedilir.
Kabul tablosuna doğrudan istemci INSERT/UPDATE/DELETE yetkisi verilmez.

Doğrudan tablo ve SECURITY DEFINER grup/davet yazmaları trigger ile korunur;
RLS üyelik/kimlik denetimi ayrıca korunur. Eski outbox yeni sürüm kabulünden
önce sunucuda reddedilir. Güvenlik işlemleri (şikâyet, engelleme, token silme,
konum durdurma, hesap silme) yeni kabul olmadan kullanılabilir. Silinen Auth
hesabının kabul kayıtları cascade ile silinir. Hukuken gereken ayrı saklama
politikası varsa gerçek karar olmadan bu davranış değiştirilmez.

Test: `service_terms.test.sql` yalnız rollback edilen sahte fixture kullanır;
mevcut RLS/moderasyon/silme testlerinin kabul fixture'ları kullanıcı varlığı veya
canlı seed değildir. Canlı testte iki hesap/iki kafile, sürüm yükseltmesi,
üyelik iptali, çevrimdışı outbox, konum/token iptali ve hesap silme sonrasını
kanıtla. SQL fixture sonucu gerçek Supabase/Auth/Realtime kabulü değildir.
