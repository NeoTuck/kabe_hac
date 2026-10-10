# Hesap silme işlemi (yetkili sunucu operasyonu)

`account_deletion_requests` yalnız isteği kaydeder. `20261009160000_account_deletion_operation.sql` migrasyonu sunucuya hazırlık RPC'si ve kalıcı işlem kaydı ekler. İstemciye service-role anahtarı verilmez. Bu dosyadaki işlem gerçek test projesinde uygulanıp iki hesapla kabul edilmeden canlı hizmet kapalı kalır.

## Operatör adımları

1. Ürün/veri sorumlusu istek sahibinin kimliğini, uygulanacak veri saklama kararını, sahiplik devrini ve kullanıcıya sonuç bildirme kanalını onaylar. Şikâyet veya hukuki saklama gerekiyorsa bunu ayrıca belgeler; bu araç kendiliğinden hukuki karar vermez.
2. Migrasyonu yetkili projeye uygula. Sırrı yalnız operatörün gizli ortamında `SUPABASE_URL` ve `SUPABASE_SERVICE_ROLE_KEY` olarak ayarla. Bu değerleri komut satırına, Git'e veya istemciye yazma.
3. `node supabase/operations/process_account_deletion.mjs --dry-run REQUEST_UUID` ile istek durumu ve bağlı ortak kayıt sayılarını gör. Kafile/şirket kurucusu, davet, duyuru, program veya rota yazarı ya da şikâyet kaydındaki kişi için işlem durur. Bu içerikleri silme/devretme/saklama kararı ve ayrıca güvenli uygulaması gerekir.
4. Engel yoksa `node supabase/operations/process_account_deletion.mjs --execute REQUEST_UUID` çalıştır. Sunucu RPC'si isteği `processing` yapar, konumu/bildirimi tekrar iptal eder ve işlem kaydı açar. Araç ardından Supabase Auth Admin API ile hesabı siler. Auth'a `on delete cascade` bağlı kişisel/mesaj verileri silinir. Son olarak işlem kaydında kullanıcı kimliği temizlenir ve `deleted` yazılır.
5. Ağ kesintisi Auth silmesinden sonra olduysa `--reconcile REQUEST_UUID` kullan. Araç yalnız önceden hazırlanmış işlem kaydını kabul eder ve Auth kullanıcısı hâlâ varsa `deleted` sonucunu yazmaz. Auth kullanıcı hâlâ varsa operatör olayı incelemeli; `--execute` ikinci kez çalışmaz.
6. İşlem kaydının `deleted` olduğunu, Auth kullanıcısının bulunmadığını, bağlı kayıtların silindiğini ve kullanıcıya ayrı kanaldan sonuç bildirildiğini doğrula. Kimlik silindikten sonra kullanıcı uygulamada tamamlandı durumunu göremez. Bu sonuç bildirme sürecinin sahibi ve saklama süresi ürün kararıdır.

## Sınırlar

- `processing` aşamasındaki istek çalıştırma sırasında hata alırsa otomatik yeniden silme yoktur; operatör incelemesi gerekir. Yeni şikâyet gibi yarışan kayıtlar Auth silmeyi veritabanında durdurur. Bu durumda önce moderasyon/saklama kararını belgeleyin; yalnız yeniden `--execute` denemesi yapılmaz.
- Şikâyet bildiren, şikâyet edilen mesajı gönderen veya özel mesajın alıcısı olan hesap silinirken şikâyet kaydı kaskadla kaybolacaksa Auth silme tetikleyicisi işlemi reddeder. Başvuru, şikâyet ve audit için gerçek saklama politikası olmadan bu engel kaldırılmaz.
- Sahiplik alanına yeni kayıt/atama, silme isteğinden sonra veritabanı tetikleyicisiyle de reddedilir; bu denetim `create_personal_group` gibi `SECURITY DEFINER` işlemleri de kapsar.
- Ortak kayıtlar için blokaj, `auth.users` üzerindeki kısıtlayıcı yabancı anahtarlarla uyumludur. Bu araç onları otomatik silmez veya başka üyeye devretmez.
- `account_deletion_operations` yalnız sunucu rolüne açıktır. Tamamlanmada `user_id` alanı boşaltılır; `request_id` ve zaman damgasının ne kadar saklanacağına ürün/veri sorumlusu karar vermelidir.
- Canlı projede çalışma, gerçek hukuki uyum, Auth/Storage dışındaki üçüncü taraf sistemlerin silinmesi veya kullanıcıya bildirim bu kodla kanıtlanmış değildir.
