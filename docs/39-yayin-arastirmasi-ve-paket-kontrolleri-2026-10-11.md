# Yayın araştırması ve uygulanmış paket kontrolleri — 11 Ekim 2026

Sonuç: teknik pilot ilerledi; **genel kullanıcı yayını henüz kabul edilmedi**.
Taslak içerik, hak, canlı hizmet, fiziksel cihaz ve imza kapıları değişmedi.
Başlangıç uzak HEAD `62f3a41fa6ef504cf3ec66d9987989a49a7cdbaa`, hedef
`codex/mvp1-pilot`, PR #1. PR #2 ilk kullanım değişikliği zaten daldaydı.

## İcra planı ve yapılan iş

1. Uzak dalı, mevcut kod/veriyi ve son CI çıktısını doğrula; tamamlanan özellikleri koru.
2. Resmî Apple/Google gerekliliklerini son binary ve servis akışlarıyla karşılaştır.
3. Gerçek APK hizalama denetimi, 16 KB ortam testi, iOS paket manifesti envanteri
   ve teknik App Bundle derlemesini uygula; anlamlı regresyonları çalıştır.
4. Yeni native bulguyu düzelt; kanıt, mağaza taslağı ve dış teslimleri kaydet.
5. Normal ilerleyen commitlerle hedef dalı ve PR #1'i güncelle; yeni CI ayrı kabul edilir.

## Güncel resmî kaynaklarla eşleme

Kaynaklar 11 Ekim 2026'da kontrol edildi. Console/hesap üzerinden verilmesi gereken
kararlar bu kaynakları okumakla tamamlanmış sayılmaz.

