# Gerçek çevrimdışı veri ve ses üretim hattı — 9 Ekim 2026

Bu dilim Linux çalışma ortamında `fdf7ca41` üzerinden uygulandı. Mac, fiziksel Android veya iPhone kullanıldığı iddia edilmez. 18 Umre / 35 Hac kimliği, ilerleme, favoriler, isteğe bağlı 3D olmayan prova ve dinî onay filtreleri korunur.

## Uygulananlar

- Geofabrik GCC OSM PBF dosyasından Mekke/Medine için 2.928 gerçek adlandırılmış yer kaydı ve yol/bina/su geometrisi çıkarıldı. PBF SHA-256: `37ddf4a1c62bf695297173744a9ff7524ae51cd4c421a75cfa5de110b80166eb`. Kaynak anı `2026-10-08T20:21:06Z`. Yeniden üretim aracı `tools/build_osm_travel.py`; sadece çıkarım sırasında osmium 4.2.0 gerekir.
- Mekke geometri dosyası 1.281.906 bayt / 40.971 şekil; Medine 889.330 bayt / 30.291 şekil. Paketlere kaynak kaydı ve tam ODbL-1.0 lisansı dahil edildi. Türetilmiş veri tabanı `offline_packages/osm-2026-10-08/` altında aynı lisansla yayımlandı. Küçük binalar ve multipolygon ilişkileri dahil değildir; kutsal sınır veya güvenli navigasyon ürünü değildir.
- Veri dosyaları değişmez `fed9f97861081f67cb5844598667347787f96502` commit'inden indirilir. Üç manifestin güven özeti uygulamada sabittir. Katalog değişse bile başka manifest kabul edilmez. Başlangıçta ağ isteği veya şehir geometrisi açma yoktur; kullanıcı Paketler ekranından seçer.
- Yeni yerel MapLibre ekranı indirilen GeoJSON verisini 2D çizer. Harita stili dış tile, glyph, sprite ve GPS istemez. Kaynak atfı ve tarih görünür; yer araması vardır. Gzip açılmış veri 24 MB ile sınırlıdır; JSON ayrıştırma ve stil kodlama ayrı isolate'tadır. Gerçek gezi listesi binlerce kartı aynı anda oluşturmayan ListView.builder kullanır.
- Resmî MFA/MOH/SPA kaynaklarıyla altı iletişim kaydı eklendi. Kaynak kontrolü insan/dinî inceleme yerine geçmez. Ayrı `sourceVerified` durumu, resmî alan adı, telefon biçimi ve gelecekte olmayan tarih ister; Arapça dil kartını onaylamaz. Arama düğmesi kullanıcı seçimiyle numara çevirme ekranını açar.
- `tools/produce_narration.py` 55 ses kimliğini kaynak metin/sürüm/script SHA-256 ile eşleştirir. Google Cloud TTS ancak onaylı Türkçe metin ve gerçek sağlayıcı hak/hesap girdisiyle çağrılır; mevcut taslaklar için ücretli istek göndermez. Arapça otomatik üretilmez. Mono AAC 64 kbps çıktısı ffmpeg/ffprobe ve gerçek decoder QA ile sınanır. Üretim makbuzu sentetik kökeni ve bekleyen dinleme incelemesini açıkça kaydeder. Ana WAV dosyaları dağıtım kayıtlarından ayrı tutulur.
- Diyanet telbiye adaylarının hash/ölçüm ve izin durumu `docs/qa/source-registry.v1.json` içinde. Kullanım izni olmadığı için uygulamaya ses olarak eklenmedi. Ses üretim anahtarı burada yapılandırılmadı; gerçek kullanıcı ses dosyası üretilmedi.

## Kontroller ve sınırlar

Yerel format ve analiz temiz. Son birleşik Flutter koşusu 188/188 geçti; gerçek iki şehir paketinin kurulması/açılması/bozulmuş dosyanın reddi bu koşudadır. Native sonuç CI üzerinden ayrıca takip edilir. Python 41/41, Node 13/13 geçti. Teknik 30 saniye AAC dosyasının integrity/decoder kontrolü başarılı; bu insan anlatımı veya fiziksel cihaz sesi kabulü değildir. Paket ekranı dört regresyon kontrolü geçti. SQL kaynakları değiştirilmedi; önceki SQL sonuçları yeni çalıştırma sayılmaz.

Maestro yedinci akış gerçek Mekke paketinin indirilmesini ve native stilin hazır olmasını ister. Dördüncü akış artık kapalı katalog yerine gerçek katalog bekler. YAML/politika kontrolü yedi dosyada başarılıdır; bu cihaz çalıştırma kanıtı değildir. Android API28/API35 ve macOS iOS simülatör işlerinin bu commit'e ait sonucu GitHub Actions'ta ayrıca kontrol edilmelidir. Yerel Linux ortamında Android SDK ve Xcode bulunmadığı için native derleme çalıştırılmadı.

`release_preflight` hâlâ blocked/155: 53 dinî adım taslak, gerçek ses/inceleme/üretim hakları, Hac profil incelemesi, canlı backend ve bildirim kabulü, gizlilik/saklama kararı ve üretim imzaları tamamlanmadı. Lisanslı OSM kaynağı ve resmî iletişim gerçek girdidir; uçak modu/native render/fiziksel saha kabulünün veya kapsamlı güncel rotanın yerine geçmez. Yayın kanıtları tamamlanmadan engeller silinmez.

## Tekrar üretim

```sh
python3 tools/produce_narration.py --help
python3 tools/build_osm_travel.py --help
python3 -m unittest discover -s tools -p 'test_*.py' -v
flutter analyze
flutter test
python3 tools/verify_mobile_qa.py
python3 tools/release_preflight.py --evidence-dir release-inputs
```

Sıradaki gerçek içerik işi: ilk Umre metni ve telbiye için gerçek uzman kararı, buna bağlı kayıt hakkı/hesap erişimi ve dinlenmiş kayıt dosyasını katalogla eşleştirmek. İnceleyen adı, lisans izni, insan sesi, hesap veya mağaza imzası AI tarafından varsayılmaz.
