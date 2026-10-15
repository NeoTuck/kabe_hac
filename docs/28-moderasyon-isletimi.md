# Şikâyet inceleme işletimi — teknik temel

`20261009161000_moderation_operations.sql` yalnız sunucu tarafında iki RPC ekler.
`list_moderation_reports` açık şikâyetleri durumuna göre (`pending` veya
`reviewing`) ayrı kuyruklarda, en eski önce ve sayfa başına en çok 100 kayıt halinde verir.
İncelemeye alınmış eski kayıtlar yeni başvuruları gizlemez. Son kaydın
`reported_at` ve `report_id` değerleriyle sonraki sayfa istenir; iki değer birlikte
verilmeli ve seçilen kuyruktaki aynı kaydı göstermelidir. Eksik, hatalı veya
durumu değişmiş imleç hata verir: kuyruğun ilk sayfasından yeniden başlanır.
Son sayfa boş veya istenen `batch_size` değerinden kısa olana kadar devam edilir.
Sayfalar arasında yeni şikâyet ya da durum değişimi olursa bu işlem tek bir
veritabanı anlık görüntüsü değildir; operatör kuyruğu yeniden taramalıdır.
`record_moderation_review` şu geçişleri
kilitli işlem içinde yapar ve ayrı bir audit satırı yazar:

| Eski durum | İşlem kodu | Yeni durum | Anlamı |
| --- | --- | --- | --- |
| `pending` | `claimed` | `reviewing` | Sorumlu incelemeye aldı. |
| `reviewing` | `escalated` | `reviewing` | Dış/üst incelemeye aktarıldı. |
| `reviewing` | `no_violation` | `resolved` | İnsan değerlendirmesinde ihlal bulunmadı. |
| `reviewing` | `handled_offline` | `resolved` | Ayrı yürütülen işlem operatörce teyit edildi. |

RPC'ler `service_role` dışında çalışmaz. Uygulama istemcisine veya kullanıcı
cihazına servis anahtarı konmaz. Yetkili görevli sunucu ortamından, güvenli
sır yöneticisinden alınan kimlikle RPC'yi çağırır. `operator_label` gerçek
görevli/iş emri kimliği, `note` kısa karar gerekçesi olmalıdır. Sır, telefon,
tam mesaj kopyası veya gereksiz kişisel veri nota yazılmamalıdır. Operatör
etiketi çağıran servis hesabından kriptografik olarak türetilmez; gerçek kişi
eşleştirmesi işletim kayıtlarında ayrıca tutulmalıdır. Paylaşılan servis
anahtarıyla bireysel yetki ve sorumluluk kendiliğinden sağlanmaz.

Örnek çağrı sözleşmesi (URL/anahtar gerçek ortamda sır olarak sağlanır):

```http
POST /rest/v1/rpc/list_moderation_reports
Authorization: Bearer <server-side service role secret>
apikey: <server-side service role secret>
Content-Type: application/json

{"batch_size":50,"queue_status":"pending"}
```

Yanıtın son satırı örneğin `reported_at=2026-10-09T10:00:00Z` ve
`report_id=90000000-0000-0000-0000-000000000006` ise sonraki çağrı:

```json
{"batch_size":50,"queue_status":"pending","after_reported_at":"2026-10-09T10:00:00Z","after_report_id":"90000000-0000-0000-0000-000000000006"}
```

```http
POST /rest/v1/rpc/record_moderation_review
Authorization: Bearer <server-side service role secret>
apikey: <server-side service role secret>
Content-Type: application/json

{"target_report_id":"<uuid>","expected_status":"pending","action_code":"claimed","operator_label":"<operator or ticket>","note":"<short reason>"}
```

`false`, kayıt yok veya başka görevli durumu değiştirmiş demektir; kuyruğu
yeniden oku. Hata dönerse durumun değiştiğini varsayma. Mesaj gizleme, hesap
kısıtlama, kullanıcıya dönüş ve hukuki saklama kararı bu RPC'lerin kapsamında
değildir. `handled_offline` ancak ayrı işlemin kanıtı varsa kullanılır.

## Canlı kabul için açık işler

- Veri sorumlusu moderasyon görevlisini, hedef yanıt süresini, yaptırım
  yönergesini, itiraz/destek kanalını ve şikâyet ile audit saklama süresini
  kararlaştırmalı. Bu kararlar yokken canlı Kafile kapalı kalır.
- Gerçek Supabase test projesinde en az iki hesap/iki kafile ile yetkisiz RPC
  erişimi, kuyruk, eşzamanlı inceleme, kullanıcıya dönüş ve saklama akışı
  denenmeli. Bu migration yerel veya canlı projeye uygulanmış sayılmaz.
- `supabase/tests/database/moderation_operations.test.sql` bu geçişler için
  pgTAP senaryosu ekler. Bu görevde kullanıcının önceki test çalıştırmama
  tercihine göre çalıştırılmadı; başarılı test kanıtı değildir.
