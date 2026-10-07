# Mobil testleri çalıştırma

Bu paket dört ilk test akışıdır; bütün ürünün veya fiziksel cihazın kabulü değildir. Maestro kurulumunu resmi belgeden yapın: https://docs.maestro.dev/maestro-cli/ . CLI referansı: https://docs.maestro.dev/maestro-cli/maestro-cli-commands-and-options . iOS burada yalnız simülatördür.

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
# Yalnız yapılandırılmamış kafile/paket pilotunda:
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
