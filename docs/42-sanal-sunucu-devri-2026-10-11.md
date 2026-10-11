# Sanal sunucu devri — 11 Ekim 2026

## Alınacak kod ve son durum

- Depo: `https://github.com/NeoTuck/kabe_hac`
- Çalışma dalı: `codex/mvp1-pilot`; PR #1 açık/taslak.
- Son gönderilmiş uygulama kodu `9547ecb` üzerindedir. iOS26 ilk kurulum
  süresi düzeltmesi bu commit'tedir; yeni native sonucu kullanıcı isteğiyle
  takip edilmiyor.
- Son bağımsız incelenen koşu GitHub Actions `38142992091`: iOS16.4 ve
  Android işleri başarılı, iOS26.2 ilk kurulum zaman aşımıyla başarısız.
- Yerel biçim ve Flutter analiz temiz; 241 Flutter ve 86 Python testi geçti.
  Python testleri macOS'ta kanonik `TMPDIR=/private/tmp` ile çalıştırıldı.
  iOS kurulum aracı değişikliğinden sonra da aynı kontroller tekrar geçti.

## Tamamlanan teknik parçalar

54 sentetik **taslak** ses kimlik/sürüm/hash kontrolüyle rehber ve provada
çalıyor. Prova ve sayaç kayıtları rehber ilerlemesinden ayrı; çevrimdışı
gerçek POI/şehir haritası, kafile mesaj/şikâyet/engel altyapısı, sürümlü
koşul kabulü, hesap silme operatör yolu, paket güvenliği ve mağaza teknik
denetimleri kodlandı. Son turda Android 16 KB için JNI ve bağımlılık hizaları,
gerçek sayfa boyutu/uyumluluk ölçümü, ayrı optimize UI ve debug ses işleri,
ELF LOAD/ZIP/RELRO raporu eklendi. Android API35'te eski medya oturumundan
geç gelen `stop` yeni ses yüklemesini keserse, yalnız mevcut kullanıcı isteği
için bir kez kontrollü toparlanma uygulanır. API28 harita testi için
emülatörün 4 GB RAM'i geri getirildi.

Önceki CI `38139991882`: 10 işin 8'i başarılı. Android API36/16 KB x86_64
optimize UI 9/9, ayrı debug 54/54 paketli ses ve teknik probe geçti. API28
harita akışı 2 GB emülatörde MapLibre `std::bad_alloc` nedeniyle 8/9 kaldı;
ses 54/54 ve probe geçti. API35 UI 9/9 ve probe geçti; 45. seste SystemUI
`stop` ile native bağlantı kesildi. İki iOS simülatör işi başarılıydı;
arşivleri bağımsız indirilemedi. Bu iki Android bulgusunun kod/ortam
düzeltmeleri son kodda; kabul için **yeni CI sonucu gerekir**.

Sonraki CI `38142992091`: Android API28/API35, iki API36/16 KB işi,
Flutter/QA/veritabanı/AAB başarılıdır. API35'te 9/9 uygulama akışı, 54/54
ses ve probe; 16 KB optimize pakette 9/9 akış, ayrı debug pakette 54/54
ses ve probe geçti. İndirilen Android 35/16 KB JUnit ve oturumlarında
cihaz testi/kurulu APK hash'i doğrulandı; iki 16 KB emülatöründe ölçülen
sayfa boyutu 16384'tür. iOS26.2'de derlemeler geçti fakat ilk simülatör
uygulama kurulumu 120 saniyede zaman aşımına uğradı; native akış çalışmadı.
İlk kurulum sınırını 300 saniyeye çıkaran ve hata kanıtı yazan değişiklik
sonraki gerçek cihaz kabulü gerektirir. iOS16.4 artifact'inde 9/9 UI,
54/54 ses, probe 1/1 ve sıfır JUnit hatası bağımsız incelendi; kurulu iOS
`.app` hash'i bu arşivde bulunmuyor.

**Güncel kullanıcı tercihi:** Uzun yayın/native işleri otomatik GitHub
akışından çıkarıldı. `mvp-checks.yml` artık iOS simülatör, Android emülatör,
release APK/AAB veya teknik ses probe üretmez; kısa QA, Flutter
analiz/birim testi ve veritabanı kontrolleri kalır. Araçlar gerektiğinde
elle çalıştırılabilecek biçimde depoda saklanır. Bu değişiklik için yeni
yerel veya native test istenmedi. Önceki cihaz kanıtları tarihseldir;
yayın kapıları kapanmış sayılmaz.

## Açık yayın kapıları

`release_preflight` tam kapsam `blocked/158`, MVP kapsam `blocked/546`.
53 adım/dua/Hac profili için gerçek uzman kararı, 54 taslak sesin hak ve
işitsel/telaffuz kararı, eksik Arapça telbiye dosyası, gerçek hizmet URL'leri,
yetkili Supabase/Firebase/APNs test projesi, moderasyon/silme sorumlusu ve
saklama süreleri, saha/dil/rota insan incelemesi, fiziksel iPhone/Android
kabulü, üretim imzaları ve mağaza beyanları yok. Teknik 16 KB x86_64 emülatör
başarısına rağmen arm64 Flutter `libflutter.so` GNU_RELRO bitişi 16 KB'ye
hizalı değil (12.288 bayt kalan); arm64 gerçek cihaz/Play kabulü açık.

Karar ve belge teslimi için mevcut tek paket:
`docs/release-handoff/2026-10-10/README.md`. İçinde tam envanter, 324 boş
karar satırı, ilk Umre 19 satırlık inceleme dilimi, hak talebi, moderasyon,
veri/rota ve hizmet koşulu işletim yönergeleri bulunur. Belgeler hazırlıktır;
gerçek kişi/onay/izin/credential içermez. Bunları uydurup `approved` veya
`LIVE_SERVICE_ACCEPTED` açma. Gerçek gizli belgeleri Git'e koyma.

## Sunucudaki ajan için devam isteği

> `NeoTuck/kabe_hac` deposunda `codex/mvp1-pilot` dalını koruyarak devam et.
> Önce `git status --short --branch`, `AGENTS.md` ve
> `docs/41-kalan-yayin-isleri-plani-2026-10-11.md` dosyalarını oku;
> kullanıcı değişikliklerini silme. Uzun yayın/native testleri kullanıcı
> istemedikçe başlatma veya CI sonucunu izleme. Önce koddan incelenebilen
> bağımsız işleri tamamla; değişiklikleri normal push ile PR #1'e gönder.
> Native/mağaza testleri daha sonra açıkça istenirse mevcut araçlarla yeniden
> çalıştır ve sonucu artifact/JUnit/session ile doğrula. O zamana kadar
> bunları geçmiş kanıt veya yayın kabulü olarak gösterme.
> Gerçek uzman/hak/servis/cihaz/imza girdisi yoksa ilgili yayın kapısını
> kapalı tut ve hangi kişi ya da hesabın hangi belgeyi sağlaması gerektiğini
> `docs/release-handoff/2026-10-10/README.md` üzerinden bildir.

Bu devir sunucuda çalışmaya devam etmek içindir. Canlı migrasyon, moderasyon,
hesap silme veya mağaza yayını için kendi başına yetki ya da gerçek veri
oluşturmaz.
