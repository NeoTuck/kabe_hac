# Ses kesintisi ve koşul yenileme — 11 Ekim 2026

Bu dilim kullanıcı isteğiyle `a569f18262f40886f46e670627e0f1f863336f5f` uzak HEAD doğrulanarak başlatıldı. Çalışma ağacı temizdi; önceki kapsam ve taslaklar korundu.

## İcra planı

1. Mevcut CI/native sonuçlarını kontrol et; bağımsız geliştirmeyi bekletme.
2. Geciken ses komutunun yeni anlatıma etkisini ve kesinti sırasında bekleyen oynatma isteğini regresyonla yeniden üretip düzelt.
3. Sunucu koşul sürümü değişince açık yeniden kabul yönlendirmesi ve güvenli çevrimdışı davranışı tamamla.
4. Yerel tam doğrulama, native regresyon kapsamı, küçük commit ve hedef dal/PR kanıtını kaydet.

## Kullanıcı için değişen davranış

- Seek, duraklatma, devam, tekrar ve hız komutları yükleme/durdurma ile aynı sırada işlenir. Eski dosyaya ait geciken komut yeni dosya yüklendikten sonra oynatıcıya uygulanamaz. Değişmiş dosya isteğine ait bekleyen komutlar atlanır. Başarısız hız değişimi sonraki komutları kilitlemez ve eski hız tercihini bozmaz.
- Telefon/kulaklık kesintisi yükleme veya devam isteği sırasında gelirse o istek ses başlatmaz. Kesinti sonrasında yeniden kullanıcı isteği gerekir. Kurulu just_audio 0.10.6 kaynak kodunda varsayılan `handleInterruptions=true` transient interruption sonunda `play()` çağırır; `DeviceNarrationBackend` bunu false yaparak kendi AudioSession kesinti/noisy hattının tek sorumlu olmasını sağlar. Bu teknik düzeltme fiziksel çağrı/Bluetooth kabulü değildir.
- Sunucu eski kullanım koşulunu reddederse Kafile ekranı yerel kabul görünümünü kaldırıp sunucunun güncel metnini getirir. Kullanıcıya oku/kabul et/işlemi yeniden dene adımı gösterilir; davet kodu korunur. Bu sırada ağ kesilirse eski kabul yeniden kullanılmaz, yazma düğmeleri kapalı kalır ve yenileme yönlendirmesi görünür. Üyelik/erişim hatası yanlışlıkla koşul hatası sayılmaz: yalnız sunucunun iki belirli 42501 koşul hatası bu akışı başlatır.
- Açık koşul belgesi, hesap veya tema değiştiğinde başka sürüme sessizce dönüşmez; açıldığı metin/sürüm snapshot'ını gösterir. Yeni hesabın kabul durumu ayrıca kontrol edilir. Kabul otomatik verilmez.

## Kanıt

Önce yeni testler eski davranışta çalıştırıldı: geciken seek ve pause için iki test başarısızdı (yeni dosya erken yükleniyordu). İlk sıra düzeltmesinden sonra kesinti sırasında bekleyen resume ve loading için iki ek test eski kesinti davranışını başarısız gösterdi (istenmeyen play sayısı 2/1 idi; beklenen 1/0). Son uygulamada bu dört regresyon geçti. Var olan assertion ve kapsam kaldırılmadı.

Son yerel tam Flutter **232/232** (önceki 224 + 8 regresyon), Python **57/57**; format **92 dosya / 0 değişiklik**, Flutter analyze **0 sorun**. Varlık/lisans envanteri güncel: 87 varlık, 150 kilitli Dart paket kaydı, eksik yerel lisans dosyası 0; hak kabulü değildir. SQL/Node üretim kodu değişmedi; önceki uzak veritabanı ve QA sonuçları aşağıda ayrı belirtilir. SQLite yine sistemin gerçek libsqlite3.so.0 dosyasıyla çalıştırıldı. Makine okunur sonuç [QA kaydında](qa/2026-10-11-ses-ve-kosul-kabul.json).

Native akış 03, güncel kayıt nerede olursa olsun ilk gerçek taslak başlığı açıkça seçer; gerçek paketli anlatımı oynatır, sonraki başlığa geçince eski sesin durduğunu ve yeni anlatımın kendiliğinden başlamadığını bekler. Bütün gerçek katalog dosyalarını oynatan Android/iOS integration testine eşzamanlı seek/pause/dosya değiştirme eklenmiştir. Ayrı teknik probe bütün anlatımların yerine geçmez. Dokuz YAML'ın statik kontrolü geçti; bu yeni native assertion'lar yerelde cihazda çalıştırılmadı.

## Derleme ve CI sınırı

