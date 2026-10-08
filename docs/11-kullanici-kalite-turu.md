# Kullanıcı odaklı kalite turu

8 Ekim 2026. Mevcut özellikler, veri kayıtları ve görsel yön korunur; 3D eklenmez. Çalışmanın kapsamı uygulama kalitesi ve teknik kabulüdür; eksik dinî/saha girdilerini üretilmiş veriyle doldurmaz.

## Kullanıcı akışları

- Kafilede sabit “Mesaj yaz” girişi ve klavye üstünde kaydırılabilen editör var. Taslak kapatınca korunur, hesap değişince temizlenir. Çift gönderim engellenir. Önceki özel alıcı kafileden ayrılmışsa yeniden seçim gerekir; mesaj sessizce genel sohbete dönmez. Yerel kaydın alınması teslim edildi iddiası değildir. Davet ve duyuru/program işlemleri tek işlem olarak yürür; eski hesabın geç daveti yeni hesaba gösterilmez, açık davet hesabın değişmesiyle gizlenir ve değişmiş hesapla yayın gönderilmez.
- Kafile arka plandayken yeni yenileme başlatmaz; dönüşte üyelik/veri kontrol edilir. Hesap değişiminde eski abonelik kapanır. Önceden başlamış isteklerin hesap/epoch kontrolleri korunur.
- Paket indirme/silme/geri dönüş aynı ekranda tek işlem yürütür. Okuma hatasında tekrar deneme vardır. Türkçe paket türleri ve büyük yazıya uygun kartlar kullanılır.
- Gezi favorileri aynı noktaya eşzamanlı yazılmaz. Başarılı kayıttan sonra gereksiz SQLite tekrar okuması kaldırıldı. Favori filtresi ve aramayı temizleme eklendi. Türkçe arama işaret farklarını tolere eder.
- Yer kartları koordinat, yerel ad, mevcut telefon/saat ve kaynak ayrıntısını açar. Rota ayrıntısı sıralı durakları gösterir; POI durağı yer ayrıntısına açılır. Bu ekran canlı yön bulma sağlamaz. Teknik fixture etiketleri korunur.
- Rehberde başlık açma, sonraki/önceki geçiş ve yeni yolculuk hızlı çift dokunuştan korunur. Ses durdurma hatası ekranı kapatmaz.
- Sayaç sıfırlama onayı tek pencere açar. Cemarat ekleme/açma işlemleri korunur; liste okuma hatasında yükleme biter ve yeniden deneme görünür. Dinî ilerleme hâlâ yalnız kullanıcı seçimiyle değişir.
- Ayar yazmaları dokunuş sırasıyla yürür. Kaydetme hatasında önceki ses hızı geri yüklenir. Oynatıcı hız değişimini reddederse sonraki sesin tercihi değişmez.

## Çevrimdışı dayanıklılık

- Paket kataloğu da aynı sınırlı taşıma katmanını kullanır: geçici dosya, 1 MB sınır, zaman aşımı ve yönlendirme reddi.
- HTTPS ve yönlendirme sınırları korunur. Bağlantı/yanıt/akışta 30 saniye bekleme sınırı vardır; geç gelen bağlantı iptal edilir.
- HTTP Range devamında başlangıç, son, toplam ve Content-Length doğrulanır. Sunucu 200 ile tam dosya dönerse eski parça güvenle sıfırlanır.
- Yazılacak veri manifest boyutuyla sınırlanır; addStream geri basıncı kullanılır. Kapatma hatası asıl zaman aşımı/boyut hatasını örtmez.
- Tam boyda ama bozuk staging dosyası yeniden indirilir. Son tam dosya kümesi/boyut/SHA-256 kontrolü korunur.
- Staging sembolik bağları yazmadan önce reddedilir. Aktivasyon kimliği ve her iki sürüm alanı doğrulanır. Geri dönüşte eski manifest kimliği/sürümü ve sabit güven özeti yeniden kontrol edilir.
- Ana atomik işaretçisi eksik ama yedeği bulunan paket listeden kaybolmaz.

## Kaynak ve zaman bilgisi

- İnceleme bekleyen iletişim numarası kullanıcıya yayınlanmaz.
- Kaynak başlığı, bağlantısı ve yerel tarih açılabilir; bağlantı kopyalanabilir.
- Saha kaydı başlamadan güncel sayılmaz; süre sınırı ekrandayken tek seferlik zamanlayıcıyla güncellenir. Arka planda zamanlayıcı durur, dönüşte saat yeniden kontrol edilir.
- Konum rızası başlangıçtan önce etkin sayılmaz. Gelecekte/ters zamanda ölçülen veya sonlu olmayan konum güncel sayılmaz. Gerçek GPS/push entegrasyonu bu değişiklikle tamamlanmış değildir.

