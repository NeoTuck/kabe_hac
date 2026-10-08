# 9 Ekim 2026 geliştirme ve Mac doğrulaması

Bu rapor `codex/mvp1-pilot-desktop` çalışma dalının `origin/codex/mvp1-pilot` hedefi için yapılan yeni dilimini anlatır. Başlangıçta yerel ve uzak HEAD aynıydı: `0853ad123ab0756a108220088c7274192e88b54a`. Çalışma yeri `/Users/mustafasenoglu/Desktop/kabe_hac`; diğer worktree ve kullanıcı dosyalarına dokunulmadı. İlk kod commit'i `15df0b6110e2c1cff0a0b96b3d51844e5a3c044b` normal push ile hedef dala gönderildi; kaynak/dua düzeltmeleri bu raporla birlikte ikinci commit'tedir. Önceki CI ve cihaz kanıtları `docs/13-15` içinde tarihseldir; bu Mac'te tekrar edildiği anlamına gelmez.

## Hazırlanan içerik ve hak sınırı

`assets/content/umre_inventory.v1.json` ve `hac_inventory.v1.json` içindeki sabit 18+35 kimliğe özgün Türkçe özet ile hazırlık, işlem, dikkat ve sonraki aşama alanları eklendi. Adım bazlı URL/bölüm/erişim tarihi/hak durumu işlendi. [Diyanet İlmihal I](https://webdosya.diyanet.gov.tr/DiyanetAnasayfa/UserFiles/DiniBilgiler/ilmihal_cilt_1.pdf) ve [Din İşleri Yüksek Kurulu ihram](https://kurul.diyanet.gov.tr/tr/fetva/ihram-ne-demektir/c8a56fea-4dd9-4872-090e-08dd1c135351), [tavaf](https://kurul.diyanet.gov.tr/tr/fetva/tavaf-nedir-ve-kac-cesit-tavaf-vardir/0193c42d-793d-79e9-3fb4-ff842e2a0759), [sa‘y](https://kurul.diyanet.gov.tr/tr/fetva/sayin-savtlarini-eksik-yapan-kisiye-ne-gerekir/0193c42d-7a72-7dea-2f22-dcdaeaedf06b) sayfaları başlangıç kaynaklarıdır. Metin kopyalama veya yeniden dağıtım hakkı varsayılmadı.

53 adımın tamamı `draft`; üç Hac profilindeki uygulanabilirlik `unverified` kaldı. Telbiye kartına resmî kaynaklı Arapça, taslak okunuş ve özgün Türkçe anlam eklendi; `draft` kaldığı için kullanıcıya gösterilmez. İnceleyen kişi/tarih ve ses hakları doldurulmadı. `docs/content-review/2026-10-09-adim-onay-calisma.csv` ile `2026-10-09-dua-onay-calisma.csv` yetkili uzman kararları için üretildi. Diyanet PDF'sinin içindekilerindeki basılı sayfalarla 39 ilgili kaynak konumu adım alt bölümlerine düzeltildi; saha güvenliği yorumları kaynak hükmü sayılmadı. Türkçe ihtiyaç cümleleri `docs/content-review/dil-kartlari-taslak.csv` içinde, Arapça/insan incelemesi boş. Ayrıntılı kaynak ve lisans gerekçesi `docs/17-icerik-veri-ve-paket-arastirmasi.md` içindedir. Taslak dinî içerik onaylı rehber gibi açılmaz.

## Kod ve regresyon

| Alan | Yapılan iş | Gerçek sınır |
| --- | --- | --- |
| İçerik denetimi | `sourceAccessedAt` model/export alanı, 53 adım bütünlük testi ve onay etiketi için kaynak hakkı/erişim tarihi kontrolü. | Kaynak bulmak uzman onayı değildir. |
| Çevrimdışı paket | `tools/build_offline_manifest.py` dosya hash/boyut/HTTPS URL ve sabitlenecek manifest özetini üretir; symlink/gizli dosya/üzerine yazma reddi. Yerel HTTP fixture ile indirme, güncelleme, bozuk hash reddi, geri alma, silme regresyonu. | Üretim HTTPS hosting, güven özeti, lisanslı dosya ve dağıtım yok. Test HTTP'si uygulama üretim fetcher'ını gevşetmez. |
| GPS | `geolocator` ile yalnız kullanıcı onayından sonra foreground izin/tek ölçüm; Supabase paylaşımı 15 dakika ile sınırlı, durdurulabilir. Kafile yöneticisi için son 5 dakikada ölçülmüş konum “son bilinen” olarak gösterilir; rol ve süre SQL RLS ile de denetlenir. | Canlı Supabase, gerçek GPS cihaz kabulü, sunucu saklama/silme işi yok. Arka plan takibi yok. Ağ kesilince sunucu iptalinin doğrulanamadığı gösterilir. |
| Push | Firebase yapılandırması varsa açık izinle FCM token kaydı, yenileme, çıkışta bu cihaz kaydının silinmesi ve yalnız üyeliği doğrulanmış kafileye yönlendirme. Yapılandırma yoksa izin istenmez. | APNs/FCM hesabı, sunucu göndericisi, anonim kilit ekranı şablonu ve gerçek teslim yok. |
| Prova | Var olan isteğe bağlı `PracticeScreen`, ayrı SQLite prova tabloları ve onay kapıları korunur. | Gerçek katalogda 53 adım taslak olduğu için ses/ibadet sayaçları onaysız açılmaz. |
| CI | Yeni Python araçlarının sözdizim kontrolü ve Firebase'in istediği Android API 34 platformu CI hazırlığına eklendi. | CI sonucu ayrıca doğrulanır. |

## Bu Mac'te gerçek kontroller

| Kontrol | Sonuç |
| --- | --- |
| Ortam | macOS 26.5.2 arm64; Flutter 3.47.6, Dart 3.13.5; Android SDK 36 / Java 25; Xcode 26.6 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` ile erişilebilir, iOS 26.5 simulator var. CocoaPods yok ve Android lisanslarının bir bölümü eksik. `build/20261009-doctor-final.log`. |
| Flutter biçim/analiz | Son kodda `dart format --output=none --set-exit-if-changed lib test`: 69 dosya/0 değişiklik. `flutter analyze`: sorun yok (`build/20261009-analyze-final3.log`). |
| Flutter test | Yeni konum/push/paket/içerik/dua regresyonları dahil son tam takım **174/174** başarılı: `build/20261009-flutter-test-final3.log`. |
| Python QA | 19/19 başarılı: `build/20261009-python-tests-final.log`. Dört Maestro YAML yapılandırma kontrolü başarılı. |
| SQL/RLS | PGlite 0.5.8 + resmî pgTAP 1.3.2 kaynak SQL'iyle 39/39 bağımsız fixture kontrolü başarılı: `build/20261009-sql-fixture.log`. Canlı Supabase Auth/Realtime/HTTP veya iki gerçek hesap kabulü değildir. |
| İçerik/ses | 18 Umre + 35 Hac kaydının hepsi taslak. `tools/verify_audio.py` sentetik teknik QA dosyasını doğruladı; dosya uygulama varlığı ve insan kaydı değildir. |
| Yayın girdileri | `tools/release_preflight.py` exit 2, **blocked: 155** eksik girdi/kanıt (`build/release-preflight.json`). Bu sayı 155 kod hatası değildir. |
| Android debug | Son çalışma ağacından `flutter build apk --debug` başarılı. `build/app/outputs/flutter-apk/app-debug.apk`: **257.209.023 bayt** (245,29 MiB), SHA-256 `f11faebb4b4a475b8e5df389acec5ee64f6d1421efd6f3c0562daab3b5130796`. ZIP içerik listesinde `teknik_demo.m4a`/`assets/audio` yok. Debug APK'nin büyük olması optimize cihaz paketinin boyutunu temsil etmez. |
| Android optimize teknik pilot | `KABE_TECHNICAL_PILOT=true flutter build apk --release --split-per-abi` başlatıldı; işlem tamamlanmadan eski split çıktılar güncel sayılamaz. Bu paket üretim imzalı mağaza paketi değildir. |
| Yerel iOS | İlk simulator derlemesi `objective_c` build hook içinde `xcrun` SDK yolu boş döndüğü için başarısız (`build/20261009-ios-simulator-build.log`); bu Mac'in varsayılan `xcode-select` yolu Command Line Tools. Tam Xcode `DEVELOPER_DIR` ile erişilebilir. İkinci deneme Firebase Swift Package indirmesinde uzun süre kaldı ve kullanıcı isteğiyle beklenmedi; iOS yerel derlemesi **geçti sayılmaz**. Sistem parolası veya lisans kabulü kullanılmadı. |
| CI cihaz kanıtı | İlk commit [run 37849860678](https://github.com/NeoTuck/kabe_hac/actions/runs/37849860678): format/analiz/174 Flutter, Python/SQL, Android debug ve split release işleri başarılı. Android API 28 JUnit 4/4, gerçek emülatör oturumu ve kurulu APK hash eşleşmesi `build/ci-20261009-15df0b6/api28/` içindedir. API 35 işi sistem imajı ZIP arşivi bozuk indiği için emülatör açılmadan başarısız; uygulama hatası veya cihaz testi sonucu sayılamaz. iOS işi rapor yazılırken sürüyordu. |

## Gerçek kullanıcıya açık, taslak ve eksik

- Teknik olarak çalışan ve korunan: rehber seçimi/başlık akışı, yerel ilerleme, manuel sayaçlar, isteğe bağlı ayrı prova, çevrimdışı paket yöneticisi, gezi katalog adaptörü, kafile mobil kodu ve yerel outbox. Bu akışların içerik/servis kabulü aynı şey değildir.
- Taslak: 53 dinî adım açıklaması ve Hac matrisi; kaynaklı telbiye Arapçası/okunuşu/anlamı; dil kartları ve resmî iletişim adayları. Uygulama taslak dinî açıklamayı, duayı, sesi ve test gezi verisini onaylı içerik gibi göstermez.
- Kodda kısmi: bir kez GPS paylaşımı ve FCM cihaz kaydı/yönlendirmesi. Gerçek sunucu, cihaz ve teslim kabulü yok. Canlı konum takibi veya push göndericisi iddia edilmez.
- Eksik dış girdiler: gerçek uzman kararı → dinî anlatım/profil/sayaç hedefi; insan sesi veya TTS hak belgesi → ses paketi; HTTPS hosting/güven özeti → gerçek paket; offline harita lisansı ve saha koordinat doğrulaması → gezi/harita; Supabase projesi ve iki hesap → gerçek grup/RLS/Realtime; Firebase/APNs ve sunucu gönderimi → teslim; fiziksel iki platform cihazı → GPS/ses/Bluetooth/çağrı/performance; upload/Apple dağıtım imzaları ve gizlilik/mağaza beyanları → mağaza yayını.

## GitHub ve çıktı

Hedef açık [PR #1](https://github.com/NeoTuck/kabe_hac/pull/1). `main` birleştirilmez, mağaza yayını yapılmaz. Son kod ve bu rapor `origin/codex/mvp1-pilot` dalına normal push ile gönderilir; kesin HEAD ve son CI durumu PR/`git rev-parse HEAD` üzerinden kontrol edilir. Kullanıcı isteğiyle büyük CI artefaktlarının indirilmesi beklenmedi. Yukarıdaki debug APK yereldedir; geçerli iOS `.app` bu Mac'te üretilmedi.
