# Yayın hazırlığı — 8 Ekim 2026

**Durum: bu kod diliminin teknik kabulü tamamlandı; tam ürün mağaza kabulü verilmedi.** Mevcut rehber, sayaç, kafile, güvenlik, dil, gezi ve paket özellikleri korunmuştur. 3D eklenmez.

## Son teknik kabul

8 Ekim 2026 — kaynak kod `67335ffb2475d8492336b207032fb8467e405b40`; PR merge/test çalışma ağacı commit'i `6b0752bd4e7e547be7ad6f8da362461aaf22510c`. CI [37769687931](https://github.com/NeoTuck/kabe_hac/actions/runs/37769687931): yedi iş başarılı.

| Kontrol | Kanıt |
| --- | --- |
| Flutter | Format/analiz temiz; 153 test başarılı. |
| Backend fixture | 39 bağımsız SQL kontrolü başarılı; canlı Supabase değildir. |
| QA araçları | 14 Python kontrolü, YAML ve envanter denetimi başarılı. |
| Ses dosyası | AAC, 30 saniye, RMS -17.5 / peak -3.2 dBFS; sentetik teknik kayıt. |
| Android build | Debug ve üç ABI split release başarılı; release APK'lar teknik pilot debug imzalıdır. |
| iOS build | No-codesign ve simulator derlemeleri başarılı; dağıtım imzası yok. |
| Android API28 / API35 | İkisinde dört pilot akış passed; driver_prepared true; JUnit/session incelendi. |
| iOS 18.5 / iPhone16 simulator | Dört pilot akış passed; JUnit/session ve SDK/runtime incelendi. |
| UI/UX | 320/390 px, %100/%200 yazı; güncel Flutter renderları ve native duraklatma ekranları incelendi. |

Kurulu Android debug APK, iki cihazda beklenen dosya SHA-256 ile eşleşti: `e7d29e62b9f97b927c63cf5ea7b627011c4682c7fc4c913884fdb8f5c6502594`.
ARM64 teknik pilot APK: 35869863 bayt (~35.9 MB), SHA-256 `810315533ba6662a62d68dcd6edf9e0a491563fb9c9c6165a0474859ab392b99`.

Kanıt artifact kimlikleri: API28 11548505375; API35 11547845907; iOS 11547856051; UI preview 11547223955; debug APK 11547725322; split APK 11547930180. Her native raporda dört vaka, sıfır failure/error/skipped doğrulandı. Android ve iOS duraklatma ekranında oynatma konumu toplam sürenin altında ve “Ses duraklatıldı” görünür; yalnız doğal ses bitişi sayılmadı.

**Bu kabul dört pilot akış ve otomatik test kapsamıyla sınırlıdır. Fiziksel cihaz, işitsel kalite, Bluetooth/çağrı/batarya, lisanslı saha haritası, canlı servis, imzalı TestFlight/Play veya dinî içerik kabulü değildir.** 18 Umre/35 Hac kaydı hâlâ taslak; yayın girdi denetimi bu yüzden blocked döner. GPS/push ve canlı konum servisleri için eksik entegrasyon kodu ve gerçek cihaz kabulü gerekir; yalnız belge eklemek bunları tamamlamaz.

## Bu dilimdeki değişiklikler

- Etkin `travel` paketindeki `content/travel_catalog.v1.json`, manifest güveni/tür/yol/hash denetiminden sonra okunur. 8 MiB dosya / liste başına 10000 kayıt sınırı vardır. Tek tam katalog seçilir; birden fazla geçerli katalogda boş duruma dönülür. Yayıncıların sessizce birbirini ezmesi engellenir. Bir paket bir tam POI/rota kataloğu içermelidir.
- Ana ekran, paket ekranından dönüşte rehberle birlikte gezi verisini yeniler. Güncelleme/geri dönüş/silme veri modelini etkiler; SQLite favorileri ve dinî ilerleme silinmez. Önceki asenkron yenileme yeni sonucu ezemez.
- Android `release` varsayılan debug imzası kaldırılmıştır. Gerçek yayın için `android/key.properties` ve gerçek upload keystore gerekir. Debug anahtarlı optimizasyon denemesi yalnız `KABE_TECHNICAL_PILOT=true` ile açılır; CI bu teknik ayarı açıkça kullanır. Bu APK'lar mağaza yayını sayılmaz.
- Android UI çalıştırıcısı iki ardışık boot/ADB yanıtı bekler. Bir UI testi başarısızsa otomatik geçtiye çevrilmez veya tekrar denenmez. Son önceki API35 hatası ilk launchApp sırasında `device offline` idi; yeni CI sonucu ayrı kaydedilir.
- `tools/release_preflight.py` içerik/ses bağlantısı, Hac profilleri ve dış kabul kanıtları için hata halinde kapalı kalan girdi denetimi sağlar. Eksik girdide exit 2 verir; boş veya yalnız approved etiketi olan kayıtlar geçmez.
- Kaynak kontrollü özgün Umre açıklama önerileri `docs/content-review/umre-kaynakli-oneri.md` içinde. Uzman onayı veya ses kullanım izni değildir; uygulamanın taslak onay bilgileri değiştirilmez.

- Hac önizleme/akış etiketleri gerçek katalog/profil durumuna bağlıdır; uzman onaylı teknik fixture üzerinde sabit önizleme etiketi kaldırılmış, gerçek taslak katalog korunmuştur.

