# Tam sürüm geliştirme: kapsam, kabul ve ilk uygulama

7 Ekim 2026. Android ve iOS aynı Flutter ürün kapsamını paylaşır. 3D yok; mevcut özellikler kaldırılmaz. Kod, içerik, canlı servis, cihaz ve yayın kabulü ayrı izlenir.

## Güncel başlangıç kanıtı

`6d02270b2d2460767508474b2a218898d8fcf323` için GitHub çalışması https://github.com/NeoTuck/kabe_hac/actions/runs/37669070487 başarılı: format/analiz, Flutter test işi, ses QA, Android debug APK, iOS debug/no-codesign ve database. Bu commit için yerel Flutter test kanıtı 91 testtir. İmzalı iOS dağıtımı, gerçek cihaz, Maestro ve canlı Supabase kabulü değildir.

## Yedi aşama

| Aşama | Uygulama | Kabul |
|---|---|---|
| 1 | Güncel envanter, eksik/kabul matrisi, mobil test akışları ve kanıtlı çalıştırıcı | Kod/CI başlangıcı doğrulanmış; cihaz senaryoları hazırlanmış; ilk Android/iOS simülatör çalıştırması ayrıca kayıtlı |
| 2 | 18 Umre açıklama/dua/kaynak metni, editöryal inceleme ve kullanıcıya gösterim | Metin/sürüm/kaynak/hak ve gerçek uzman onayı; tüm Umre akışı cihazda |
| 3 | İzinli insan sesleri, yayın paketleri, offline/kesinti/güncelleme | Uçak modu; kilit ekranı/çağrı/kulaklık; iki platform |
| 4 | 35 Hac alt adımı, üç profil matrisi ve cemarat bağlamları | Temettü/ifrad/kıran için uzman onaylı ayrı akışlar |
| 5 | Lisanslı offline harita, POI/rota/şirket rotaları, dil ve saha verisi | Gerçek izinli bölgede offline kullanım, güncellik, atıf |
| 6 | Canlı kafile backend, geçmiş, program, konum ve push | İki hesap/grup RLS, offline senkronizasyon, rıza/iptal ve bildirim teslimi |
| 7 | UI/UX, erişilebilirlik, performans, veri koruyan güncelleme, imza/mağaza | Gerçek Android/iPhone; sabit güvenli imza, TestFlight ve yayın beyanları |

İlk bağımsız uygulama: aşama 1 test temeli ve aşama 2 editöryal çalışma tabloları. Aşama 1 cihaz yürütmesi eksik olduğu için tamamen bitmiş değildir. Sonraki kod dilimi: kafilede son 100 mesajın ötesine erişim için hesap/üyelik kontrollü geçmiş sayfalama. Canlı backend kurulumu gelmeden servis kabulü verilmez.

## Ürün kabul matrisi

| Alan | Kod/otomatik kanıt | Android/iOS kabulünde açık olan |
|---|---|---|
| Rehber, seçim, devam, SQLite | Unit/widget ve migrasyon testleri | Fiziksel iki platformda yeniden açma/güncelleme |
| Manuel sayaçlar | Tavaf/sa‘y/cemarat ve geri alma testleri | Sayaç/pil/ekran kilidi saha deneyimi |
| UI/tema/RTL/yazı | 320/390 ve %100/%200 widget matrisi | TalkBack/VoiceOver, gerçek yaşlı kullanıcı deneyimi |
| Umre/Hac içerik | 18/35 taslak kimlik; şema/onay filtreleri | 53 gerçek metin; uzman; profil uygulanabilirliği |
| Dua ve üç ses türü | Bir taslak dua, üç taslak ses kaydı tanımı | Arapça/telaffuz/anlam, gerçek ses dosyaları ve haklar |
| Teknik ses | AAC dosya QA, oynatıcı durum testleri | Gerçek işitsel çıktı, çağrı, Bluetooth, kilit ekranı |
| Offline paket | Hash/atomik etkinleştirme/kesinti testleri | Gerçek sunucu/manifest/yayın paketleri; uçak modu |
| Harita/POI/rotalar | Adaptör, model, liste/arama/favori | Etkileşimli harita, izinli veri, şirket rotası indirme |
| Güvenlik/dil/saha | Şema, kaynak/güncellik ve boş durumlar | Doğrulanmış kurum numaraları/dil kartları/kapı-saat verisi |
| Kafile/Auth/davet/sohbet | Repository/mock HTTP/widget; 35 SQL kontrolü | Gerçek Supabase/OTP/Realtime/RLS; geçmiş sayfalama |
| Konum | Yerel süreli rıza modeli | GPS izinleri/gönderim/iptal/saklama kabulü |
| Push | Tamamlanmadı | APNs/FCM, token yaşam döngüsü, teslim testi |
| Adım sensörü/yoğunluk | Tamamlanmadı | Sensör/veri kaynağı ve cihaz kabulü |
| Şirket yönetimi/rota paylaşımı | Tamamlanmadı | Panel/yetki/oluşturma/indirme/moderasyon |
| Dağıtım | Android debug ve iOS no-codesign CI | Kalıcı imza, veri koruyan güncelleme, iOS imzalı dağıtım |

## İlk uygulamanın araçları ve sınırları

- `.maestro/flows/`: dört akış. Umre girişleri/adım taslak gösterimi, ayarlara erişim, teknik ses UI durumları, kapalı kafile/paket hizmetleri.
- `tools/verify_mobile_qa.py`: YAML biçimi ve pilot komut politikası; cihaz çalıştırmaz.
- `tools/run_mobile_qa.py`: açık cihaz seçimi, uygulama kurulum kontrolü, JUnit/ekran görüntüsü/log/session.json. Sonuçlar build/mobile-qa altında tutulur. CLI başarılı olsa bile eksik/başarısız/atlanmış JUnit vakaları kabul edilmez.
- Çalıştırıcı APK/IPA kurmaz, uygulama/keychain/veri silmez, giriş/davet/mesaj yapmaz. Rehber oturumu oluşturabildiği için ayrı test cihazı seçilir.
- Varsayılan `core` üç akıştır; `04` yalnız canlı hizmetleri yapılandırılmamış teknik pilot içindir. Dört akış bütün ürün testi değildir; cihaz denemesinden sonra seçiciler gerektiğinde düzeltilecek.
- Teknik ses akışı UI oynatma/duraklatma durumunu kontrol eder; hoparlör/telaffuz/kalite kabulü vermez.
- iOS hedefi yalnız simülatör; fiziksel iPhone kurulumu ve manuel/uygun ayrı araçla kabul açık kalır.
- session.json içindeki workspace_commit yalnız çalışma kodunu tanımlar. Kurulu uygulamanın hash'i ayrıca doğrulanmadan bu commit'in cihaza kurulduğu iddia edilmez.

## Yerel doğrulama

Python derleme kontrolü, dört YAML yapı kontrolü ve 18/35 kimlik/sıralama denetimi geçti. Android ve iOS dry-run komutları oluşturuldu; cihaz yürütmesi yok. Android preflight, Maestro ve adb bulunmadığı için `blocked` ve `device_tests_run=false` döndü. Bu ortamda cihaz testleri geçmedi. Yeni Dart/native uygulama kodu değiştirilmedi; son uygulama kanıtı yukarıdaki CI çalışmasıdır. Yeni CI QA işi yalnız araçları ve envanteri doğrular.
