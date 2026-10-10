# CI ve native kanıt incelemesi — 10 Ekim 2026

İncelenen dal kodu: `ff6db6533af5aae97bc5934e73788d0a2510b187`.
PR #1 test birleştirmesi: `33f37b98974936c7b962e796bcde191ec3af0c9a`; iki commit arasında dosya ağacı farkı yoktur.
[CI 37991790287](https://github.com/NeoTuck/kabe_hac/actions/runs/37991790287) **completed/success: sekiz iş başarılı**. Son native sonuçları aşağıda izlenir.

## Önceki başarısızlıkların gerçek nedeni

- CI 37967154898 Android API28 ve iki iOS paketindeki `commands.json`, ekran ağacı ve Android prova ekran görüntüsü incelendi. Umre giriş/ses testleri artık bulunmayan `Umreye hazırlanıyorum` kartını arıyordu. Prova düğmesi küçük Android ekranının altında kalıyordu; assertion öncesi kaydırma eksikti. Dalda zaten bulunan kart seçicisi ve kaydırma düzeltmeleri korunur; özellikler yeniden kurulmadı, assertion kaldırılmadı.
- CI 37990630058 QA işi eski ses metni beklentisiyle başarısızdı. Son dalın QA işi 53 Python kontrolünden geçti; yerelde de aynı 53 kontrol ve Maestro YAML/pilot politika denetimi geçti. Önceki koşunun native işleri yeni push nedeniyle iptal edildi; bunlar başarı sayılmaz.
- `16.4` iş adı **Xcode** sürümüdür. `ci-simulator.json` ve runtime seçimi Xcode 16.4 için iOS **18.5**, Xcode 26.2 için iOS **26.2** kullanır. iOS 16.4 kabulü yapılmış değildir. Devir belgelerindeki sürüm adlandırması düzeltildi.

## Yeni koşu kanıtı

| İş | Sonuç | İncelenen kanıt |
| --- | --- | --- |
| QA | Başarılı | 53 Python testi, YAML/pilot politika, içerik denetimi |
| Flutter | Başarılı | Format, temiz analiz, 205 test/coverage, debug APK ve varlık denetimi |
| Veritabanı | Başarılı | SQL, gerçek PostgreSQL yarış kontrolleri, Node ve Deno işleri |
| Android release size | Başarılı | Teknik pilot split APK ve varlık denetimi; üretim imzası değildir |
| Android API28 / google_apis | Başarılı | Artifact `11645793320`: JUnit 7/7 uygulama + ayrı 1/1 teknik ses, session passed, driver_prepared, hash eşleşmesi |
| Android API35 / default | Başarılı | Artifact `11645274762`: JUnit 7/7 uygulama + ayrı 1/1 teknik ses, session passed, driver_prepared, bütün commands tamamlanmış |
| Xcode16.4 / iOS18.5 | Başarılı | Artifact `11646123483`: iPhone16/iOS18.5, JUnit 7/7 uygulama + ayrı 1/1 teknik ses, session passed, driver_prepared, bütün commands tamamlanmış |
| Xcode26.2 / iOS26.2 | Başarılı | Artifact `11646701660`: iPhone16/iOS26.2, JUnit 7/7 uygulama + ayrı 1/1 teknik ses, session passed, driver_prepared, bütün commands tamamlanmış |

İki Android cihazdaki kullanıcı APK SHA-256: `5fc3e772a1b517ea5bb39df7fb579e21cca0e35f7ac565dc3a536476ab8f164e`.
Ayrı teknik ses APK SHA-256: `b86be715a2b98aa29a546e60be446f829ce04c4b6266e628913d11d0de759837`.
Kurulu APK ile beklenen paket hash değerleri Android API28 ve API35'in uygulama/ses oturumlarında eşleşir. iOS oturumlarında `installed_build_hash` ölçülmemiştir (`null`); iOS kurulu build hash kabulü iddia edilmez.

## Yayın sınırı

Bu turda yerel tam sürüm preflight `blocked/157`, MVP kapsam preflight `blocked/546` döndü. Sayılar eksik kanıt kayıtlarıdır, yazılım hatası sayısı değildir. 54 sentetik taslak sesin uzman/dil, dinleme ve dağıtım hakkı kabulü açık; Arapça telbiye kaydı yoktur. Canlı Supabase/Firebase/APNs/GPS ve moderasyon/silme işletimi, saha/rota, fiziksel cihaz ve üretim imzası kabulü yoktur. CI başarısı bunları tamamlamaz.

Bu turun değişikliği yalnız kanıt/devir belgeleridir; uygulama ve test kodu değişmedi. Son belgesel push yeni CI başlatırsa bu sonuç önceki doğrulanmış kod koşusuna aittir; yeni koşu ayrı izlenir.