## Mobil QA ve paket boyutu

- CI Android API 28 ve 35 emülatörlerinde dört pilot Maestro akışı çalıştıracak şekilde genişletildi. Kurulu APK, beklenen build ile SHA-256 eşleşmeden kabul verilmez. JUnit/log/screenshot/session kanıtı ayrı artifact olur.
- iOS CI fiziksel hedef için no-codesign build yanında simulator build üretir; yalnız bu CI için oluşturulmuş bir iPhone 16 simülatörüne kurar. Sonrasında kendi simülatörünü kapatır/siler. Fiziksel iPhone veya TestFlight kabulü değildir.
- Maestro 2.11.0 sabitlendi. Eski CI işlerindeki gereksiz tekrarlar dal bazlı concurrency ile iptal edilir.
- Release modunda ABI başına APK ve SHA-256/boyut raporu üretilir. Mevcut imza debug anahtarıdır: mağaza yayınına veya kullanıcının mevcut kurulumunu veri koruyarak güncellemeye hazır değildir.
- İlk release ölçümü `fd8ca398` / CI `37711891995`: arm64 35.609.619, armeabi-v7a 30.256.253, x86_64 37.444.980 bayt. Arm64 APK içeriği incelendi: Flutter çekirdeği 11.747.864, MapLibre 10.851.472 ve uygulama native kodu 7.734.152 bayt; APK içinde tek ABI vardır. Bu ara committe iki indirme regresyonu başarısızdı; final uygulama kabulü değildir. Hatalar sonraki committe düzeltildi. Boyut ölçümü fiziksel cihaz FPS/bellek/pil ölçümü değildir.

## Doğrulama durumu

İlk dilim `123ccbc4` / CI `37710748385`: analiz/format, 113 Flutter testi, teknik ses QA, Android debug APK, iOS debug/no-codesign, 39 SQL fixture kontrolü ve qa-foundation başarılı. Gerçek Flutter ana ekranı ve sabit mesaj yazma girişinin renderı incelendi.

Uygulama kodu `82708e1e` / CI `37713783433`: analiz/format, **143 Flutter testi**, teknik ses dosyası QA, **39 bağımsız SQL fixture kontrolü**, qa-foundation, Android debug APK, Android release/split ve iOS fiziksel hedef debug/no-codesign ile simulator derlemeleri geçti. Arm64 release 35.609.619 bayt (SHA-256 `0fff91a84994abb40804550f1156d104e5a40ca2471d89e765fa7fe8176f1834`), armeabi-v7a 30.256.253 ve x86_64 37.444.980 bayt.

Mobil ekran testleri bu run'da başarılı değildir. Android API 35'te uygulama açıldı ve gerçek ana ekran görüntüsü/hiyerarşisi incelendi; Maestro tam etiket beklediği için başlıkla alt açıklamayı birleştiren Flutter erişilebilirlik düğümlerini bulamadı. iOS'ta iki derleme geçti fakat Xcode 16.4 / SDK 18.5 ile en yeni kurulu iOS 26.2 runtime seçildi; XCTest sürücüsü açılmadı. iPhone kullanım akışı çalıştı sayılmaz.

Düzeltme `bd89c83a`: seçiciler başlık ve birleşmiş açıklama/sekme metnini eşleştirir; görünürlük ve ses oynat/duraklat beklentileri korunur. iOS çalışma ortamı seçilen SDK'nın major/minor sürümüne eşlenir; uyumlu runtime yoksa açık hata verir. Dört YAML akışı ve Python sözdizimi yerelde doğrulandı. Tekrar CI **37715121386** bu devir sırasında sırada; yeni mobil kabul kanıtı henüz yok. [CI sonucu](https://github.com/NeoTuck/kabe_hac/actions/runs/37715121386) üzerinden JUnit, session ve ekran kanıtları birlikte incelenmelidir. Bekleyen testler geçmiş sayılmaz.

Önceki run iki gezi regresyonunda hata yakaladı; favori kaydı sırasında kartın yanlışlıkla ayrıntı açması ve belirsiz test kaydırma hedefi düzeltildi. 143 testlik kabul bu düzeltmeleri içerir. Geçmiş başarılı run yeni kodun yerine kabul sayılmaz.

## Mobil kabul devamı — 8 Ekim sabahı

