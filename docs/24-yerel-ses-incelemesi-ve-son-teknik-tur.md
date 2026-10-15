# Yerel ses incelemesi ve son teknik tur — 9 Ekim 2026

Bu kayıt, PR #1'in `a481eec` başlangıcından sonraki çalışmayı anlatır. Yerel Türkçe taslak ses üretimi ve yayın sesi birbirinden ayrılmıştır. Uzman, hak sahibi, test projesi, fiziksel cihaz veya imza kararı verilmiş sayılmaz.

## Gerçek çıktı

- `tools/produce_local_review_audio.py`, [EMA Lightning](https://github.com/canberk7/ema-lightning) 1.0.4 motorunu ve [model](https://huggingface.co/canberkkkkkk/ema-lightning) revizyonu `7a6ba1ad216bb2f1da9863f80ac8770a6a807632` dosyalarını sabitleyerek yerelde çalıştırır. Türkçe metin normalleştiricisi [normalizer-tr](https://github.com/erdemtuna/normalizer-tr) 0.4.0'dır. Model dosyası SHA-256 değerleri `docs/qa/source-registry.v1.json` ve her makbuzdadır. İleride `main` değişse bile hazırlık aracı değişken ağırlıkları sessizce kullanmaz.
- 53 adım anlatımı ve telbiyenin **Türkçe anlamı** için bir kayıt: toplam **54 sentetik AAC/m4a dosyası**, 7.453.343 bayt ve 903,17 saniye. 18 Umre ve 35 Hac adım kimliği/sürümü ile bağlar `review-index.json` içindedir. Arapça telbiye üretilmedi. Demo kayıtları kullanılmadı.
- Bütün dosyalar SHA-256, dosya boyutu, sürüm bağı, tek AAC akışı ve tam decode kontrolünden geçti. Her kayıttaki 250 ms baş/son dolgu için ilk/son 100 ms -30 dBFS altında kaldı; codec taşmasını önlemek için PCM tepe sınırı 0,7 tutuldu. Bu ölçümler kelimelerin doğru söylendiğini veya baş/son kelimenin TTS tarafından atlanmadığını kanıtlamaz. Her makbuzun `technicalQA` alanında `humanVoiceVerified=false`, `rightsVerified=false` ve `listeningReview=required` korunur.
- Bütün sesler ve makbuzlar Git dışındaki `release-inputs/local-review-audio-v2/` içindedir. Kullanıcıya aktarılabilir kopya `Desktop/Kabe-Hac-ses-inceleme-2026-10-09.zip`; ZIP SHA-256 `d54efeec3c92990ee12f635c7df36188305af6f906e45479496a18993ac124ff`. ZIP bütünlük testi geçti. Uygulamanın `assets` ağacına hiçbir taslak ses eklenmedi.

## Lisans ve kullanım sınırı

| Aday | Yazılım/model/veri | Karar |
| --- | --- | --- |
| Mevcut Diyanet telbiye MP3'leri | Erişilebilir dosya, çevrimdışı ticari dağıtım izni bulunmadı. Hash ve konum kaynak envanterinde. | Uygulamaya alınmadı. Hak sahibinin yazılı izni gerekir. |
| Piper Türkçe `dfki` | Piper yazılımı açık olsa da [model kartı](https://huggingface.co/rhasspy/piper-voices/blob/main/tr/tr_TR/dfki/medium/MODEL_CARD) eğitim veri kümesini CC-BY-NC-SA-4.0 gösterir. | Ticari dağıtım için reddedildi. |
| MMS Türkçe | [Model kartı](https://huggingface.co/facebook/mms-tts-tur) CC-BY-NC-4.0. | Ticari dağıtım için reddedildi. |
| EMA Lightning | [Motor lisansı](https://github.com/canberk7/ema-lightning/blob/main/LICENSE), [ağırlık/model kartı](https://huggingface.co/canberkkkkkk/ema-lightning) ve [normalleştirici lisansı](https://github.com/erdemtuna/normalizer-tr/blob/main/LICENSE) Apache-2.0; model kartı ticari kullanımı belirtiyor. Model kartı yaklaşık 1000 saatlik iç, tek konuşmacılı korpus diyor; ayrı korpus kullanım/onam zinciri yayımlanmıyor. | Yalnız kapalı taslak dinleme incelemesi. Hak zinciri açıklığı, metin ve işitsel inceleme tamamlanmadan yayın varlığı yapılmaz. Sentetik olarak etiketlenir; insan kaydı diye sunulmaz. |

Motor/model/normalleştirici uygulama APK'sına girmez. Kaynak adları ve tam dosya hash'leri makbuzlarda tutulur. Model sahibine gönderilmeye hazır hak soruları: eğitim korpusunu kullanma ve model çıktısını ticari uygulamada çevrimdışı dağıtma yetkisi, konuşmacı rızası, ek atıf/değişiklik koşulları ve Apache-2.0 beyanının ilgili sabit revizyona uygulanması. Gerçek hak sahibi yanıtı alınmış gibi yazılmaz.

## Diğer ürün alanları

- Harita ve gezi: mevcut Geofabrik ODbL şehir paketleri, 2.928 OSM yer kaydı, yerel MapLibre, paket indirme/hash/yeniden deneme/geri dönüş ve yer/favori akışı korunur. [CI 37939054112](https://github.com/NeoTuck/kabe_hac/actions/runs/37939054112) iOS 26.2 ve Android API28/API35 yedi uygulama akışını, ayrıca teknik ses vakasını geçti; iOS 16.4 sürücü hazırlığında engellendi. iOS 26.2'nin gerçek indirme/render ekran görüntüsü `docs/store-draft/mekke-cevrimdisi-harita-iphone16.png` dosyasındadır. Bu vaka gerçek uçak modu veya fiziksel saha kabulü değildir.
- Prova: mevcut ayrı SQLite prova kayıtları, duraklatma/devam/yeniden açma ve taslak ses yayın filtresi korunur. Yeni inceleme sesleri provaya bağlanmadı; böylece taslak ses onaylı gibi oynatılmaz. İlerleme ve favoriler bu dilimde değiştirilmedi.
- İçerik: 18 Umre/35 Hac metni ve telbiye kartı kaynaklı **taslaktır**. Diyanet [İlmihal I](https://webdosya.diyanet.gov.tr/DiyanetAnasayfa/UserFiles/DiniBilgiler/ilmihal_cilt_1.pdf) Hac çeşitlerini basılı s. 548–550'de ayrı anlatır; mevcut Hac profil matrisi uzman kararı bekler. Hiçbir `approved` alanı yazılmadı.
- Servis: kullanılabilir gerçek Supabase/Firebase test kimliği bu depoda yok. SQL/outbox/push/GPS teknik kodu canlı iki hesap/iki kafile kabulü değildir. Gerçek kullanıcıya mesaj veya bildirim gönderilmedi.
- Mağaza: `docs/22-magaza-metinleri-ve-gorsel-taslak.md` gerçek çevrimdışı haritayı ve teknik ekran görselini açıklayacak şekilde düzeltildi. Üretim Android/iOS imzası ve fiziksel cihaz kabulü yok; main merge ve mağaza gönderimi ayrıca son onay bekler.

## Yerel doğrulama ve sıradaki kabul

`dart format` temiz; Flutter analizinde sorun yok ve 190/190 test geçti. Python 49/49 test geçti. Android debug APK ve Xcode 26.6 / iOS 26.5 SDK ile iOS simülatör `.app` bu Mac'te derlendi. İlk iOS denemesi, sistemin aktif geliştirici dizini Command Line Tools olduğu için `objective_c` kancasının boş `xcrun` çıktısında durdu; Xcode yolunu kanca alt işlemine de aktaran geçici `xcrun` sarmalayıcısıyla aynı kaynak başarıyla derlendi. Bu ortam düzeltmesi uygulama kodu veya paket sürümü değiştirmedi. Yerel simülatör akışı ve son kodun CI sonucu ayrıca izlenir. `release_preflight --evidence-dir release-inputs` gerçek eksik girdilerle `blocked/155` kalır; inceleme ZIP'i bu engelleri kapatmaz.

Tek sonraki içerik kabulü: uzman/Arabist tarafından metin ve telaffuzun tarihli onayı, hak sahibinden telbiye kaydı veya sentetik sesin eğitim verisi/çıktı hak açıklığı, ardından aynı `textId`/`textVersion` için dinlenmiş sesin katalog/pakete alınması. Canlı servis, saklama politikası, fiziksel cihaz ve üretim imzaları ayrıca gerçek sahip girdisi ister.
