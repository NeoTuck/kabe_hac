# Tek Umre içeriği ve mobil doğrulama

Bu dilim, bir adımın içerik hazırlama kaydından uygulama kartına kadar olan teknik hattını kurar. Gerçek dinî içerik, uzman onayı veya ses kullanım izni sağlanmadığı için hiçbir kayıt yayın içeriği olarak işaretlenmemiştir.

## Seçilen adım

`U02.2 — Niyet ve telbiye` seçildi. Bu seçim, adım anlatımı ile Arapça dua/okuma ve Türkçe anlam seslerinin birbirinden ayrı yönetilmesini aynı kartta sınamak için yapıldı. Adımın başlığı mevcut envanterden gelir; açıklama, dua ve telaffuz üretilmedi.

Uygulama kataloğunda şu hazırlama kayıtları bulunur:

- `U02.2-text-v1`: adım metni sürümü.
- `P-U02.2-01` / `P-U02.2-01-text-v1`: boş dua hazırlama kaydı.
- `A-U02.2-TR-01`: Türkçe anlatım kaydı.
- `A-P-U02.2-AR-01`: Arapça okuma kaydı.
- `A-P-U02.2-ANLAM-01`: Türkçe anlam kaydı.

Bütün kayıtların durumu `draft`; dosya, kaynak, inceleyen ve hak sahibi alanları boştur. Uygulama bunları “Taslak” ve “henüz sağlanmadı” ifadeleriyle gösterir. Doldurma örneği [U02.2 içerik şablonundadır](templates/U02.2-icerik-sablonu.json). Bu şablon uygulama tarafından yüklenmez ve boş değerleri yayın içeriği sayılmaz.

## Şema ve kabul kuralları

Adım ve dua kayıtları `textVersion`, `sourceTitle`, HTTPS `sourceUrl`, `sourceLocation`, `sourceUsageRights`, `reviewedBy` ve `reviewedAt` alanlarını destekler. Durumlar `draft`, `pendingReview` ve `approved` değerleridir. İnceleme bekleyen bir metin için sürüm ve kaynak alanlarının tamamı gerekir. Onay için ayrıca inceleyen ve ISO tarih gerekir. Kaynak bağlantısı bulunması onay anlamına gelmez; kaynak metninin kullanım koşulu `sourceUsageRights` içinde ayrıca kaydedilir.

Ses kaydı `kind`, `textId`, `textVersion`, `asset`, `recordingOwner`, `rights`, `reviewedBy` ve `reviewedAt` alanlarını taşır. `turkishNarration`, `arabic` ve `turkishMeaning` ayrı kimliklerdir. Onaylı ses; onaylı metne, aynı metin sürümüyle bağlanmalı ve dosya, kayıt sahibi, kullanım hakkı ile inceleme alanlarını içermelidir. Kırık geri bağlantı, bilinmeyen metin, metin–ses sürüm farkı, eksik kaynak ve geçersiz URL katalog yüklenirken reddedilir. Kaynak kullanım koşulu ile ses kayıt hakkı ayrı alanlardır.

## Ekran davranışı

Adım ve dua kartı inceleme durumunu metinle gösterir. Taslak kartta boş dinî alanların durumu açıklanır. Veri onaylandığında dua kartı Arapça metni RTL ve büyük yazıyla, isteğe bağlı okunuşu, Türkçe anlamı ve kaynak konumunu gösterir. Her ses türü ayrı kontrol olarak açılır; ortak `NarrationService` aynı anda tek kayıt oynatır ve ekran/adım değişiminde sesi durdurur. Eksik veya onaysız ses yerine durum metni görünür. Açma, oynatma, bitirme ve tekrar dinleme ilerleme işaretini değiştirmez.

## Test kapsamı

Katalog testleri taslak yüklemeyi, eksik isteğe bağlı alanları, zorunlu kaynakları, geçersiz URL'yi ve metin–ses sürüm uyuşmazlığını kapsar. Widget testleri `U02.2` taslağının onaylı gibi sunulmadığını, boş dua/ses durumunu, onaylı test verisinde doğru dua metni ve RTL yönünü doğrular. Mevcut ilerleme testleri içerik sürümü değişse bile eski oturumun kimliğini, konumunu ve işaretlerini koruduğunu; ses bitişinin işaret eklemediğini doğrular. Son çalıştırmada `flutter analyze` sorunsuz tamamlandı ve 19 testin tamamı geçti.

## Mobil araç ve derleme durumu

5 Ekim 2026'da Homebrew Android SDK'sı `/opt/homebrew/share/android-commandlinetools` altında bulundu ve `flutter config --android-sdk` ile Flutter'a tanıtıldı. Android 36 platformu, build-tools 36.0.0, build-tools 28.0.3, NDK 28.2.13676358 ve CMake 3.22.1 kuruldu; lisanslar kabul edilmiş durumdadır. `flutter build apk --debug` başarıyla tamamlandı. Üretilen `build/app/outputs/flutter-apk/app-debug.apk` 159 MB, SHA-256 değeri `3143cd77ba39247af7c237b18ac50f1d25e4a7b4a482ef726a48460add5a01f0` oldu.

iOS denemesi `flutter build ios --debug --no-codesign` ile başlatıldı ve derleme aşamasına geçmeden `Application not configured for iOS` sonucuyla durdu. `flutter doctor -v`, yalnız Command Line Tools bulunduğunu; tam Xcode/xcodebuild ve CocoaPods olmadığını doğruladı. Tam Xcode kurulmalı, ardından `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, `sudo xcodebuild -runFirstLaunch` çalıştırılmalı ve CocoaPods kurulmalıdır. Bu işlemler yönetici yetkisi ve Apple lisans etkileşimi gerektirir.

Başlangıçta bağlı Android/iOS cihazı yoktu; Flutter yalnız macOS ve Chrome hedeflerini gördü. Kurulu Android 35 `FaceGuard_Test` AVD'si başlatılarak debug APK yüklendi. Ana sayfa, `U02.2` taslak ve boş dua kartı, erişilebilirlik açıklamaları ve Arapça teknik RTL örneği ekranda doğrulandı. Uygulama zorla kapatılıp yeniden açıldığında “Kaldığım yerden devam · Umre” üzerinden yeniden `U02.2` açıldı. Sistem yazı ölçeği 1.5 yapıldığında metinler büyüdü ve ekran kaydırılabilir kaldı; test sonunda ölçek 1.0'a döndürüldü. Teknik ses kontrolü oynatma sırasında “Duraklat” durumuna geçti ve logda Flutter/ses hatası görülmedi. Emülatör `-no-audio` ile çalıştığı için işitsel kalite doğrulanmadı. Emülatör test sonunda kapatıldı. Gerçek Android/iPhone üzerinde hoparlör, kulaklık, kesinti ve yaşam döngüsü kontrolleri açık iştir.

## Sonraki parça

Sonraki tek parça, kullanıcıdan gelen `U02.2` kaynak paketi ile uzman inceleme kaydını şablona işlemek; metin sürümü kilitlendikten sonra hak sahibi ve kullanım izni belli üç gerçek ses dosyasını bağlayıp Android cihazda dinleme doğrulaması yapmaktır.

## 6 Ekim 2026 geniş kapsam eki

Birleşik ürün programı, modül kabul durumları, veri/izin sınırları ve yeni kişi-gün tahmini `docs/04-birlesik-gelistirme-programi.md` dosyasına taşındı. `U02.2` için gerçek uzman onayı ve izinli ses gereksinimi değişmedi. Teknik altyapının genişlemesi bu taslağı onaylı içeriğe çevirmedi.
