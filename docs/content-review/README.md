# Umre/Hac editöryal çalışma tabloları

CSV dosyaları mevcut sabit kimliklerden üretilen UTF-8 (BOM) çalışma tablolarıdır. Umre 18, Hac 35 satırdır. Dinî açıklama yazılmamış; onay verilmemiştir. Uygulama bu dosyaları yüklemez.

Her satırda mevcut kimlik, sıra, grup, başlık ve taslak durum korunur. Metin, kaynak/konum, kullanım hakkı ve gerçek inceleyen/tarih alanları uzmanla doldurulur. Dua, ses kayıtları ve Hac profil matrisi ayrı şema girdileridir; tek bir CSV satırı onların kabulünü sağlamaz. Onaylı yayın kataloğuna aktarım, mevcut Dart içerik doğrulayıcısı ve testler üzerinden ayrı yapılmalıdır.

`tools/content_audit.py` kaynak envanterlerin tip/sayı/benzersiz ID/sıralamasını denetler. `--export` tabloları üretir, mevcut çalışma tablolarını ezmez; uzman düzenlemelerini korur. Yeniden dışa aktarmadan önce mevcut değişiklikleri inceleyip ayrı dosyada koruyun. Kaynak envanterdeki `status=approved` sayısı tek başına uzman onayı kanıtı değildir.

## Prova sayacı ve profil kabul listesi

İsteğe bağlı 2D prova, rehber envanterindeki aynı sabit kimlikleri kullanır; ayrı dinî metin kopyası yoktur. Sayaç yalnız ilgili adım gerçekten `approved` olduğunda ve envanterde `counterTarget` (1–100 arası tamsayı) bulunduğunda açılır. Bu alanı bir geliştirici tahmin ederek doldurmaz. Uzman, hedefi ve neyin bir sayım olduğu açıklamasını metin sürümüyle birlikte onaylamalıdır:

| Adım | Bağlantı | Uzman kararı gereken veri |
| --- | --- | --- |
| `U06.2` | Tavaf | Manuel tur hedefi, başlangıç ve bitiş tarifi, özel durumlar |
| `U09.2` | Sa‘y | Manuel geçiş hedefi, Safa/Merve yön ve sayım tarifi |
| `H06.3`, `H09.2` | Cemarat | Hac profili, gün/hedef bağlamı ve her adımın manuel hedefi |

Hac için her 35 adımda Temettü, İfrad ve Kıran uygulanabilirliği ayrıca incelenir. Taslak profile göre otomatik filtreleme yapılmaz. Dua Arapçası, telaffuzu, Türkçe anlamı ve her ses kaydının metin kimliği/sürümü, sahipliği ve yeniden dağıtım hakkı ayrı kabul girdileridir. `tools/release_preflight.py` eksik onay alanlarında `blocked` verir; bu teknik alan denetimi uzman incelemesinin yerine geçmez.

## OSM yer adı incelemesi

`2026-10-09-kritik-osm-yer-incelemesi.csv`, kaynak OSM kataloğundaki 1.284 sağlık, eczane, polis, ulaşım ve dinî mekân kaydını öncelikli insan incelemesine ayırır. `source_name` mevcut ham alanı korur; boş `proposed_turkish_name`, `reviewer` ve `reviewed_at` alanları gerçek editör tarafından doldurulur. Bu tablo uygulamaya yüklenmez ve herhangi bir yeri sahada doğrulanmış yapmaz. Kaynak değişirse `tools/build_poi_review_queue.py` yeniden üretilebilir; önce insan düzenlemeleri ayrı saklanmalıdır.
