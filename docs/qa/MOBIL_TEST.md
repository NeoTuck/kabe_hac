# Mobil testleri çalıştırma

Güncel `--flow all` paketi beş uygulama akışıdır: Umre girişleri, ayarlar, onaylı ses yok durumu, yapılandırılmamış servisler ve isteğe bağlı prova. Bütün ürünün veya fiziksel cihazın kabulü değildir. Maestro kurulumunu resmi belgeden yapın: https://docs.maestro.dev/maestro-cli/ . CLI referansı: https://docs.maestro.dev/maestro-cli/maestro-cli-commands-and-options . iOS burada yalnız simülatördür. Derleme minimumları Android API 28 (Android 9) ve iOS 15.0; gerçek cihaz uyumluluğu ayrıca kabul edilmelidir. Mevcut iOS proje bağımlılık hattı Swift Package Manager’dır.

İsteğe bağlı prova artık `.maestro/flows/05-prova.yaml` ile ana beşli matrise dahildir. Eski `.maestro/practice-flow.yaml` tarihsel tek akış olarak korunur. Prova başlatma, duraklatma ve yeniden açıp devam test edilir; taslak dinî metin/sayaç ve gerçek ses kabulü değildir.

## Ayrı native ses paketi

Üretim uygulaması teknik demo sesini içermez. Üretim build tamamlandıktan sonra `python3 tools/build_audio_probe.py --platform android` veya `--platform ios-simulator`, geçici asset manifesti ile **ayrı debug QA uygulaması** derler. Üretim manifesti ve önceki üretim artifact'ı `finally` ile geri getirilir. QA uygulamasını kullanıcıya dağıtmayın; aynı application ID ile kurulum önceki teknik test uygulamasının yerini alır, bu yüzden yalnız açıkça seçilen boş test cihazında çalıştırın.

QA artifact kurulduktan sonra genel çalıştırıcıya `--flow audio` verin. `.maestro/audio-probe.yaml` gerçek native eklentide süre/konum, pause/resume, seek/completion, replay ve stop durumlarını zorunlu tutar. Konum ilerlemesi tek başına işitsel çıktı kabulü değildir. CI Android emülatörü `-noaudio` kullanır; duyma, ses netliği, insan telaffuzu, kilit ekranı, Bluetooth ve telefon çağrısı fiziksel kabul bekler. Probe dinî ilerleme kaydetmez. `KABE_AUDIO_QA=true` ve debug hedefi zorunludur; üretim giriş noktası probe'u import etmez.

Her platformda beş uygulama vakasının JUnit/session kanıtı ile ayrı bir ses vakasının kanıtını birlikte okuyun. Yalnız build, YAML veya test dosyasının bulunması native başarı değildir. Güncel inceleme: `docs/19-ilk-kullanici-kabul-incelemesi.md`.


## Ön koşullar

1. Aynı commit'ten Android APK veya iOS simülatör `.app` derleyin; ayrı test cihazına kurun. No-codesign iPhone `.app` dosyasını simülatör veya imzalı iPhone paketi sanmayın.
2. Android: adb ve yetkilendirilmiş test telefon/emülatör. iOS: tam Xcode, açılmış simülatör ve doğru mimari/SDK derlemesi. Maestro CLI ve Java gerekli.
3. Android ID `com.mustafasenoglu.hac_umre_sesli_rehber`; iOS `com.mustafasenoglu.hacUmreSesliRehber`. Kişisel imzalama ID'si farklıysa `--app-id` verin.
4. Kullanıcı verisi bulunan ana telefonu test hedefi yapmayın. Akışlar veri silmez ama rehber oturumunu açabilir/güncelleyebilir. Ayarları değiştirmez; ses duraklatılır.

```sh
python3 -m venv build/qa-venv
build/qa-venv/bin/pip install -r tools/qa-requirements.txt
build/qa-venv/bin/python tools/verify_mobile_qa.py
python3 tools/content_audit.py
# Yalnız komut hazırlama; gerçek cihaz testi değildir:
python3 tools/run_mobile_qa.py --platform android --device emulator-5554 --test-device --dry-run
# Cihaz/uygulama/araç kontrolü:
python3 tools/run_mobile_qa.py --platform android --device emulator-5554 --test-device --preflight
# Android ilk üç akış:
python3 tools/run_mobile_qa.py --platform android --device emulator-5554 --test-device
# iOS Simulator; gerçek açılmış simülatör UUID'sini kullanın:
python3 tools/run_mobile_qa.py --platform ios-simulator --device SIMULATOR_UUID --test-device
# Beş uygulama akışı (isteğe bağlı prova dahil):
python3 tools/run_mobile_qa.py --platform android --device emulator-5554 --test-device --flow all
```

Maestro sürümü, platform, hedef, kurulu Android sürüm bilgileri, workspace commit, komut ve status session.json'a; UI raporu JUnit'e; log ve ekran görüntüleri ayrı run dizinine kaydedilir. `blocked`, `prepared`, `preflight_ready` cihaz testi başarısı değildir. Cihaz akışlarında hata varsa log ve ekranı inceleyip seçiciyi düzeltin; beklentiyi kaldırarak test geçirmeyin. APK hash'i ve derlenen commit ayrıca kaydedilmelidir.

## Tam ürün için ayrıca yürütülecek cihaz matrisi

