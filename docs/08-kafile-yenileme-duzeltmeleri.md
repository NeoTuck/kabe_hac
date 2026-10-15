# Kafile yenileme ve hesap geçişi düzeltmeleri

7 Ekim 2026 incelemesinde iki davranış sorunu bulundu. Kafile ayrıntısı sunucu listesini mesaj kuyruğu gönderilmeden önce alıyordu; Realtime bildirimi gelmediğinde gönderilmiş mesaj bekleyenlerden çıkıyor fakat sohbet listesine bir sonraki yenilemeye kadar girmiyordu. Yenileme artık önce hesap bağlı kuyruğu gönderir, ardından sunucu listesini okur. Gönderim başarısızsa yerel kayıt başarısız durumuyla görünür kalır. Teslim teyidi ve üyelik kontrolleri mevcut repository içinde korunur.

Hesap değişirken eski kafile listesi isteğinin hatası yeni hesabın listesini temizleyebiliyordu. Eski ayrıntı isteğinin hatası da oturum değişimi uyarısını ezebiliyordu. Her iki hata kolunda istek sahibi hesabın hâlâ aktif olduğu kontrol edilir. Asenkron kuyruk işlemi ile ayrıntı okuması arasındaki hesap/ekran kontrolleri eski oturumla yeni istek başlatılmasını engeller.

Mevcut rehber, ses, sayaç, gezi, paket, güvenlik, kafile ve ayar özellikleri korunur. SQLite sürümü ve veri şeması değişmez. İçerik onayı veya canlı hizmet yapılandırması eklenmez.

## Regresyon kapsamı

`test/group_refresh_test.dart` dört senaryo ekler: Realtime bildirimi olmadan gönderilmiş mesaj görünürlüğü, başarısız gönderimin görünür kalması, eski hesap liste hatasının yeni listeyi bozmaması ve eski ayrıntı hatasının oturum değişimi uyarısını ezmemesi. Bunlar test repository ve yerel kuyruk fixture'larıyla widget davranışını sınar; gerçek Supabase veya fiziksel cihaz kabulü değildir.

## Doğrulama durumu

- `git diff --check`: geçti.
- Paketli teknik ses: FFmpeg/ffprobe çözümleme, sonlu PCM, sessizlik ve kırpılma kontrolü geçti. Gerçek cihaz işitsel testi değildir.
- Flutter 3.47.6 / Dart 3.13.5: 49 Dart dosyası biçim kontrolü temiz, `flutter analyze --no-pub` temiz; tüm 91 Flutter testi geçti. Yerel SQLite testlerinde sistemdeki libsqlite3.so.0, yalnız test oturumu için ayrı dizindeki libsqlite3.so bağlantısıyla yüklendi.
- Dört yeni test düzeltmede geçer. Eski uygulama kodunda görünürlük ve iki hesap geçişi testi başarısız; başarısız gönderimi koruma testi geçer. Regresyonun eski davranışı yakaladığı doğrulandı.
- `6d02270` için GitHub CI 37669070487 başarılı: Flutter/Android, iOS debug/no-codesign ve database işleri. Fiziksel cihaz kabulü değildir.
- Bu değişiklik için gerçek Android/iPhone ve Maestro cihaz testi henüz çalıştırılmadı.
