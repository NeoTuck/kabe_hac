# Kayıt ve kullanım hakkı teslim dosyası — 9 Ekim 2026

Bu dosya gönderilmeye hazır **taslaktır**. Hiçbir kurum veya ses sanatçısına istek gönderilmedi; izin alınmadı. Proje sahibinin kimliği, ticari kapsamı ve imzası başvuru öncesi doldurulur.

## Ses kayıt brifi

`2026-10-09-kayit-metni-calisma.csv` mevcut kataloglardan üretilen **55 taslak kayıt** satırıdır: 53 Türkçe adım anlatımı, bir Arapça telbiye, bir Türkçe anlam. CSV'deki adım metni, `textVersion`, önerilen ses kimliği ve dosya adı birebir eşleşir. Süre alt/üst sütunları Türkçe kelime sayısından tahmindir; kayıt kabul ölçümü değildir. Arapça satırın süresi insan dil uzmanı tarafından belirlenir. Bütün satırlar `draft_unapproved` ve `recording_and_distribution_permission_pending` durumundadır. Uzman metni değiştirirse CSV ve katalog sürümü yeniden üretilir; eski ses yeni sürüme bağlanmaz.

Kayıt teslimi: her kimlik için ayrı mono konuşma dosyası; baş/son kelime kırpılmadan, müzik veya efekt olmadan, sabit konuşmacı ve sessiz ortamda. Düzenleme ana dosyası kayıpsız PCM WAV, uygulama kopyası AAC-LC `.m4a` olarak teslim edilir. Dosya adı CSV'deki önerilen addır. Teslim formunda gerçek kayıt sahibinin adı/rolü, kayıt tarihi, metin kimliği ve sürümü, dosya SHA-256'sı, izin belgesi kimliği ve Arapça telaffuz inceleyeninin kararı bulunur. Teknik araç `tools/verify_recording.py` codec, tam decode, süre, hash, clipping/sessizlik ve sürüm bağını kontrol eder; dinî veya işitsel onayın yerine geçmez. Arapça okunuş otomatik TTS ile onaylanmaz.

