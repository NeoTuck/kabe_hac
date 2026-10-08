# Son kullanıcı ve isteğe bağlı prova hazırlığı — 8 Ekim 2026

## Kapsam ve Git

Başlangıç dalı `codex/mvp1-pilot-desktop`, upstream `origin/codex/mvp1-pilot`; başlangıç HEAD `f59c8ef9b609dc11b2c94d9d34bd3cc1042ef514`. Repo `/Users/mustafasenoglu/Desktop/kabe_hac`. `codex/mvp1-pilot` yerel adı başka worktree'de kullanıldığı için bu dalda çalışıldı. `docs/14-mac-inceleme.md` ile `test/counter_screen_test.dart` içindeki önceki yerel inceleme değişiklikleri korundu. Uzak dal fetch ile doğrulandı; çalışma başlangıcında beklenen commit uzak HEAD ile aynıydı. İnceleme commit'i `d5321a71b9e73f5d44f31ebefc6e519a801bbd3e`, uygulama/test commit'i `71b23bba181a54923024d2c4039060e78676b38f`; bu rapor ayrı son commit ile eklenecektir.

Ana rehber, Umre/Hac seçimi, üç Hac profili, SQLite ilerlemesi, sayaçlar, ses, çevrimdışı paket, gezi, güvenlik, ayarlar ve kafile akışları korunmuştur. 3D/AR/oyun motoru eklenmedi. Prova yalnız kullanıcı ana ekrandaki **Simülasyonu dene** düğmesini seçerse açılır; indirme zorunlu değildir.

## Kod dilimi

| Alan | Uygulama ve sınır |
| --- | --- |
| İsteğe bağlı akış | `lib/selection_screens.dart`, `lib/practice_screen.dart`: giriş → Umre/Hac ve profil/kapsam/ses seçimi → temel veya etkin paket → hazırlık → prova → özet. Yeni kayıt ve kaldığı kayda devam vardır. |
| Ayrı kayıt | `lib/progress_store.dart`: SQLite 8→9 yükseltmesi yalnız `practice_*` tablolarını ekler. Prova adımı, işaretleri, sayaç olayları, içerik sürümü ve ses/paket tercihi gerçek `guide_*` ilerlemesine yazılmaz. Uygulama yeniden açılınca kayıt okunur. |
| Değişen katalog | Sabit adım kimlikleri kullanılır. Sürüm veya seçili adım değişmişse eski prova kaydı korunur, güncel katalogda yeni prova açılır; kaldırılan bölümde tüm akışa güvenli dönüş vardır. Eski işaret/sayılar sessizce yeni kayda taşınmaz. |
| İçerik ve sayaç | Prova `lib/guide_catalog.dart` içindeki aynı katalogları kullanır. Taslak açıklama/dua/ses gösterilmez. Prova sayacı yalnız uzman onaylı adım ve onaylı `counterTarget` alanı varsa açılır; işlem kimliği, sınır, geri alma ve sıfırlama ayrı kaydedilir. Mevcut 53 adımın hepsi taslak olduğundan üretim kataloğunda sayaçlar kilitlidir. |
| Ses ve paket | Var olan `NarrationService`/`AudioControls` ve doğrulanmış paket yöneticisi kullanılır. Ekran/adım değişince ses durur; ses bitişi adım işaretlemez. İzinli ortam sesi veya gerçek insan kaydı olmadığı açıkça belirtilir. |
| 2D şema | Tavaf, sa‘y ve cemarat için soyut yön/hedef işaretleri bulunur. Harita, GPS konumu veya ibadet geçerliliği olarak sunulmaz. |
| Yayın kapısı | `tools/release_preflight.py` onaylı sayaç adımında geçerli hedef alanını zorunlu kılar. `docs/content-review/README.md` dört sayaç adımını ve Hac profil kabulünü uzman kontrol listesine ekler. |

