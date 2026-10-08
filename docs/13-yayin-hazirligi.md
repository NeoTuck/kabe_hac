# Yayın hazırlığı — 8 Ekim 2026

**Durum: teknik yayın hazırlığı sürüyor; tam ürün mağaza kabulü verilmedi.** Mevcut rehber, sayaç, kafile, güvenlik, dil, gezi ve paket özellikleri korunmuştur. 3D eklenmez.

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
python3 tools/release_preflight.py --evidence-dir release-inputs
flutter build appbundle --release
```

Ön kontrol yeşil olsa bile bu komutların sonucu, imza, sürüm kodu, üretim yapılandırması ve mağaza kabulü bağımsız doğrulanır. iOS için Apple Developer takım/provisioning ile gerçek imzalı archive/TestFlight gerekir; simulator veya no-codesign bunun yerine geçmez.

## Kabul kanıtı sözleşmesi

`release-inputs/` özel ve gitignore kapsamındadır. Her kategori için `<kategori>.json` ve aynı dizin altında gerçek kanıt dosyası gerekir. JSON alanları: `file`, `sha256`, `result: accepted`, `reviewedBy`, `reviewedAt` (YYYY-MM-DD), `scope`. Hash yalnız dosya bütünlüğünü doğrular; uzman yetkisini veya belgenin doğruluğunu otomatik onaylamaz. Üretim commit/build/hash ve değerlendirilen kapsam gerçek belgede bulunmalı; değişen sürümde kabul yeniden yapılmalı.

Kategoriler: religious_expert_review, human_audio_rights, offline_map_license, verified_travel_safety_language_data, live_supabase_acceptance, push_location_acceptance, physical_android_acceptance, physical_iphone_acceptance, ios_distribution_signing, privacy_store_declarations, signed_android_artifact.

## Gerçek yayın için açık bağımlılıklar

1. 18 Umre/35 Hac metni, dua, kaynak/hak ve üç Hac profili için gerçek uzman incelemesi.
2. Metin sürümlerine bağlı izinli insan kayıtları ve işitsel/kesinti/kulaklık cihaz kabulü.
3. Gerçek paket sunucusu/güven kökü, offline harita lisansı, doğrulanmış yer/rota/iletişim/dil verisi.
4. Canlı Supabase Auth/RLS/Realtime kabulü; gerçek GPS izin akışı, konum gönderimi, APNs/FCM teslimi. Bunlar yalnız kanıt dosyası eklenerek tamamlanmış olmaz, eksik servis kodu ve entegrasyon testi gerekir.
5. Gerçek Android/iPhone, performans/batarya/uçak modu/erişilebilirlik ve gizlilik kabulü; üretim imzaları, mağaza açıklamaları ve gerçek destek/gizlilik URL'leri.

## Doğrulama

Yerel Python regresyonları ve YAML kontrolleri çalıştırıldı. Tam Flutter analiz/test ve Android/iOS derlemeleri GitHub CI'da doğrulanır; tamamlanmadan geçti yazılmaz. Güncel sonuç bu bölümde eklenecek.
