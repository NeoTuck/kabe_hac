# Yerel kafile backend'i

Bu dizin geliştirme amaçlı Supabase şemasıdır. Canlı servis veya üretim credential'ı içermez.

## İsteğe bağlı yerel test

Docker yalnız Supabase'in yerel PostgreSQL servislerini çalıştıran geliştirme aracıdır. Mobil uygulamanın derlenmesi, kurulması veya çalışması Docker istemez. Bu komutlar atlanırsa SQL ve RLS testleri çalıştırılmış sayılmaz.

Docker uyumlu bir motor açıkken:

```sh
npx supabase start
npx supabase db reset
npx supabase test db
```

Şema; şirket/kafile üyeliği, süreli davet, kalıcı mesaj, duyuru, program, rota, rızaya bağlı konum paylaşımı ve cihaz bildirim tokenlarını içerir. RLS politikaları grup verisini sunucuda ayırır. Realtime kanalları `group:<uuid>` biçiminde ve private açılmalıdır.

Mobil uygulamaya yalnız Supabase publishable key konabilir. Secret/service-role anahtarı mobil uygulamaya veya bu depoya eklenmez. Gerçek push bildirimi için ayrıca APNs/FCM kaydı ve güvenilir server gönderimi gerekir.
