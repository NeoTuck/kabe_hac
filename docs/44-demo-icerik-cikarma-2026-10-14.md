# Kullanıcı uygulamasından demo içerik çıkarma — 14 Ekim 2026

## Kapsam

Kullanıcı kararıyla 53 uzman onaysız Umre/Hac metni, 1 taslak dua ve 54 sentetik taslak ses kullanıcı Flutter paketinden çıkarıldı. Dosyalar kaynak, sürüm ve hak incelemesi için depoda kalır; uygulamanın varlık listesinde değildir. Teknik `teknik_demo.m4a` da paketlenmez. OSM/Geofabrik kaynaklı isteğe bağlı yer ve harita paketleri gerçek kaynak kayıtları olarak ayrı kalır; saha doğruluğu veya güvenli rota onayı verilmez.

## Uygulama davranışı

- Varsayılan Umre/Hac kataloğu boş; onaylı içerik yokluğu ana ekranda açıkça görünür. Rehber/prova girişi ve eski taslak oturuma devam düğmesi gösterilmez. SQLite kişisel oturumlar ve favoriler silinmez.
- Hazırlık ekranı `0` onaylı adımı ve sesi hazır gibi göstermez. Taslak sesi dinletme açıklamaları kaldırıldı.
- Daha önce indirilmiş taslak içerik paketi yüklenmez. Güvenilir paket manifesti/hash denetimine ek olarak her adım, dua ve sesin `approved` durumu aranır. Sese ait yerel paket dosyası yine doğrulanır.
- İlk onaylı içerik dilimi sabit adım kimlikleri ve sırası içinde kısmi katalog olabilir. Kısmi Umre/Hac kataloğu tam yolculuk hazırlığı sayılmaz; Hac profil akışı tüm adımlar tamamlanmadan doğrulanmış sayılmaz.
- Kullanıcı APK denetimi teknik sesi, `draft-v2` seslerini ve onaysız dinî katalogları reddeder.

## Yerel kanıt

- `flutter analyze --no-pub`: 0 sorun.
- `flutter test --no-pub`: uzak `147d94d` üzerine yeniden tabanlanmış birleşik kodda 255 test geçti. Boş kullanıcı kataloğu, eski taslak paket reddi, kısmi onaylı paket ve eski kişisel kaydın korunması sınanır.
- `flutter build bundle --no-pub`: başarılı. `build/flutter_assets` içinde yalnız `package_defaults.v1.json` ve `safety_catalog.v1.json` içerik varlıkları bulunur; rehber JSON ve ses dosyası bulunmaz. Bu yerel Flutter varlık denetimidir, imzalı APK/IPA incelemesi değildir.
- Python QA: 86 test geçti. Lisans envanteri yeniden üretildi (87 depo varlığı, 150 Dart paketi); taslak metin ve sesler `excluded_from_user_build` olarak işaretlendi. Yerel Mac geçici dizinindeki üst yol sembolik bağı yüzünden yanlış alarm veren iki kanıt kontrolü yalnız verilen depo/kanıt kökü içindeki bileşenleri denetleyecek şekilde düzeltildi.

## Açık kapılar

Dinî/dil uzmanı kararı, ses sahibi ve dağıtım hakkı, gerçek test servisi, saha/cihaz kabulü ve üretim imzası yoktur. Taslak dosyalarda bulunan kaynak kaydı uzman onayı değildir. İlk gerçek onaylı paketin derleme/cihaz testleri ile mağaza değerlendirmesi ayrıca gerekir. Önceki native ses ve ekran sonuçları taslak içerikli eski kod içindir.