Önceki sayaç regresyonundaki ikinci sıfırlama dokunuşunu gerçekten çalıştıran düzeltme `test/counter_screen_test.dart` içinde korunmuştur. Yeni regresyonlar `test/practice_store_test.dart` ve `test/practice_screen_test.dart` içindedir: v8 veri yükseltmesi, gerçek rehber ayrımı, yeniden açma, idempotent/sınırlı sayım, geri alma/sıfırlama, profil kuralı, taslak filtresi ve sürüm değişince eski kaydı koruma.

## Bu Mac'te çalıştırılan kontroller

| Kontrol | Gerçek sonuç / kanıt |
| --- | --- |
| Ortam | macOS 26.5.2 arm64; Flutter 3.47.6 / Dart 3.13.5 tam yoldan kullanıldı; sistemdeki ayrı Dart 3.12.2 kullanılmadı. Android SDK 36, API35 arm64 emülatörü ve Java 25. `flutter doctor -v`: Android lisanslarının bir kısmı eksik; Xcode 26.6 seçili `DEVELOPER_DIR` ile erişilebilir, CocoaPods yok. |
| Format ve analiz | `dart format --output=none --set-exit-if-changed lib test`: 65 dosya/0 değişiklik. `flutter analyze`: sorun yok. |
| Flutter | Başlangıçta 153/153, son kodda `flutter test --coverage`: **159/159** başarılı. Son log `build/practice-flutter-test-final4.log`. 320/390 piksel ve %100/%200 yazı widget matrisi dahildir; fiziksel erişilebilirlik kabulü değildir. |
| Python/QA/içerik/ses | `unittest`: **15/15**; dört Maestro pilot YAML politikası geçerli; 18 Umre/35 Hac kaydı taslak; 30 sn sentetik AAC dosyası teknik QA geçti. `build/practice-python-tests.log`. İnsan sesi veya işitsel cihaz kabulü değildir. |
| SQL | PGlite 0.5.8 ve resmî pgTAP 1.3.2 kaynak SQL'iyle **39/39** bağımsız RLS fixture kontrolü geçti: `build/practice-sql-fixture.log`. Gerçek Supabase Auth/Realtime/HTTP veya iki gerçek hesap kabulü değildir. |
| Android debug | Son yerel Android derlemesi geçti. APK `build/app/outputs/flutter-apk/app-debug.apk`: **229648509 bayt**, SHA-256 `9a66790b6eba74f51ab1081ac999f7b9b0f252d4833162f333f6fe0e36d656df`. Debug imzası mağaza imzası değildir. |
| Android API35 | `KabeQA35` arm64 emülatöründe mevcut dört pilot akışın JUnit/session sonucu **passed**, `device_tests_run=true`, kurulu APK hash'i beklenen dosyayla eşleşti: `build/mobile-qa/20261008T182130Z-89279be6/`. Yeni prova akışı ayrı Maestro/JUnit ile başlatma, paket atlama, taslak başlık, duraklatma ve yeniden açıp devam adımlarından geçti: `build/practice-native-qa/report-final-artifact.xml`. İlk iki seçici denemesi birleşik erişilebilirlik etiketi nedeniyle başarısızdı; ekran görüntüsüyle incelenip seçiciler düzeltildi. Son başarılı raporları esas alın. Sonrasında yalnız eski sürüm özet metni ve buna ilişkin widget testi değişti; aşağıdaki son APK yeniden üretildi. |
| iOS | Xcode 26.6 ile iOS 26.5 runtime indirildi; iPhone 17 simülatörleri listeleniyor. Yerel `flutter build ios --simulator --debug` **başarısız**: `objective_c` 9.5.0 native asset hook içindeki `xcrun --show-sdk-path` çağrısı Xcode build script ortamında boş stdout döndürüp `Bad state: No element` üretti. Aynı hook `DEVELOPER_DIR` verilerek terminalde tek başına çalıştı. `flutter build ios --debug --no-codesign` ise Xcode build adımından sonra development team/provisioning gerektiği bildirimiyle başarısız oldu. `xcode-select` hâlâ Command Line Tools'u seçiyor; sistem ayarı `sudo` parola gerektirdiğinden değiştirilmedi. Loglar `build/practice-ios-simulator-build-retry.log`, `build/practice-ios-no-codesign-final.log`. iOS `.app` geçerli build ve açılış kabulü **yok**. Önceki CI iOS sonuçları bu Mac'in sonucu değildir. |
| Yayın girdi denetimi | `release_preflight.py` exit 2 / **blocked**, 155 eksik kayıt/kanıt: `build/practice-release-preflight.json`. 155 ayrı uygulama hatası değildir. |
| Profil performansı | Android API35 emülatöründe profil APK oluşturuldu; kurulum sırasında Android servisleri geçici yanıt vermedi, sonraki Maestro sürücüsü açılış zaman aşımına uğradı. `dumpsys gfxinfo` yalnız dört başlangıç karesi bildirdi; 60 Hz kare bütçesi veya uzun oturum hakkında güvenilir sonuç çıkarılmadı. `build/practice-android-profile-build.log`, `build/practice-native-qa/maestro-profile.log`. |