| Gereklilik ve birincil kaynak | Depodaki karşılığı / kabul sınırı |
| --- | --- |
| [Apple yaklaşan gereklilikler](https://developer.apple.com/news/upcoming-requirements/): 28 Nisan 2026 sonrası Xcode26/iOS26 SDK, 9 Eylül sonrası en az iOS13; güncel yaş beyanı ve AB trader bilgisi | Xcode26.2 unsigned release derlemesi mevcut CI'da geçti; deployment target15 uyumlu. Üretim imzası, yaş/ülke/trader beyanı yok. Xcode16.4 matrisi geriye uyumluluk içindir. |
| [Play hedef API](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en): 31 Ağustos 2026 sonrası yeni uygulama/güncellemelerde API36 | compile/target36 mevcut; önceki genel API35 ifadesi yeni yayın için yeterli değildir. Son imzalı paketin manifesti ayrıca okunur. |
| [Android 16 KB](https://developer.android.com/guide/practices/page-sizes): native ELF, APK ZIP, AAB türevi ve gerçek çalışma ayrı kontroller | Yeni denetçi ELF LOAD/ZIP kontrol eder, RELRO gözlemlerini ayrı kaydeder. API36/google_apis_ps16k matrisi gerçek PAGE_SIZE=16384 ve uyumluluk modu kapalı olmasını zorunlu tutar. Henüz yeni CI sonucu yok. |
| [Apple SDK gizliliği](https://developer.apple.com/support/third-party-SDK-requirements/), [manifest şeması](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests) | Flutter ve kullanılan Firebase/sqflite/geolocator gibi SDK'lar gerçek `.app` içinden taranır; hash ve bildirim yapısı kaydedilir. Envanter tüm SDK kapsamı, beyanın doğruluğu veya SDK imza kabulü değildir. Kaynak önbelleğindeki 12 plist yapı kontrolünü geçti; paketlenmiş iOS sonucu yerelde çalıştırılmadı. |
| [Apple Review1.2](https://developer.apple.com/app-store/review/guidelines/), [Play UGC](https://support.google.com/googleplay/android-developer/answer/9876937?hl=en) | Sürümlü koşul kabulü, sunucu yazma koruması, şikâyet/engel/kuyruk mevcut. Yasak içerik politikası ve yayın öncesi filtreleme/human moderasyon kabulü ayrıca gereklidir; mevcut şikâyet altyapısı tek başına tam UGC kabulü değildir. |
| [Play hesap silme](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) | Uygulama içi istek/final silme ayrımı ve Auth finalizasyon koruması mevcut. Uygulama kaldırıldıktan sonra da çalışan web yolu gerekiyor; yalnız uygulamaya yönlendiren URL yeterli değil. Gerçek URL ve operasyon kabulü eksik. |
| [Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) | Yerel SQLite, isteğe bağlı paket istekleri ve etkinleştirilirse Auth/mesaj/konum/FCM ayrı değerlendirilir. SDK/IP logları da gerçek yapılandırmayla eşleşmeli; kaynak koddan sahte “veri toplanmıyor” beyanı üretilmez. |
| [Yeni kişisel Play hesabı testi](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) | Koşul hesaba uygulanıyorsa 12 kişinin kesintisiz14 günlük kapalı test katılımı ve üretim erişim başvurusu gerekir. CI veya internal test bunun yerine geçmez. Hesap tipi/oluşturulma tarihi sahibi tarafından doğrulanır. |

## Uygulanan teknik değişiklikler

- `audit_android_native.py`: gerçek APK hash'i, ELF64 başlık/bounds/LOAD hizalama
  ve congruence, yinelenen ZIP girdisi ve sıkıştırılmamış `.so` veri ofseti kontrolü.
  32 bit paket 64 bit kabulü diye gösterilmez. RELRO bitiş kalanları raporda korunur;
  statik kontrol gerçek 16 KB veya mağaza kabulü vermez.
- CI optimize APK'larda denetçiyi ve Android build-tools36 `zipalign -c -P16 -v4`
  çalıştırır. Teknik release App Bundle derlemesi ve QA varlığı dışlama kontrolü
  eklendi. Pilot debug imzası üretim upload imzası değildir.
- API28/API35 korunarak API36/16 KB ortamı eklendi. Gerçek sayfa büyüklüğü kaydı,
  yalnız disposable CI emülatöründe root ve iki compatibility property readback
  zorunludur. Optimize x86_64 APK ile dokuz uygulama akışı; ayrıca gerçek paketli
  ses integration build'i ve ayrı teknik probe çalışır. Ayrı derlemeler tek
  imzalı son paket kabulü diye birleştirilmez.
- `audit_ios_privacy.py`: gerçek `.app` içindeki plist yapısı, manifest yolu/hash'i,
  boolean alanlar, API kategori/reason ve collected-purpose alanları kontrol edilir.
  Dışarıya symlink kabul edilmez; Flutter manifesti paket içinde bulunmalıdır.
  Gerçek API/hak/veri beyanı icat eden app manifesti eklenmedi.
- iOS26.2 ve18.5 native ekran bulgusunun nedeni: hız düğmesinin visible label'ına
  tooltip eklenmişti (`Anlatım hızı · 1.0×\nAnlatım hızı`). Gereksiz tooltip kaldırıldı;
  bağımsız button/tap semantiği ve güncel hız etiketi korundu. Yeni tooltip assertion'ı
  eski kodda başarısız, düzeltilmiş kodda başarılı; native assertion gevşetilmedi.
- [Makine okunur mağaza taslağı](store-draft/metadata.tr-TR.json) hazırlandı;
  ad24, Play kısa metin69, Apple subtitle25 karakter. Eski kısa metin sınır altına
  çekildi; taslak/eksik ses/kapalı hizmet sınırları metinde açık. URL, karar ve
  imzalı paket alanları bilinmediği için null bırakıldı.

## Doğrulama ve gerçek kapsam

[CI38127815107](https://github.com/NeoTuck/kabe_hac/actions/runs/38127815107)
**baseline62f3a41** içindir. Test merge `ab5f7920` ağacı baseline ile aynı;
dört native artifact ZIP SHA-256, JUnit/session/commands ve ses logları incelendi.
Android iki ortamda kurulu/expected APK hash'leri eşleşir. Ayrıntılı ve binary
hash'li kayıt: [QA JSON](qa/2026-10-11-yayin-arastirma-kaniti.json).

| Kontrol | Gerçek sonuç |
| --- | --- |
| Yerel son kod | 234 Flutter,75 Python;92 dosya format0 değişiklik; analyze0 sorun. Yeni binary/regresyonlar yanlış hizalama, bozuk manifest, eksik SDK, dış symlink, yanlış PAGE_SIZE/uygulanmamış compat değerinde kabulü reddeder. |
| Baseline AndroidAPI28/API35 | İkisinde9/9 uygulama ekranı +54/54 gerçek paketli sentetik anlatım +ayrı probe geçti. Harita ortak filtresi, hazırlık ve Hac devam akışı dahil. |
| Baseline Xcode26.2/iOS26.2 ve Xcode16.4/iOS18.5 | İkisinde8/9 ekran; aynı hız etiketi bulgusu. Her ikisinde54/54 gerçek paketli anlatım ve ayrı probe geçti. Düzeltilmiş kodun native sonucu açık. |
| Baseline derleme/veritabanı | Flutter/debug APK, optimize Android, QA ve SQL işleri geçti. İki iOS debug/simülatör derlemesi ve Xcode26.2 unsigned release geçti; genel workflow ekran hatasından failed. |
| Baseline optimize binary | arm64/x86_64 beşer `.so` LOAD/ZIP geçti; bazı RELRO kalanları sıfır değil ve runtime/upstream incelemesi açık. ZIP kontrolleri tam16 KB kabulü değildir. |
| Son kod yerel Android build | 7 saniyede Gradle Kotlin DSL6.4.2 plugin çözümlemesi blocked. Hatalı build başarılı yazılmadı. Linux'ta iOS/Xcode ve adb bağlı cihaz yok. |
| Yeniden ses/veri denetimi | 54 dosya hash'i, textId/version/reverse-link ve tam AAC decode geçti.53 adım taslak; eksikAR kimliği `A-P-U02.2-AR-01`. İgnore edilmiş review-index yerelde yok: kaynak makbuz denetimi bu ortamda blocked, katalog/dosya kontrolü bunun yerine hak kabulü değildir. |
| Yayın preflight | Full blocked/158, MVP blocked/546. Bunlar dış teslim/kanıt kapılarıdır, yazılım hata sayısı değildir; kayıt silerek azaltılmadı. |

## Açık teknik kabul ve uygulama işleri

1. Son hız etiketi düzeltmesinin iki iOS native turu; yeni API36 gerçek16 KB,
   paketli iOS manifest envanteri ve teknik AAB CI sonucunu incele. Başarısızlık
   olursa kanıt üzerinden düzelt; eski Android başarısı yeni kodun kabulü değildir.
2. Son AAB'de bundletool PAGE_ALIGNMENT_16K ve Play'e benzer türetilmiş APK
   LOAD/ZIP kontrollerini tamamla; son üretim imzalı sürümde tekrar yap.
3. Kafile yayın öncesi içerik filtreleme hattını güvenilir, sürümlü operatör
   politikasıyla tamamla ve sunucuda bypass/update/iptal testleri yap. Bu bir
   **kalan teknik iştir**, yalnız dış onay diye kapatılmış sayılmaz. Mevcut rapor,
   engel, RLS ve versioned terms korunur; LIVE_SERVICE_ACCEPTED kapalı kalır.
4. Fiziksel iPhone turu, gerçek iki hesap/iki kafile servis kabulü ve son imzalı
   paket ekran/gizlilik/signature testlerini aşağıdaki gerçek girdilerle yap.

## Yalnız dış girdiye bağlı teslimler

| Teslim | Kesin gereken gerçek girdi |
| --- | --- |
| Uzman ve ses hakkı | Önce [ilk Umre dilimi](release-handoff/2026-10-10/FIRST_UMRAH_SLICE.md):3adım+dua+5ses için gerçek kişi/tarih/karar ve belge; tam yayın için kalan53adım/profil/55ses kimliği kapsamını da tamamla. Dosya hash/textVersion ile bağla. |
| Arapça telbiye | `A-P-U02.2-AR-01`, metin `P-U02.2-01-draft-2026-10-09-v1` için izinli m4a/AAC, hash/byte/süre/kayıt sahibi, hak belgesi, dinleme/telaffuz incelemesi. |
| Hac profilleri | Temettü/İfrad/Kıran uygulanabilir adım ve sıra verisi; gerçek uzman belgesi, içerik sürümü. Üç test fixture onayı kullanıcı içeriğini onaylamaz. |
| Kafile canlı test | Yetkili Supabase test projesi URL/anon yapılandırması, iki test hesabı/iki kafile, güvenilir güncel koşul belgesi; Firebase/APNs test projesi, cihaz/token allowlist. Service-role yalnız operatör secret store'da. |
| Hizmet işletimi | Dört gerçek HTTPS gizlilik/destek/silme/koşul adresi; silme web yolunun uygulamasız çalışması; veri sorumlusu/bölge/saklama, moderasyon görevlisi ve müdahale süresi, yasak içerik politikası. |
| Fiziksel cihaz | iPhone model/iOS, yetkili signed build kurulumu, ilk açılış→rehber→ses→sayaç→prova→harita→kapat/devam; ağsız ve büyük yazı kanıtı. Linux simülatör/CI bunun yerine geçmez. |
| Mağaza | Apple/Play yayın hesabı ve imza erişimi, bundle/applicationId sahipliği, artan build number, gerçek yaş/ülke/DSA kararı, SDK/veri form incelemesi; son signed build ekranları. Uygun kişisel Play hesabında12/14 gün kapalı test. |
| Rota/dil/saha | Gerçek veri yoksa [şablonlar](release-handoff/2026-10-10/DATA_DELIVERY.md): kaynak/tarih/lisans/sürüm ve insan inceleme belgesi.2928POI,0rota;6iletişim,0Arapça kart,0saha kaydı korunur. Koordinat zinciri güvenli yürünebilir rota kabulü değildir. |

Mağaza gönderimi, main merge veya gerçek canlı kabul yapılmadı. Araştırma ve test
başarısı içerik/hak/operasyon kararının yerine geçmez.

## 11 Ekim Kafile/AAB devam güncellemesi

[docs/40](40-kafile-filtre-ve-aab-devam-2026-10-11.md) son teknik teslimdir: sürümlü sunucu preposting filtresi, kalıcı rejected outbox/SQLite10 ve anlaşılır kaldırma akışı, gerçek AAB-derived APK hizalama denetimi uygulandı. Son238Flutter/82Python/137pgTAP/45SQL/13Node,format/analyze geçti. Baseline2a358c4 Android35 ve iOS18.5 dokuz uygulama +54 anlatım +probe geçti; API28 getconf ve16KB adbd setup hataları ölçüm/UID readback korunarak düzeltildi. Son native/iki yeni gerçek PostgreSQL yarışı açık; eski eksik preposting/AAB ifadeleri tarihsel durumdur.
