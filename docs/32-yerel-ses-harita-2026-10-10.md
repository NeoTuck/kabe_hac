# Yerel ses ve harita sağlamlaştırması — 10 Ekim 2026

Kullanıcı CI/workflow beklenmeden yerel geliştirme ve ses/harita kontrolü istedi. Başlangıç `55bfe86`, dal `codex/mvp1-pilot`; workflow değiştirilmedi ve CI sonucu bu turun kabulü olarak kullanılmadı.

## Kullanıcıya dönük düzeltme

Paket ekranı kurulu paketleri göstermeden önce ağ kataloğunu bekliyordu. Yerel liste ve katalog yüklemesi ayrıldı. Kurulu haritalar hemen görünür ve ağ isteği sürerken yönetilebilir. Silme, geri dönüş ve başarılı indirme sonrası yalnız yerel kayıtlar yenilenir; fazladan katalog isteği yapılmaz. Katalog yenileme yinelenmez, indirme sırasında işlem kilidi korunur.

Regresyon: katalog isteği tamamlanmadan kurulu Mekke haritası görünür; kullanıcı onayıyla silinir ve katalog isteği hâlâ tek kalır. Geç gelen katalog yanıtı silinen paketi kurulu listeye geri getirmez. Paket ekranı 5/5, tüm yerel Flutter testleri **206/206** geçti. Flutter 3.47.6/Dart 3.13.5 format ve analiz temiz. İlk tam testte Linux `libsqlite3.so` yükleme adı eksikti; mevcut sistem SQLite kütüphanesi yalnız bu oturum için bağlandıktan sonra tam test geçti. Uygulama SQLite kodu değiştirilmedi.

## Gerçek medya kontrolleri

- 53 adım anlatımı + telbiyenin Türkçe anlamı: **54/54 paketli sentetik taslak**. Adım/ses kimliği, metin sürümü, katalog SHA-256, AAC tek ses akışı ve tam PCM çözümleme doğrulandı. Sessizlik/clipping yok; ilk/son 100 ms sınır kontrolü 54/54 sessiz. Toplam yaklaşık **15,05 dakika / 7,45 MB**. Süreler ffprobe ölçümüdür, özgün kayıt makbuzu veya insan dinleme onayı değildir.
- Yerelde Flutter debug **Linux varlık paketi** oluşturuldu: 54 sesin paket içindeki hash'i eşleşti; teknik QA sesi pakete girmedi. Bu bir Android APK/iPhone IPA veya native ses kabulü değildir.
- Üç gerçek harita/gezi paketi: 11 dosyanın yerel ve gerçek HTTPS indirme kaynağındaki boyut/hash'i eşleşti. Mekke 1.308.043 bayt / 40.971 yol-bina geometrisi; Medine 915.467 bayt / 30.291 geometri; yer paketi 1.153.891 bayt / **2.928 POI**. Gzip/GeoJSON çözümlemesi ve boyut sınırları doğrulandı; kaynak/lisans veri kontrolleri 4/4 geçti.
- Yer kayıtları: 437 yeme/içme, 183 sağlık, 1.145 konaklama, 99 eczane, 32 ulaşım, 944 dinî/tarihî yer, 62 tuvalet, 26 polis kaynak kaydı. Canlı çalışma saatleri veya güvenli yürüyüş rotası kabulü değildir.

Seslerin telaffuz/dinî/dil/hak incelemesi hâlâ açık; **Arapça telbiye sesi yok**. Harita native renderı ve fiziksel cihazdaki uçak modu/ses kabulü bu yerel turda yapılmadı. Canlı servis, uzman onayı ve üretim imzası durumu değiştirilmedi. Yerel ayrıntılı teknik çıktılar `build/local-media/` altında; sonuçlar sonraki içerik değişikliklerinin kabulü olarak kullanılamaz.