`bd89c83a` / CI `37715121386` tamamlandı: 143 Flutter testi, analiz/format, teknik ses dosyası QA, 39 SQL kontrolü ve Android/iOS derlemeleri yeniden geçti. iOS 18.5 runtime ile test sürücüsü artık açıldı. Ayarlar akışı iOS ve Android API 28/35'te; ses oynat/duraklat iOS ve API 28'de geçti. Rehber/kafile akışları, native Card'ın birleştirdiği başlık ve açıklamaya tam metin seçicisi uygulanması nedeniyle başarısız. API 35 ses hata ekranında konum 0:06 / 0:06: altı saniyelik teknik kayıt oynatma sonrası testin ekranın sabitlenmesini beklediği sırada bitmiş.

Başlık seçicileri başlıkla başlayan birleşik açıklamayı eşler; onaylı/başka başlık eşleşmez. Ses tap işleminin ekran sabitlenme beklemesi 500 ms ile sınırlanır; “Duraklat” ve tekrar “Anlatımı dinle” beklentileri kaldırılmaz. SDK/runtime seçimi ve üç akışın beklentisi için beş Python regresyon kontrolü eklendi; yerelde geçti. Bunlar yapılandırma testidir, cihaz kabulü değildir. Yeni tüm platform tekrarının sonucu ayrıca kaydedilecek.

Ses UI'ında duraklatılma ve tamamlanma açıkça ayrılır; yalnız seçilmiş ses kartında “Ses duraklatıldı” veya “Ses tamamlandı” gösterilir. Mobil test artık “Ses duraklatıldı” durumunu da zorunlu tutar; kendiliğinden biten kaydı başarılı duraklatma saymaz. İki Flutter regresyonu eklendi; çalıştırma CI'da bekliyor.

`3a57540a` / CI `37739530513`: 145 Flutter/39 SQL/5 Python yapılandırma kontrolü, analiz/format, teknik ses dosyası QA ve Android/iOS derlemeleri geçti. Üç ortamda rehber, ayarlar ve kapalı hizmet akışları geçti. Ses akışı daha sıkı beklentide başarısız: Android native tap işlemi 8–9 saniye sürerken 6,6 saniyelik kayıt bitmiş, ekran “Ses tamamlandı” gösteriyor; iOS'ta “Duraklat” kontrolü sırasında kayıt bitmiş. 500 ms sınırı native iç işlemi kesmedi. Önceki yalın oynat düğmesi beklentisi gerçek duraklatmayı ayırmıyordu.

Yalnız mevcut sentetik teknik demo tekrarlanarak 30 saniyeye uzatıldı; sessizlik, yeni dinî içerik veya üçüncü taraf anlatım eklenmedi. Önceki kayıt SHA/provenance/yeniden üretim `assets/audio/README.md` içindedir. Yerelde decode/süre/sessizlik/clipping kontrolü geçti: 30 sn AAC, RMS -17,5 dBFS, peak -3,2 dBFS. İnsan sesi/hak/onay değildir. “Ses duraklatıldı” beklentisi korunur; yeni mobil tekrar sonucu ayrıca gerekir.

Oynatıcı duraklatma isteği beklerken tamamlanma olayı gelirse tamamlandı durumu korunur; geç duraklatma yanıtı bunu duraklatıldı diye değiştirmez. Kontrollü backend ile regresyon eklendi. Tamamlanan kaydın yeniden oynatım için başa sarılma davranışı böylece korunur. Güncel 146 Flutter testinin CI sonucu ayrıca gerekir.

## Ürün sınırları ve sonraki iş

18 Umre ve 35 Hac kimliği hâlâ taslak. Gerçek uzman onaylı metin/profil matrisi, ses dosyaları/hakları, lisanslı harita/POI/saha verisi ve Supabase proje girdileri eksik. Harita gösterimi, POI/rota paketinin gezi kataloğuna bağlanması, şirket rota paylaşımı, gerçek GPS/push ve sensör/yoğunluk ürün akışları ayrıca tamamlanmalıdır. Gerçek Android/iPhone, işitsel çıktı/kilit ekranı/Bluetooth ve veri koruyan imzalı güncelleme kabulü ayrıca gerekir.

Sonraki bağımsız kod dilimi: doğrulanmış çevrimdışı POI/rota paketini gezi ekranına bağlamak; önce teknik fixture ile hash/yol/çakışma/yenileme testleri, sonra izinli gerçek veri. Üretime hazır iddiası bu turun sonucu değildir.
