# Backend doğrulaması

Tercih edilen tam test: tüm migrasyonları yalnız ayrı test projesine/yerel Supabase'e uygulayıp `supabase test db` çalıştır. Test dosyası transaction sonunda rollback yapar. Üretim veritabanında test fixture'ı oluşturma.

## İsteğe bağlı bağımsız SQL regresyon testi

Supabase/Docker olmadan PGlite (WASM PostgreSQL) ve pgTAP 1.3.2 kurulma SQL'i ile sütun izinleri/RLS politikaları test edilebilir. `standalone/bootstrap.sql` yalnız minimal Auth kullanıcı tablosu, JWT kullanıcı kimliği fonksiyonu ve Realtime konu fonksiyonu sağlar. Gerçek Auth, HTTP API, Realtime sunucusu, mobil senkronizasyon veya push teslimi kanıtlanmaz.

Node.js hazırken araç bağımlılığını uygulama deposu dışında kur:

```sh
npm install --prefix /tmp/kabe-rls-tools --no-save @electric-sql/pglite@0.5.8
NODE_PATH=/tmp/kabe-rls-tools/node_modules PGTAP_SQL=/absolute/path/pgtap--1.3.2.sql node supabase/tests/standalone/run.cjs
```

`PGTAP_SQL`, resmi pgTAP dağıtımı veya işletim sisteminin pgTAP paketindeki kurulma SQL'idir (Ubuntu paketi: `postgresql-16-pgtap`). Uygulama bağımlılığı değildir. `--baseline` yalnız ilk migrasyonu uygular; yeni güvenlik regresyonlarının eski şemada başarısız olması beklenir. Her çalışma ayrı, geçici bellekte veritabanı kurar; test başarısızsa çıkış kodu 1 olur.

Senaryolar: grup izolasyonu, rehbere özel mesaj, mesaj kimlik/alıcı/tür/grup değişikliklerinin engellenmesi, izinli metin düzenlemesi, üyelik iptali, konum rızasının uzatılamaması, durdurma/süre/saklama süresi/üyelik sonrası erişim ve gönderim engeli.