## Android üretim imzası

`android/key.properties` dosyası Git'e girmez. Yerel/CI gizli dosyada `storeFile` (android dizinine göre ya da mutlak yol), `storePassword`, `keyAlias`, `keyPassword` değerlerini sağla. Keystore'u da Git'e koyma. Teknik pilot ortam değişkenini üretim ortamında kullanma. Gerçek upload anahtarının SHA-256 sertifikası ve Play Console kaydı ayrıca karşılaştırılır; yalnız dosyanın bulunması bunu kanıtlamaz.

```sh
flutter build appbundle --release
# İmzalı paket ve diğer kabul belgeleri hazırlandıktan sonra:
python3 tools/release_preflight.py --evidence-dir release-inputs
```

Girdi kontrolü yeşil olsa bile bu komutların sonucu, imza, sürüm kodu, üretim yapılandırması ve mağaza kabulü bağımsız doğrulanır. iOS için Apple Developer takım/provisioning ile gerçek imzalı archive/TestFlight gerekir; simulator veya no-codesign bunun yerine geçmez.

## Kabul kanıtı sözleşmesi

`release-inputs/` özel ve gitignore kapsamındadır. Her kategori için `<kategori>.json` ve aynı dizin altında gerçek kanıt dosyası gerekir. JSON alanları: `file`, `sha256`, `result: accepted`, `reviewedBy`, `reviewedAt` (YYYY-MM-DD), `scope`. Hash yalnız dosya bütünlüğünü doğrular; uzman yetkisini veya belgenin doğruluğunu otomatik onaylamaz. Üretim commit/build/hash ve değerlendirilen kapsam gerçek belgede bulunmalı; değişen sürümde kabul yeniden yapılmalı.

Kategoriler: religious_expert_review, human_audio_rights, offline_map_license, verified_travel_safety_language_data, live_supabase_acceptance, push_location_acceptance, physical_android_acceptance, physical_iphone_acceptance, ios_distribution_signing, privacy_store_declarations, signed_android_artifact.

## Gerçek yayın için açık bağımlılıklar

1. 18 Umre/35 Hac metni, dua, kaynak/hak ve üç Hac profili için gerçek uzman incelemesi.
2. Metin sürümlerine bağlı izinli insan kayıtları ve işitsel/kesinti/kulaklık cihaz kabulü.
3. Gerçek paket sunucusu/güven kökü, offline harita lisansı, doğrulanmış yer/rota/iletişim/dil verisi.
4. Canlı Supabase Auth/RLS/Realtime kabulü; gerçek GPS izin akışı, konum gönderimi, APNs/FCM teslimi. Bunlar yalnız kanıt dosyası eklenerek tamamlanmış olmaz, eksik servis kodu ve entegrasyon testi gerekir.
5. Gerçek Android/iPhone, performans/batarya/uçak modu/erişilebilirlik ve gizlilik kabulü; üretim imzaları, mağaza açıklamaları ve gerçek destek/gizlilik URL'leri.

## Önceki ara çalışmalar (son kabul üstte)

CI `37765942469`, kod `e253b9aff`: 153 Flutter testi, format/analiz, teknik AAC ses QA, 39 bağımsız fixture SQL ve 11 Python kontrolü başarılı. Android debug/split release, iOS no-codesign/simulator derlemeleri geçti. ARM64 teknik pilot APK 35869863 bayt; SHA-256 987fd632aa162711ff35f9d77452fdd28d8becb0b7e44663f8c8673f1b84e9cb. Gerçek upload imzası değildir.

API28 dört pilot akışı geçti. API35 ilk launchApp sırasında `device offline` ile başarısız, diğer üç akış geçti. iOS sorgusu test başlamadan simctl 30 sn timeout ile blocked döndü. Bunlar tam mobil kabul sayılmaz. Android testlerinden önce ayrı Maestro hierarchy sürücü hazırlığı eklendi; en fazla iki hazırlık girişimi kaydedilir, başarısız UI akışına tekrar uygulanmaz. CoreSimulator başlangıç sorgusunda en fazla üç hazırlık girişimi vardır. Yerel Python regresyonları 14 kontrolle başarılı; yeni mobil CI sonucu ayrı doğrulanır.

Rehber yenileme testinin fake-async varlık okuma zaman aşımı tester.runAsync ile giderildi; yeni CI'da iki yenileme testi geçti. Yeni gezi paketinin güven/hash/symlink/geri dönüş/silme/çakışma kontrolleri ve UI paket dönüşü geçti. Ana sayfa, ses, ayar ve kapalı kafile güncel renderları gözle incelendi; 320/390 px ve %100/%200 yazı matrisi geçti. Fiziksel cihaz ve işitsel kalite kabulü değildir.

CI 37768070990 / c7cb0c96: iOS no-codesign/simulator ve dört pilot UI akışı başarılı; 14 Python/39 SQL ve Android split release başarılı. Linux Flutter işi dependency apt kurulumunda ilerlemeden bekledi; yeni düzeltme ağ tekrarlarını ve iki apt adımını 180'er saniye, Flutter işini 25 dakika ile sınırlar. Android yeni sürücü hazırlığının UI kabulü bu noktada bekliyor.
