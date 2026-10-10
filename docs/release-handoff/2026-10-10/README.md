# Tek yayın teslim paketi — 10 Ekim 2026

Durum: **inceleme adayı; mağaza veya dinî/hukuki kabul tamamlanmadı**. Paket bir imza isteği ve sürüm eşleme mekanizmasıdır; bir onay belgesi değildir.

## İncelenecek tam kapsam

`inventory.json` iki kataloğun tam dosya özetini ve sürümünü içerir. `decisions.csv` 324 **boş** karar satırı içerir: 53 adımın dinî ve kaynak hakkı kararı, 35 Hac adımının Temettü/İfrad/Kıran kararları, bir duanın dinî/dil/kaynak hakkı kararı ve 55 ses kimliğinin dinleme/hak kararı. Mevcut 54 dosya sentetik taslaktır; Arapça telbiye kimliği vardır ama kayıt dosyası yoktur. Kimlik olması hazır ses anlamına gelmez.

Mevcut çalışma CSV'leri ve `kayit-ve-hak-talebi.md` aynı klasöre değiştirilmeden kopyalandı; kaynakların özetleri envanterde. Bunlar uzmanla kullanılacak çalışma metinleridir. Gerçek kişi, tarih, imza, izin veya karar doldurulmadı. OSM için öncelikli saha kuyruğu ve dil kartı tablosu da pakette; kaynak kaydı, açık işletme/güvenli rota veya insan dil onayı sayılmaz.

## Gerçek belgeyi bağlama

1. Uzman/hak sahibi ilgili kimlik, metin sürümü, `recordSha256`, ses dosyasının `assetSha256`, karar türü, dağıtım kapsamı ve tarihi içeren gerçek belgeyi inceler ve imzalar. Düzeltme yaparsa **yeni sürüm ve yeni özet** çıkarılır; eski belge yeni metne taşınmaz. Hac kararları her adım için üç ayrı profil satırıdır.
2. İmzalı belgeyi Git dışındaki `KABE_RELEASE_EVIDENCE_DIR` altında tut. Her karar için aynı dizinde bir JSON makbuzu oluştur: `id`, `textVersion`, `recordSha256`, `decisionKind`, `result=accepted`, gerçek `reviewedBy`, `reviewedAt` (YYYY-MM-DD), `scope`, `document` (dizin içi dosya yolu), `documentSha256`. Şablon CSV'deki boş alanlar gerçek belgeden doldurulur. Bu araç belge sahibinin kimliğini veya imzasını kendiliğinden doğrulamaz; insan doğrulaması zorunludur.
3. Katalog kaydına `reviewEvidence` alanını ekle: karar türü → JSON makbuzu dosya adı. Adım için `religious`, `source_rights`; Hac için ayrıca `profile_temettu`, `profile_ifrad`, `profile_kiran`; dua için `religious`, `language`, `source_rights`; ses için `listening`, `audio_rights`. Metin/ses sahibi, kullanım hakkı ve dinleme kararı birbirinin yerine geçmez.
4. Kayıt özeti, onay etiketlerini (`status`, `reviewedBy`, `reviewedAt`, `reviewEvidence`) dışarıda bırakan sıralı UTF-8 JSON'dan üretilir; metin, profil ve dosya özetini kapsar. Onaylı ses `assetSha256` ve doğru `textId/textVersion` ister. Katalog değişirse izin/inceleme yeniden eşleştirilir.
5. `python tools/release_preflight.py --content-only --evidence-dir "$KABE_RELEASE_EVIDENCE_DIR"` çalıştır; ardından son paket için tam ve MVP kapsam kontrolü, cihaz ve hizmet kabulünü yap. Android üretim Release ve imzalanan iOS Release derlemesi içerik kontrolünü otomatik çağırır. CI teknik pilotu `KABE_TECHNICAL_PILOT=true` ile ayrı etiketlidir; unsigned iOS derlemesi dağıtım kabulü değildir. Tam kontrolün son imzalı eser kanıtları **derlemeden sonra** sağlanır.

Taslaklar inceleme sürümünde açık etiketle korunur; mevcut taslaklarla üretim kontrolü engellenir. Gerçek belge geldiğinde katalogda `approved` yazmak tek başına yetmez: yanlış sürüm, değişmiş metin/ses, farklı karar türü veya değişmiş belge özeti yayın kontrolünü düşürür. Tam kontrolün tarihsel `human_audio_rights` kanıt adı insan sesi iddiası oluşturmaz: sentetik kayıtta gerçek model/veri/çıktı hak zinciri, köken beyanı ve dinleme kararı gerekir; köken alanı değiştirilerek insan kaydı gibi gösterilmez. Özel belge ve credential depoya konmaz. Yeni paket dışa aktarımı mevcut insan çalışma dosyasını ezmez.

## Tek dış girdi listesi