ABI'ye ayrılmış optimize teknik pilot release derlemesi de geçti: ARM64 **36132979 bayt**, armeabi-v7a **30763229 bayt**, x86_64 **37968340 bayt** (`build/apk-size-report.json`). Bu paketler `KABE_TECHNICAL_PILOT=true` ile debug anahtarıyla imzalanır ve son küçük prova UI yazı düzenlemesinden önce derlenmiştir; mağaza veya son commit artefactı sayılmaz.

APK içinde `assets/content/` envanterleri ve 250646 bayt sentetik teknik demo sesi vardır. Büyük isteğe bağlı ses, harita veya saha paketleri içine gömülmedi. Native Android ekranları `build/mobile-qa/.../artifacts/` ve `build/practice-native-qa/.../` içinde; Flutter widget renderları farklı kanıttır. Fiziksel Android/iPhone, kulaklık/Bluetooth, telefon çağrısı, gerçek işitsel kalite, uzun oturum, profil kare süreleri, pil ve ısınma bu çalışmada kabul edilmedi. 16,7 ms kare hedefi için ölçülmüş bir iddia yoktur.

Paketli NotoSans/NotoNaskhArabic fontlarının OFL metinleri `assets/fonts/` altında ve uygulama lisans kayıtlarında bulunur. Sentetik teknik sesin üretim yönergesi `assets/audio/README.md` içindedir; insan seslendirme hakkı yerine geçmez. MapLibre kod adaptörü vardır, fakat offline harita veri sağlayıcısı/atfı ve dağıtım lisansı yoktur. Gizlilik ve mağaza veri beyanı için kod akışına dayalı çalışma taslağı `docs/16-gizlilik-ve-magaza-beyan-taslagi.md` içindedir; gerçek operatör ve servis bilgisi gelmeden yayımlanmaz.

## Özelliklerin gerçek durumu

| Özellik | Durum ve kanıt sınırı |
| --- | --- |
| Temel rehber, manuel ilerleme ve mevcut üç sayaç | Teknik uygulama/otomatik test ve API35 emülatör pilotu var. Dinî içerik 53/53 taslak; ibadet rehberi son kullanıcı kabulü yok. |
| İsteğe bağlı prova | Yerel kayıt, başlık akışı, 2D şema, sessiz kullanım ve devam teknik olarak çalışır. Onaylı dinî hedef ve kayıt olmadığı için gerçek tavaf/sa‘y/cemarat sayma ve sesli dinî prova açılmaz. |
| Güvenli çevrimdışı paket ve gezi | Hash/yol/güven/geri dönüş kodu ve testleri var. Gerçek güvenilir manifest, paket sunucusu, lisanslı offline harita/POI/rota ve güncel saha verisi yok. |
| Kafile/outbox | Mobil adaptör ve bağımsız SQL fixture var. Canlı Supabase URL/publishable key, iki hesaplı RLS/Auth/Realtime kabulü yok. |
| Konum/push | Süreli, kapatılabilir yerel rıza modeli var. GPS izin/ölçüm/gönderim ve APNs/FCM entegrasyonu eksik. |
| Güvenlik/dil | Kaynak/güncellik ve boş durum modelleri var. Doğrulanmış resmî numara, insan incelemeli ifadeler ve canlı saha akışı yok. |
| Mağaza | Android debug ve teknik pilot derlemeleri test içindir. Gerçek Android upload/iOS dağıtım imzası, mağaza beyanları ve cihaz kabulü yok. |

