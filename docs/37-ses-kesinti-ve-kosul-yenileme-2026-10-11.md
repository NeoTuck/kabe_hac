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

Başlangıç `a569f18` için [CI 38124114268](https://github.com/NeoTuck/kabe_hac/actions/runs/38124114268) takip edildi: Flutter işi (test/analyze/debug APK), Android optimize paket, veritabanı ve QA completed/success. İki iOS işinde no-codesign ve simulator derlemeleri geçti, native QA aşamasına geçildi; son kontrolde dört Android/iOS UI işi in_progress. Bunlar bu dilimin yeni ses kodunun sonucu değildir. Son değişiklik gönderildiğinde yeni CI ayrıca kontrol edilmelidir; önceki tüm run sonucu/native başarı uydurulmaz.

Yeni yerel Android debug denemesi yine Gradle Kotlin DSL 6.4.2 plugin artifact'ının ağdan çözülememesi nedeniyle exit 1 / 7,1 s ile durdu. Bu ortamda yeni APK kabul edilmedi. Linux'ta Xcode, çalışan emulator veya fiziksel test telefonu yok. Gerçek çağrı/Bluetooth/arka plan kesintisi ve yeni Android/iOS native sonuçları açık; yetkili gerçek test projesi olmadığı için canlı hizmet kabulü yapılmadı.

53 adım/54 sentetik ses taslak kalır; eksik Arapça telbiye, uzman/hak, saha/rota/dil, hukuki metin, canlı servis sorumlusu/test hesabı, fiziksel cihaz ve dağıtım imzası girdileri [mevcut teslim listesindeki](release-handoff/2026-10-10/README.md) gibidir. `LIVE_SERVICE_ACCEPTED` kapalı; main merge ve mağaza yayını yapılmaz.