| Girdi | Somut teslim ve kabul |
| --- | --- |
| Başvuran kişi/kurum | Kişisel/kurum hesabı kararı, gerçek yasal başvuran, yetkili imzalayan ve veri sorumlusu. Kimlik/adres/billing bilgileri yalnız ilgili konsola güvenli girilir. Kurum için gereken D-U-N-S/yasal yetki belgeleri; Apple hesabında 2FA. |
| Mağaza hesapları | Google Play Console hesabı (tek sefer 25 USD); Apple Developer Program (yıllık 99 USD, bölgesel ücret ve uygun muafiyetler konsolda). Hesap sahibi koşulları kabul eder. Yeni kişisel Play hesabında en az 12 test kullanıcısının 14 gün kesintisiz katıldığı kapalı test ve üretim erişim başvurusu; yalnız süreyi doldurmak yayın onayı değildir. |
| Dinî/dil/kullanım hakkı | Yukarıdaki 324 satırın gerçek uzman/hak sahiplerince sürüm bazlı kararları; kaynak yeniden dağıtım izni; 54 sentetik dosyanın model/çıktı hak zinciri ve dinleme kararı. Eksik Arapça telbiye için kayıt, metin/dil/dinleme ve dağıtım izni, dosya özeti. |
| Harita/saha | Mevcut ODbL/atıf envanteri korunarak kritik OSM yerleri, acil iletişim ve dil kartları için kişi, kaynak, tarih ve varsa geçerlilik süresiyle gerçek kontrol. Yürünebilirlik, giriş, çalışma saati ve kalabalık iddiaları için ayrı saha kanıtı. Eski kritik numarada doğrudan arama kapalıdır; resmî kaynak veya kafile sorumlusu üzerinden güncel teyit gerekir. |
| Canlı hizmet ve işletim | Gerçek Supabase/Firebase/APNs test projesi ve yetkili erişim; iki kullanıcı/iki kafile ve yalnız test cihazları. İzolasyon, üyelik iptali, offline outbox/yeniden gönderim, FCM/APNs gerçek teslimi, GPS izin reddi ve iptali, şikâyet/engel/engel kaldırma, moderasyon audit ve gerçek Auth hesabı/verisi silme kanıtı. Moderasyon/silme sorumlusu, yanıt/itiraz ve saklama süreleri. Mevcut `docs/qa/2026-10-09-sunucu-kabul.json`, `docs/20`, `docs/28` senaryolarını doldur. Gerçek kabul olmadan `LIVE_SERVICE_ACCEPTED` kapalı kalır. |
| Kamuya açık metinler | Gerçek HTTPS gizlilik, destek, hesap silme ve kullanım koşulları URL'leri; sürümlü koşul kabulü. Veri türü/amaç/saklama/silme ve hizmet sağlayıcı kararları. Yerel cihaz verisi silmek, uzak hesap silmek değildir; isteğin kaydı sonuç değildir. |
| İmza ve son cihazlar | Android upload key/Play App Signing kararı ve güvenli yedek, gerçek AAB; Apple Team ID, Bundle ID, Distribution certificate/provisioning ve TestFlight. Anahtar ve kişisel veriler Git'e girmez. Son içerikli paketle fiziksel Android (API 36 dahil)/iPhone uçak modu, soğuk açılış, geri dönüş/silme, çağrı/Bluetooth/ses kesintisi, büyük yazı/TalkBack/VoiceOver, düşük bellek, GPS/push izin reddi ve iptali kabulü. |
| Mağaza beyanları | Son binary'ye göre Data safety/App Privacy, SDK privacy manifest/reason APIs, hassas konum/bildirim izin amacı, reklam/izleme kararı, içerik hakları, yaş ve kullanıcı içeriği beyanları. Sohbet açılırsa filtre/şikâyet/engel/iletişim ve işleyen silme/moderasyon; incelemeciye gerçek test hesabı/erişim. Son gerçek ekran görselleri; taslak dinî içerik için onaylı iddia yok. AB yayını seçilirse Apple DSA trader beyanı. |

## Güncel resmî dağıtım koşulları

10 Ekim 2026 tarihinde resmî sayfalar kontrol edildi. Yeni Android uygulaması için 31 Ağustos 2026'dan beri hedef API **36+**; minimum API ayrı bir konudur (depoda 28 korunur). Gradle compile/target 36'ya sabitlendi. Apple yüklemesi 28 Nisan 2026'dan beri **Xcode 26+ ve iOS 26 SDK+** ister; minimum iOS 15 korunur ve 9 Eylül 2026'dan beri istenen minimum hedef iOS 13+ ile uyumludur. Bunlar imza, cihaz veya mağaza onayı sağlamaz.

Resmî kaynaklar:

- [Google Play hesap açma ve ücret](https://support.google.com/googleplay/android-developer/answer/6112435?hl=en)
- [Yeni kişisel hesap test koşulu](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Google Play hedef API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Google hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
- [Apple üyelik ve ücret](https://developer.apple.com/programs/enroll/)
- [Apple kayıt/kurum yetkisi](https://developer.apple.com/help/account/membership/program-enrollment/)
- [Apple SDK/minimum sistem koşulları](https://developer.apple.com/news/upcoming-requirements/)
- [Apple inceleme: 1.2 UGC, 5.1.1 gizlilik/silme](https://developer.apple.com/app-store/review/guidelines/)

Konsol adımları hesap ve nihai sürüm geldiğinde yeniden kontrol edilir. Bu teslim paketi yasal görüş, uzman veya mağaza onayı değildir.