| Alan | Senaryo | Kanıt |
|---|---|---|
| İlerleme | İki kullanım biçimi/profil, elle işaret/geri alma, kapat/aç, güncelleme | Önce/sonra kayıt ve ekran |
| Sayaç | 0/7 sınırları, hızlı dokunma, geri alma, sıfırlama iptali | Kayıtlar ve ekran |
| Ses | Gerçek duyma, sarma, kesinti, kilit ekranı, kulaklık/Bluetooth, çağrı | Sistem durum/log ve insan gözlemi |
| Offline | Uçak modu, paket kesintisi/hash, eksik alan, eski sağlam paket | Ağ durumu/paket sürümü |
| Erişilebilirlik | Küçük ekran, %200 yazı, RTL, TalkBack/VoiceOver | Ekran kaydı ve manuel sonuç |
| Grup | İki hesap/grup, özel mesaj, iptal edilen üyelik, offline tekrar | Gerçek test Supabase/SQL ve istemci kanıtı |
| Harita/rota | İzinli bölge, durak/POI, offline rota, yeniden açma | Sağlayıcı hakları ve cihaz kayıtları |
| Konum/push | İzin reddi, süre sonu/iptal, eski konum, APNs/FCM | Gerçek cihaz/sunucu kanıtı |
| Performans | Profile/release, düşük bellek, başlangıç/kare/bellek | Ölçüm yöntemi ve cihaz modeli |

Gerçek kişilere test mesajı/davet gönderilmez; acil numaralar aranmaz. Çıkışta kanıtlar kişisel veri açısından kontrol edilerek paylaşılır.

## 8 Ekim CI genişletmesi — tarihsel dört akış kanıtı

MVP workflow Android API 28 ve 35 için ayrı, yeni CI emülatörleri kullanır. APK aynı run'daki build artifact'ından indirilir. `--expected-apk PATH` verildiğinde çalıştırıcı kurulu tek APK'yı yalnız okumak için geçici klasöre çeker ve SHA-256 karşılaştırır; eşleşmezse ekran testini başlatmaz. Manuel testte bu bayrak isteğe bağlıdır. Akış süresi 10 dakika ile sınırlıdır.

iOS işi fiziksel hedef no-codesign build ardından `--simulator --debug` derler. `run_ci_ios_qa.py` yalnız `GITHUB_ACTIONS=true` içinde kendi test simülatörünü oluşturur, kurar ve dört akışı çalıştırır; kendi oluşturduğu UUID'yi kapatıp siler. CI simülatör runtime sürümü seçili Xcode SDK major/minor sürümüne eşlenir; en yeni kurulu runtime körlemesine seçilmez. Kişisel Mac'te bu yardımcı çalıştırılmaz; açık seçilen test simülatörüyle genel çalıştırıcı kullanılır.

CI'a eklenmiş olmak başarılı kabul anlamına gelmez. Run sonucu, JUnit ve session durumu birlikte okunmalıdır. Dört pilot akış bütün ürün, hoparlör sesi, gerçek iPhone, Bluetooth veya canlı backend kabulü değildir. Release/split APK'lar boyut ölçümü için teknik debug imzasıyla üretilir; kalıcı dağıtım imzası ayrıca gerekir. Güncel kanıt: `docs/11-kullanici-kalite-turu.md`.

Maestro seçicileri Flutter'ın birleştirdiği başlık/alt açıklama ve sekme sırası metnini destekler. İlk CI'da yakalanan seçici ve SDK/runtime hatalarının düzeltmesi `bd89c83a`, tekrar run `37715121386`; sonuç kanıtı olmadan cihaz akışını geçti saymayın.

Teknik kaydın ilerleme göstergesi sürekli değişir. Oynat/duraklat tap komutları `waitToSettleTimeoutMs: 500` kullanır; bu native iç işlemlerin süresini garanti etmez. Önceki 6,6 sn kayıt native bekleme sırasında bittiğinden aynı sentetik demo 30 saniyeye uzatılmıştır; `assets/audio/README.md` yeniden üretimi ve sınırları açıklar. Oynatma ve duraklatma durumlarının görünürlük beklentileri zorunludur. Beş yapılandırma regresyonu `python3 -m unittest discover -s tools -p 'test_mobile_qa.py' -v` ile yürütülür; cihaz testinin yerine geçmez.

Mobil ses akışı ayrıca ayrı erişilebilirlik canlı bölgesindeki “Ses duraklatıldı” bilgisini zorunlu tutar. “Ses tamamlandı” veya yalnız oynat düğmesinin geri gelmesi duraklatma kabulü değildir. Uygulama bu iki durumu açıkça ayırır; fiziksel işitsel çıktı ayrıca insan tarafından doğrulanmalıdır.

Güncel kabul: `58708cfb`, CI `37741666923`. Dört pilot akış Android API 28, API 35 ve iPhone 16 / iOS 18.5 simulator'de başarılı. JUnit / session / Android kurulu APK hash eşleşmesi ve duraklatma görüntüleri incelendi. 146 Flutter, 39 bağımsız SQL ve beş QA yapılandırma kontrolü de geçti. Önceki run hataları tarihsel teşhistir; güncel kanıt `docs/11-kullanici-kalite-turu.md` başında. Fiziksel cihaz, hoparlör sesi, Bluetooth ve bütün ürün kabulü açık kalır.
