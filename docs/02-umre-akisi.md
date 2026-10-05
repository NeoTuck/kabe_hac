# Umre akışı ve manuel sayaç — uygulanan ikinci dilim

> Bu belge önceki dilimin durumunu anlatır. Sabit kimlikler ve v4 migrasyonu için güncel [ana yapı belgesine](02-ana-yapi.md) bakın.

- 18 başlık, kaynak plandaki U01–U10 grup sayılarına göre sürümlü JSON'da tanımlıdır. Başlıklar ibadet talimatı sayılmaz; açıklama, dua ve gerçek ses kaydı inceleme bekliyor.
- İçerik doğrulayıcı sıra/kimlik tekrarını, bilinmeyen grubu ve eksik yayın onayını reddeder. `draft-` kimlikleri geçicidir; kesin U/H kimliklerine geçişte kayıt migrasyonu gerekir.
- Öğrenme ve yolculuk ayrı SQLite oturumlarıdır. Yeni yolculuk yeni kayıt açar; eski kayıt silinmez. Son açılan başlık ve kişisel işaretler saklanır.
- Tavaf ve sa‘y sayaçları ayrı anahtarlarla tutulur. +1 en fazla 7'ye çıkar, geri al bir azaltır, sıfırlama ekranda onay ister. Her eylem transaction içinde bir token ile kaydedilir; aynı token tekrar sayılmaz.
- Sayaç, ses veya sonraki başlığa geçiş adımı otomatik işaretlemez. Kullanıcı işareti ayrı eylemdir.
- Eski v1 teknik demo kaydı v3 şemasına geçişte korunur. Test, uygulama kaydı kapatılıp yeniden açıldıktan sonra konum ve sayaç değerlerini doğrular.

## Sonraki teknik işler

- Kaynaklı ve onaylı metin/ses geldiğinde içerik kimliği migrasyonu ve kullanıcıya açık sürüm uyumluluğu.
- Tek konuşma kanalı, arka plan/çağrı/kulaklık davranışı ve indirilir ses paketleri.
- Hac tür/gün/güzergâh matrisi ve Cemarat gün/hedef sayaçları.
- Android SDK ve tam Xcode kurulumundan sonra iki platformda gerçek cihaz doğrulaması.