## Yayın engelleri ve kullanıcıdan gereken gerçek girdiler

1. **Dinî kabul:** 18 Umre, 35 Hac, dua ve üç Hac profili için yetkili uzman metin/sıra/sayım kararı; kaynak konumu, kullanım hakkı, gerçek inceleyen/tarih. Bu gelmeden taslaklar `approved` yapılamaz ve prova hedef sayaçları açılmaz.
2. **Ses hakkı:** Metin kimliği/sürümüyle eşleşen izinli gerçek insan sesleri, kayıt sahibi, dağıtım/seslendirme hakkı ve işitsel cihaz incelemesi. Mevcut `teknik_demo.m4a` yalnız sentetik QA'dır.
3. **Çevrimdışı/saha:** HTTPS paket sunucusu ve sabit güven özetleri; offline dağıtım izni/atıflı harita; koordinatları ve güncelliği doğrulanmış POI/rota, resmî iletişim ve insan incelemeli dil kartları. Bu olmadan gerçek gezi paketi ve uçak modu saha kabulü yapılamaz.
4. **Canlı servis:** Supabase proje URL/publishable key ve iki güvenli test hesabı/grubu, APNs/FCM yapılandırması ve konum izin/push tasarım kararları. Kodda GPS/push teslim akışları da tamamlanmalı; yalnız anahtar eklemek kabul değildir. Service-role anahtarı mobil uygulamaya konmaz.
5. **Cihaz/mağaza:** Ayrı test Android/iPhone, ses/kulaklık/çağrı, çevrimdışı, erişilebilirlik, bellek/kare/pil kabulü; gerçek Android upload ve Apple dağıtım imzası, gizlilik politikası, veri beyanları, destek bağlantısı ve mağaza hesapları. Ayrıca bu Mac'te Xcode developer directory'nin yetkili kullanıcı tarafından seçilmesi ve iOS hook/derleme sonucunun yeniden doğrulanması gerekir. Debug/unsigned paket mağazaya gönderilmez.

## GitHub ve teslim durumu

Uzak hedef `origin/codex/mvp1-pilot`; açık [PR #1](https://github.com/NeoTuck/kabe_hac/pull/1) ana dalı `main` ile karşılaştırır. İlk teslim HEAD `bf1a14c34c26b5795cd182fab491f7e163e9fb65`; rapor ve çalıştırıcı düzeltmesi sonrası son tam dal SHA'sı `git rev-parse origin/codex/mvp1-pilot` ile doğrulanır. Git commit'i kendi tam SHA'sını kendi içindeki dosyaya yazamaz. Push normal fast-forward yapılır; PR merge veya mağaza yayını yapılmaz.

İlk PR CI [37824311139](https://github.com/NeoTuck/kabe_hac/actions/runs/37824311139), `bf1a14c34c26b5795cd182fab491f7e163e9fb65` için altı işi başarılı tamamladı: QA, SQL, Flutter/Android debug, teknik split release, Android API28 ve API35 UI. İki Android artifact'ındaki `session.json` `passed`, `device_tests_run=true`, dört JUnit vaka/0 hata ve kurulu APK hash eşleşmesi doğrulandı; kanıt indirmeleri `build/ci-evidence/android28/` ve `build/ci-evidence/android35/` altında. iOS no-codesign ve simulator **derlemeleri geçti**, fakat UI işi Maestro `--version` sorgusu 30 saniyede zaman aşımına uğradığı için `blocked`, `device_tests_run=false` kaldı (`build/ci-evidence/ios/.../session.json`). Bu iOS uygulama hatası veya başarılı ekran testi olarak yorumlanmaz. `tools/run_mobile_qa.py` sürüm ön denetimi 120 saniyeyle sınırlandı; yeni run sonucu ayrıca doğrulanacaktır.