Türkçe özgün anlatım için Google Cloud Text-to-Speech teknik adaydır: [resmî ürün dokümanı](https://docs.cloud.google.com/text-to-speech/docs/basics) üretilen sesin uygulamada kullanılabileceğini, [kota/şart açıklaması](https://docs.cloud.google.com/text-to-speech/quotas) bunun Google Cloud şartları ve yürürlükteki hukukla sınırlı olduğunu söyler. Hesap/faturalama, metin hakkı, seçilen sesin güncel özel koşulları ve kalite incelemesi yapılmadan üretim kaydı oluşturulmaz. Kullanılırsa `recordingOrigin=synthetic` gibi açık köken bilgisi ve ticari/çevrimdışı dağıtım delili tutulur; insan kaydı diye sunulmaz. Mevcut teknik AAC fixture'ı kullanıcı paketinde yoktur.

## Diyanet materyali için hazır izin başvurusu

**Muhtemel resmî kanal:** [Diyanet Dini Yayınlar Genel Müdürlüğü iletişim sayfası](https://diniyayinlar.diyanet.gov.tr/sayfa/44). Yetkili birimin bu materyaller için doğru hak sahibi olup olmadığı bu kanaldan teyit edilmelidir. [Hac/Umre eğitim materyali sayfasında](https://hacumreegitim.hac.gov.tr/kaynaklar?type=audio) telbiye seslerinin dinlenebilmesi, uygulama içine kopyalama izni değildir.

> Konu: Hac ve Umre Sesli Rehber mobil uygulamasında telbiye materyalinin kullanım izni talebi
>
> Sayın yetkili, [başvuran gerçek kişi/kurum ve iletişim] tarafından geliştirilen Hac ve Umre Sesli Rehber adlı Android/iOS uygulamasında [tam materyal adı, resmî URL, dosya sürümü] içeriğinin kullanımı için yazılı izin ve doğru hak sahibi bilgisini talep ediyoruz. Planlanan kullanım: Türkçe/Arapça sesin uygulama paketine veya SHA-256 doğrulamalı indirilebilir çevrimdışı pakete gömülmesi; Türkiye ve yurtdışında ücretsiz/ücretli mağaza dağıtımı; gerektiğinde yalnız teknik codec/dosya boyutu dönüşümü; uygulamada kaynak ve hak sahibi atfı. Metin, ses ve varsa görsel için çoğaltma, dijital dağıtım, çevrimdışı saklama ve teknik uyarlama haklarının ayrı ayrı kapsamını; süre, bölge, ücret, atıf ve geri çekme şartlarını bildirmenizi rica ederiz. İzin yalnız belirtilen materyal ve sürüm için kullanılacaktır. Yanıt olmadan içerik dağıtılmayacaktır.

## Özgün insan kaydı sözleşmesi için teklif maddeleri

Bu metin sözleşme veya imza değildir. Gerçek konuşmacı/ses hakkı sahibine gönderilecek brife eklenir.

> [Konuşmacı/ad-soyad ve yetki] tarafından `[audioId]` kimlikli, `[textId]` / `[textVersion]` metnine göre üretilen kaydın Android/iOS uygulamasında ve doğrulanmış çevrimdışı paketinde, [ülkeler], [süre], [ücretsiz/ücretli dağıtım] kapsamında çoğaltılması, teknik olarak AAC'ye dönüştürülmesi, dağıtılması ve oynatılması için [münhasır/münhasır olmayan] izin; ücret, kredi/atıf, düzeltme ve geri çekme yöntemi taraflarca ayrıca kararlaştırılır. Kaydın başka bir hak sahibinin icrasını veya izinsiz ses klonunu içermediği hak sahibi tarafından doğrulanır. İzin belgesi dosya hash'i ve metin sürümü ile ilişkilendirilir.

Ücret/kapsam ve hukuki metin, konuşmacı ile uygulama sahibi arasında gerçek kararlaştırma gerektirir. Dosya teslim edilse bile hak ve dinî/dil incelemesi olmadan `approved` yapılmaz.

## Harita veya saha veri sağlayıcısına hazır kapsam sorusu

[OpenStreetMap verisi ODbL](https://www.openstreetmap.org/copyright) kapsamında kullanılabilir; [OSMF'nin kamusal tile sunucusu](https://operations.osmfoundation.org/policies/tiles/) çevrimdışı toplu indirmeye izin vermez. Bu nedenle veri ve tile/hizmet hakları ayrı değerlendirilir. Bir sağlayıcı seçildiğinde aşağıdaki metin gerçek kurum kimliği ve Mekke/Medine bölge/sürüm kapsamıyla gönderilir; şu anda gönderilmedi.

> [Sağlayıcı/yetkili birim] ürününüzün [tam veri kümesi, tile stili, bölge ve sürüm] içeriğini Hac ve Umre Sesli Rehber Android/iOS uygulamasında kullanmak istiyoruz. Uygulama içine gömme veya SHA-256 doğrulamalı HTTPS paketinden kullanıcı cihazına indirerek **çevrimdışı saklama/görüntüleme**, ticari mağaza dağıtımı, stil ve gerekli teknik dönüşüm, POI/rota türetme ve kullanıcıya atıf sunma haklarının yazılı kapsamını bildirir misiniz? Ücret, bölge/süre, yenileme, iptal, alt veri hakları, ODbL veya diğer atıf metni, saklanan paketi güncelleme/silme ve sağlayıcı API/log koşullarını ayrı belirtmenizi rica ederiz. Offline dönüş-dönüş navigasyon iddiası yoktur. Yanıt ve gerçek veri doğrulaması olmadan paket yayımlanmaz.

Hastane/eczane/kapı/çalışma saati gibi değişken saha bilgilerinde tile hakkı tek başına veri doğruluğu sağlamaz; kaynak, gözden geçirme tarihi ve yetkili saha incelemesi ayrı gerekir.
