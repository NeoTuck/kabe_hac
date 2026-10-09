# Sanal sunucuya devir — 10 Ekim 2026

## Devir sonrası doğrulama

**10 Ekim CI/native doğrulaması:** `ff6db65` / [CI 37991790287](https://github.com/NeoTuck/kabe_hac/actions/runs/37991790287) completed/success; sekiz iş başarılı. 205 Flutter ve 53 Python kontrolü, format/analiz, veritabanı ve teknik mobil derlemeler geçti. Android API28/API35 ve Xcode16.4/iOS18.5 ile Xcode26.2/iOS26.2 iPhone16 simülatörde yedi uygulama + ayrı teknik ses vakası geçti; dört artifact ZIP, JUnit/session/commands ve Android kurulu APK hash eşleşmesi bağımsız incelendi. PR test merge `33f37b9` ile dal kodunun dosya ağacı aynı. Önceki eski seçici, prova kaydırması ve QA ses beklentisi düzeltmeleri zaten daldaydı; yeni uygulama hatası bulunmadı, yalnız devir/kanıt belgeleri güncellendi. `16.4` iOS değil Xcode sürümüdür. Full preflight blocked/157, MVP kapsam blocked/546; uzman/ses hakkı/canlı servis/fiziksel cihaz/üretim imzası kabulü yoktur. Ayrıntı `docs/31-ci-native-dogrulama-2026-10-10.md`.

## Kodun bulunduğu yer

- Depo: `https://github.com/NeoTuck/kabe_hac`
- Çalışma dalı: `codex/mvp1-pilot`; açık taslak PR: <https://github.com/NeoTuck/kabe_hac/pull/1>
- Ana durum ve dış engeller: `AGENTS.md`, `docs/29-plan-uygulama-durumu.md`; başlangıç iş listesi: `docs/25-profesyonel-surum-son-isler.md`, tam deneyim planı: `docs/27-tam-kullanici-deneyimi-uygulama-plani.md`.
- Bu dosya yazılırken önceki commit `3f2248e` için [CI 37990630058](https://github.com/NeoTuck/kabe_hac/actions/runs/37990630058) sürüyordu. En son commit ve CI sonucunu GitHub'dan yeniden kontrol et.

## Yapılmış teknik işler

1. **Ses:** 53 Umre/Hac anlatımı ile telbiyenin bir Türkçe anlam kaydı olmak üzere 54 **sentetik taslak** ses uygulama varlığına eklendi. Rehber ve prova aynı kayıtları çevrimdışı kullanır; metin kimliği, sürüm ve hash denetlenir. Ekran/medya etiketleri taslak kökeni söyler. Lisans envanteri hak ve dinleme incelemesini bekliyor. Arapça telbiye kaydı yok.
2. **Deneyim ve prova:** Dört sekmeli Rehber/Yolculuk/Kafile/Ayarlar düzeni, kaldığı yer, ayrı prova kayıtları, adım sırası/seçimi, özet, soyut 2D açıklama, ses/çevrimdışı paket/kafile kullanım kartları kodlandı. Prova gerçek ibadet ilerlemesini değiştirmez.
3. **Veri ve Kafile güvenliği:** Yerel veri silme, önce kayıtlı push tokenını uzak tarafta iptal eder; iptal başarısızsa kayıtları korur. Sohbette şikâyet, engelleme ve engel kaldırma; sunucuda yalnız yetkili rol için şikâyet kuyruğu, sayfalama, kilitli inceleme geçişi ve audit kodlandı. Hesap silme isteğine ek olarak yetkili operasyon/rehber ve yarış/sahiplik korumaları hazırlandı.
4. **Yayın kapıları:** Gizlilik/destek/hesap silme/kullanım koşulları bağlantı kapıları ve sürümlü MVP kapsam denetimi eklendi. Yapılandırma ve gerçek kabul olmadan canlı Kafile kapalı. Teknik QA dosyası kullanıcı APK'sından dışlanır; kasıtlı paketli taslak sesler artık yanlışlıkla QA dosyası sayılmaz.

## Devir anındaki doğrulama ve açık CI işi (tarihsel)

- Hedefli yerel veri silme widget testleri 5/5, mobil QA yapılandırma testleri 12/12 geçti; Flutter analiz temiz. Kullanıcının tercihi nedeniyle tüm test paketi yerelde tekrarlanmadı.
- [CI 37967154898](https://github.com/NeoTuck/kabe_hac/actions/runs/37967154898): QA, veritabanı, Flutter test/analiz, Android debug ve release APK başarılı. Android API28/API35 ekran işlerinde 4/7 akış geçti; eski Umre kartı seçicileri ve aşağıda kalan prova düğmesi nedeniyle 3 akış düştü. Xcode 16.4 / iOS 18.5 kanıtında eski seçiciyle iki akış düştü. Bunlar `.maestro/flows/01-umre-girisleri.yaml`, `03-rehber-ses-durumu.yaml`, `05-prova.yaml` içinde düzeltildi.
- [CI 37990630058](https://github.com/NeoTuck/kabe_hac/actions/runs/37990630058): Son bakışta veritabanı, Flutter ve Android release başarılı; iOS/Android cihaz işleri sürüyordu. `qa-foundation`, eski `tools/test_mobile_qa.py` beklentisi nedeniyle düştü. Bu beklenti güncellendi ve yerelde 12/12 geçti. Bu düzeltmeyi içeren **yeni commit'in CI sonucunu** doğrula; önceki koşunun başarısız QA sonucunu geçmiş sayma.
- Cihaz akışları başarısız olursa `gh run view <id> --json jobs` ile işi bul, GitHub Actions `build/mobile-qa` kanıt paketindeki `commands.json`, erişilebilirlik ağacı ve ekran görüntüsünden ilk başarısız assertion'ı incele. Gerçek assertion'ı kaldırma veya cihaz testini geçmiş sayma.

## Sıradaki işler

1. **CI incelemesi tamamlandı:** Sonuç ve dört platform kanıtı `docs/31` içinde. Yeni kod değiştiğinde yeniden kabul gerekir. Tarihsel görev: `git status --short --branch` ile başla; `codex/mvp1-pilot` dalının en son commit'ini çek. En son PR CI'sının bütün işlerini incele. Yeni QA düzeltmesinin geçtiğini ve Android API28/API35 ile Xcode 16.4/26.2 (iOS 18.5/26.2) akışlarının sonucunu doğrula; gerçek hata çıkarsa küçük düzeltme yapıp aynı dala normal push et.
2. Dinî/dil uzmanları 53 adım, dua/Arapça/okunuş/anlam ve üç Hac profil uygulanabilirliğini sürüm/tarihle onaylamalı. 54 ses için model/çıktı dağıtım hakkı ve metinle dinleme kararı, eksik Arapça telbiye için ayrı kayıt/izin gerekir. Bunlar gelmeden `approved` yazma.
3. Gerçek Supabase/Firebase/APNs test projesi, iki hesap/iki kafile, push/GPS/şikâyet/engel/silme işletim kabulü; saklama politikası, moderasyon ve silme sorumlusu, gerçek URL'ler ve kullanım koşulu sürümlü kabul kaydı gerekir. Credential veya sonuç uydurma.
4. Kritik gezi/rota/dil verisinin insan incelemesi, fiziksel Android/iPhone ses/çevrimdışı/erişilebilirlik kabulü, üretim imzaları, TestFlight/AAB ve mağaza beyanları gerekir. Bunlar tamamlanmadan tam sürüm veya mağaza yayını hazır deme.

## Sanal sunucudaki ajana verilecek görev

> `NeoTuck/kabe_hac` deposunda `codex/mvp1-pilot` dalından devam et. Önce `AGENTS.md`, `docs/29-plan-uygulama-durumu.md` ve `docs/30-sanal-sunucu-devir-2026-10-10.md` dosyalarını oku; git durumunu ve PR #1'in en son CI'sını kontrol et. Mevcut teknik parçaları yeniden kurma. Öncelik, QA beklentisi düzeltmesinin ve Android API28/API35 ile Xcode 16.4/26.2 (iOS 18.5/26.2) ekran akışlarının son CI'da geçmesidir. Başarısız işlerin kanıt paketinden gerçek nedeni bul, küçük düzeltme yap, ilgili statik/otomatik doğrulamayı çalıştır ve normal push et. Sonra kodla tamamlanabilen açık güven/UX işlerini ilerlet. Dinî uzman onayı, ses hakkı, canlı servis, gerçek URL, saha verisi, fiziksel cihaz veya imza kanıtı olmadan bunları tamamlanmış gösterme. Sonunda çalışan kodu, CI sonucunu ve dış girdilere bağlı kalan işleri ayrı yaz.