Başlangıç `a569f18` için [CI 38124114268](https://github.com/NeoTuck/kabe_hac/actions/runs/38124114268) takip edildi: Flutter işi (test/analyze/debug APK), Android optimize paket, veritabanı ve QA completed/success. İki iOS işinde no-codesign ve simulator derlemeleri geçti, native QA aşamasına geçildi; ilk gözlemde dört Android/iOS UI işi in_progress idi; sonradan gelen başarısızlıklar aşağıda kaydedildi. Bunlar bu dilimin yeni ses kodunun sonucu değildir. Son değişiklik gönderildiğinde yeni CI ayrıca kontrol edilmelidir; önceki tüm run sonucu/native başarı uydurulmaz.

Yeni yerel Android debug denemesi yine Gradle Kotlin DSL 6.4.2 plugin artifact'ının ağdan çözülememesi nedeniyle exit 1 / 7,1 s ile durdu. Bu ortamda yeni APK kabul edilmedi. Linux'ta Xcode, çalışan emulator veya fiziksel test telefonu yok. Gerçek çağrı/Bluetooth/arka plan kesintisi ve yeni Android/iOS native sonuçları açık; yetkili gerçek test projesi olmadığı için canlı hizmet kabulü yapılmadı.

53 adım/54 sentetik ses taslak kalır; eksik Arapça telbiye, uzman/hak, saha/rota/dil, hukuki metin, canlı servis sorumlusu/test hesabı, fiziksel cihaz ve dağıtım imzası girdileri [mevcut teslim listesindeki](release-handoff/2026-10-10/README.md) gibidir. `LIVE_SERVICE_ACCEPTED` kapalı; main merge ve mağaza yayını yapılmaz.

## Sonradan gelen native kanıt ve uygulanan düzeltme

`a569f18` CI 38124114268 tamamlandı: Flutter/debug APK, optimize Android, veritabanı ve QA başarılı; Android API28 **7/9**, API35 **5/9**, iki iOS işi sonraki push nedeniyle cancelled. İki Android ZIP'in SHA-256 özeti upload artifact kaydıyla ve kurulu APK `0a4c48db267ec174245c1cb54e3fdee64d3035f1dc393da64e3c53493f3fcecc` beklenen APK ile eşleşti. PR test merge `2e3faca` tree `0446fb7624112020df1e02fba4e0f4e2a7d4e6a1` dalın a569f18 tree'siyle aynı. JUnit, commands ve başarısız ekran hiyerarşileri bağımsız okundu. Bu sonuç tam native kabul değildir.

- 07: Katalog JSON sırası çalışma zamanı sırası değildir; parser packageId'ye göre sıralar. Yer paketi haritaların altındadır. Önceki UP değişikliği yanlıştı; DOWN düzeltildi. Pozitif Eczane sonuç sayısı ve harita hazır assertion'ları korunur.
- 03: API28 hiyerarşisinde Devam et/0:11 vardı; duraklatma olmuş fakat durum yazısı görünür viewport dışında kalmıştı. API35'te oynatma tap'i 10,9 s, pause tap'i 16,9 s sürdü; 15 saniyelik dosya bitmişti. Medya dokunuşlarında sürekli konum animasyonu için settle beklemesi 200 ms ile sınırlandı; pause durumuna ve yeniden resume düğmesine açık kaydırma eklendi. Oynat/duraklat/devam/seek/hız/stop/adım değişimi assertion'ları silinmedi. Maestro bu sınırı best-effort olarak uygular: [resmî tapOn belgesi](https://docs.maestro.dev/reference/commands-available/tapon).
- 08/09: Geniş Rehber.* seçicisi ana ekrandaki rehber giriş düğmesini de eşliyordu; API35 rehber listesine geçmişti. Gereksiz tap kaldırıldı; her açılışta restore edilmiş ana ekran başlığı için bounded wait kullanılır. launchApp varsayılan yeniden açılışı korunur; veri/izin sıfırlanmaz. [Resmî launchApp davranışı](https://docs.maestro.dev/reference/commands-available/launchapp).
- Eski orkestrasyon ekran testi nonzero olunca gerçek bütün paketli anlatım integration testini ve ayrı probe'u hiç çalıştırmıyordu. Yeni Android/iOS stage toplayıcısı bağımsız üç aşamayı yürütür, ayrı log/exit/JSON bırakır ve herhangi bir failure/timeout son sonucu nonzero tutar. Başarısız install sonrası bağlı testler çalışmış sayılmaz. Ses dosyası/native oynatma dinî, telaffuz veya hak onayı değildir.

Bu üç yapılandırma regresyonu eski akışta önce başarısızdı. Son yerel Python **65/65** (57 + 3 native bulgu + 5 orkestrasyon regresyonu); YAML politika ve Python compile kontrolleri geçti. Flutter kodu önceki 232/232 doğrulamadan sonra değişmedi. Bu ek dilimde yeni cihaz çalıştırması yok; son CI'nın düzeltilmiş 9 ekran, gerçek paketli ses ve ayrı probe sonuçları ayrıca kabul edilmeli. [Makine okunur native bulgu kaydı](qa/2026-10-11-native-bulgu-duzeltme.json).

Ses/kabul kodu `3841597` için CI 38125179058 gözleminde QA, veritabanı ve Android optimize build başarılı; Flutter format/analyze/test geçti ve APK işi sürüyordu, iOS derlemeleri sürüyordu. Bu HEAD de henüz tam native kabul değildir. Son native düzeltmenin sonuçları kendi HEAD/CI kaydıyla takip edilir; cancelled önceki iş başarı sayılmaz.
