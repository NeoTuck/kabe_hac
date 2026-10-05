# AGENTS.md

Bu dosya, bu depoda çalışan insan ve AI geliştiriciler için ana çalışma talimatıdır. Kök dizinin tamamına uygulanır. Projenin hangi aşamada olduğu, sıradaki tek iş ve teknik sınırlar burada tutulur.

## 1. Çalışmaya başlama sırası

Her çalışmada önce şunları yap:

1. `git status --short --branch` ile mevcut değişiklikleri kontrol et ve kullanıcı değişikliklerini koru.
2. Bu dosyadaki **Mevcut durum** ve **Sıradaki tek iş** bölümlerini oku.
3. İlgili teknik belgeyi ve değiştireceğin kodu incele.
4. Tamamlanmış aşamaları yeniden kurma; sıradaki işi çalışan ve test edilmiş küçük bir parça halinde uygula.
5. Kod değiştiyse biçimlendirme, analiz ve testleri çalıştır.
6. Bir aşamanın durumu gerçekten değiştiyse bu dosyadaki durum, kanıt ve sıradaki iş alanlarını aynı değişiklik içinde güncelle.

Yalnız plan veya öneri bırakma. Erişilebilen proje kapsamında uygulamayı tamamla. İnsan girdisi zorunluysa dinî içerik, uzman onayı veya kullanım hakkı uydurma; teknik olarak bağımsız kalan işleri bitir ve gereken girdiyi açıkça yaz.

## 2. Mevcut durum

**Son doğrulama:** 5 Ekim 2026  
**Aktif aşama:** 3 — İçerik ve mobil doğrulama  
**Depo:** `https://github.com/NeoTuck/kabe_hac`  
**Ana dal:** `main`

### Tamamlananlar

- Teknik prototip ve ana uygulama akışları hazır.
- Ana sayfa, öğrenme/yolculuk biçimleri, Umre/Hac seçimi, Hac türü, liste ve ayrıntı ekranları çalışıyor.
- 18 Umre ve 35 Hac alt kimliği sürümlü yerel JSON kataloglarında bulunuyor.
- Öğrenme/yolculuk ve Hac profili bazlı SQLite ilerleme kayıtları ile eski Umre kimlik migrasyonu hazır.
- Tavaf ve sa‘y manuel sayaçları var; ses veya kart olayı ilerlemeyi otomatik değiştirmiyor.
- Metin, dua ve ses için kaynak, sürüm, inceleme ve kullanım hakkı alanları ile katalog doğrulamaları hazır.
- `U02.2 — Niyet ve telbiye` için boş/taslak içerik hattı ve dua kartı teknik olarak çalışıyor.
- Arapça RTL, büyük yazı, ekran okuyucu etiketleri ve üç ayrı ses türü için ekran desteği var.
- Android debug APK derlendi ve Android 35 emülatörde temel akış doğrulandı.
- Son yerel kontrolde `flutter analyze` hatasız ve 19 test başarılıydı.

### Açık noktalar

- Uygulamada uzman onaylı gerçek dinî metin, dua veya telaffuz bulunmuyor.
- İzinli gerçek insan ses kaydı bulunmuyor; mevcut ses yalnız teknik demodur.
- Hac türlerinin uygulanabilirlik matrisi uzman onayından geçmediği için Hac akışı önizlemedir.
- Gerçek Android/iPhone cihazında ses, kesinti, kulaklık ve yaşam döngüsü testi yapılmadı.
- iOS derlemesi tam Xcode ve CocoaPods kurulumu olmadığı için doğrulanmadı.

## 3. Sıradaki tek iş

### Aşama 3'ü ilk gerçek U02.2 paketiyle tamamla

Kullanıcı tarafından sağlanan ve uzman incelemesi bulunan `U02.2` paketini mevcut şemaya bağla. Bu iş yalnız şu girdiler geldiğinde içerik bakımından tamamlanabilir:

- Kaynak başlığı, HTTPS bağlantısı, sayfa/bölüm ve kaynak kullanım koşulu.
- Türkçe açıklama.
- Varsa Arapça metin, okunuş ve Türkçe anlam.
- İnceleyenin adı, inceleme tarihi ve açık onay durumu.
- Türkçe anlatım, Arapça okuma ve Türkçe anlam için ayrı ses dosyaları.
- Her ses için kayıt sahibi ve uygulamada kullanım hakkı bilgisi.

Uygulama adımları:

1. `docs/templates/U02.2-icerik-sablonu.json` girdilerini incele.
2. Metin ve ses sürümlerini eşleştir; kaynak hakkı ile ses kullanım hakkını ayrı tut.
3. Kayıtları `assets/content/umre_inventory.v1.json` içine ekle ve taslak/onay durumunu kanıta göre ayarla.
4. Gerekli sesleri `assets/audio/` altına ekleyip `pubspec.yaml` içinde tanımla.
5. Dua kartını ve üç ses türünü test et; ses olaylarının ilerlemeyi değiştirmediğini koru.
6. Gerçek Android cihaz varsa büyük yazı, RTL, ses, kapatıp açınca devam ve ses kesintilerini doğrula.
7. Sonucu `docs/03-icerik-ve-mobil-dogrulama.md` içinde güncelle.

**Girdiler yoksa:** Dinî metin, Arapça metin, telaffuz, inceleyen kişi veya kullanım izni üretme. `draft` kaydını `approved` yapma. Aşama 3'ü tamamlandı sayma ve Aşama 4'e geçildiğini yazma.

## 4. Genel yol haritası

| Aşama | Kapsam | Durum | Tamamlanma ölçütü |
| --- | --- | --- | --- |
| 1. Teknik prototip | Kart, RTL Arapça örnek, yerel teknik ses, SQLite | Tamamlandı | Teknik kart, ses ve kalıcı kayıt test edildi. |
| 2. Ana uygulama | Seçimler, listeler, ayrıntı, profil bazlı ilerleme ve sayaçlar | Tamamlandı | Ana akışlar ve migrasyon testleri geçiyor. |
| 3. İçerik ve mobil doğrulama | İlk kaynaklı/onaylı içerik hattı, dua kartı, Android/iOS doğrulaması | Devam ediyor | İlk gerçek onaylı U02.2 paketi ve izinli sesler bağlanır; uygun cihaz kontrolleri kaydedilir. |
| 4. Tam Umre rehberi | 18 adımın metin, dua ve sesleri; mevcut tavaf/sa‘y sayaçlarıyla tam akış | Sırada | 18 adım kaynaklı, incelenmiş, sürümlü ve cihazda doğrulanmıştır. |
| 5. Ses ve çevrimdışı paketler | İndirme, bütünlük kontrolü, güncelleme, arka plan ve kesinti yönetimi | Sırada | Paket sürümü/hatası güvenli yönetilir; yaşam döngüsü testleri geçer. |
| 6. Tam Hac rehberi | Temettü, İfrad, Kıran için onaylı matris, 35 alt adım ve Cemarat sayacı | Sırada | Uzman onaylı profil matrisi ve içerikler doğru yönlendirilir. |
| 7. Kalite ve kullanıcı pilotu | Arama, favoriler, erişilebilirlik, eski cihazlar, hata düzeltmeleri | Sırada | Pilot geri bildirimleri ve hedef cihaz matrisi tamamlanır. |
| 8. Mağaza ve yayın | Son içerik onayı, Android/iOS mağaza süreçleri ve destek | Sırada | İmzalı sürümler, mağaza kayıtları, gizlilik/destek akışları hazırdır. |

Aşamaları sırayla ilerlet. Bir aşamayı yalnız tablodaki tamamlanma ölçütleri kanıtlandığında `Tamamlandı` yap.

## 5. Teknoloji ve çalışma ortamı

- **İstemci:** Flutter `3.47.6`, Dart `3.13.5`, Material arayüz.
- **Durum ve kalıcı kayıt:** `sqflite`; veritabanı şema sürümü `4`.
- **Ses:** `just_audio`; aynı anda tek ses oynatan `NarrationService`.
- **İçerik:** `assets/content/` altında sürümlü JSON; şema sürümü `1`.
- **Test:** `flutter_test` ve SQLite testleri için `sqflite_common_ffi`.
- **Android:** En düşük API 28; debug APK ve Android 35 emülatör doğrulandı.
- **iOS:** Proje doğrulaması açık; tam Xcode ve CocoaPods gerekiyor.
- **Sunucu:** Şu anda backend, hesap sistemi veya uzaktan içerik servisi yok.

Ana paketler `pubspec.yaml` içinde kilitlenir. Paket yükseltmesini ayrı, test edilen bir değişiklik olarak yap; özellik değişikliğiyle karıştırma.

## 6. Kod ve veri haritası

- `lib/main.dart`: uygulama başlangıcı ve bağımlılıkların kurulması.
- `lib/selection_screens.dart`: ana seçim, kullanım biçimi ve Hac profili ekranları.
- `lib/guide_screens.dart`: rehber listesi, ayrıntı ve dua kartları.
- `lib/guide_catalog.dart`: JSON modelleri, durumlar ve içerik doğrulaması.
- `lib/content_repository.dart`: katalogların yüklenmesi.
- `lib/progress_store.dart`: SQLite şeması, oturumlar, işaretler ve migrasyon.
- `lib/narration_service.dart`: tek kanallı ses yaşam döngüsü.
- `lib/audio_controls.dart`: oynat, duraklat ve tekrar kontrolleri.
- `lib/counter_screen.dart`: manuel tavaf/sa‘y sayaçları.
- `assets/content/umre_inventory.v1.json`: 18 Umre alt adımı ve içerik kayıtları.
- `assets/content/hac_inventory.v1.json`: 35 Hac alt adımı ve profil önizlemesi.
- `test/`: katalog, ilerleme, ayar, sayaç ve ekran akışı testleri.
- `docs/02-ana-yapi.md`: güncel mimari ve veri yapısı.
- `docs/03-icerik-ve-mobil-dogrulama.md`: Aşama 3 kanıtları ve cihaz durumu.

## 7. Değişmez ürün kuralları

- Dinî içerik uydurma, anlam veya telaffuz tahmin etme.
- Kaynak bulunmasını uzman onayı sayma.
- İnceleyen ve tarih alanlarını kendiliğinden doldurma.
- Kaynak kullanım koşulu ile ses kaydı kullanım hakkını ayrı kaydet.
- Taslak veya inceleme bekleyen içeriği onaylı yayın içeriği gibi gösterme.
- Onaylı sesin bağlı olduğu metin kimliği ve sürümü birebir eşleşmeli.
- Arapça, Türkçe anlatım ve Türkçe anlam seslerini ayrı kimliklerle yönet.
- Aynı anda tek ses çalmalı; ekran/adım değişince önceki ses durmalı.
- Kart açma, ses oynatma/bitirme/tekrarlama veya ileri gitme ilerlemeyi otomatik işaretlememeli.
- İçerik sürümü değiştiğinde eski ilerleme kaydını silme veya sessizce başka adıma taşıma.
- Hac profil kurallarını uzman onayı olmadan etkinleştirme.
- Sayaçlar, uzaktan indirme, ödeme veya bütün Hac içeriğini sıradaki işin kapsamına kendiliğinden ekleme.

## 8. Geliştirme ve doğrulama komutları

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Android ile ilgili bir değişiklikte araçlar uygunsa ayrıca:

```sh
flutter build apk --debug
```

iOS ile ilgili bir değişiklikte tam Xcode ve CocoaPods hazırsa ayrıca:

```sh
flutter build ios --debug --no-codesign
```

Araç eksikliği ile kod hatasını ayrı raporla. Emülatör başarısını gerçek cihaz testi olarak yazma; bir platformdaki başarıyı diğer platformun doğrulaması sayma.

## 9. Tamamlanma ve devir kuralı

Bir geliştirme parçası ancak şu koşullarda tamamlanmıştır:

- İstenen davranış çalışan kodla uygulanmıştır.
- İlgili anlamlı testler eklenmiş veya güncellenmiştir.
- Biçimlendirme, `flutter analyze` ve `flutter test` sonucu kaydedilmiştir.
- Gerçek içerik, uzman onayı, ses hakkı ve cihaz testi iddiaları kanıtla uyumludur.
- Durum değiştiyse bu dosyadaki **Mevcut durum**, yol haritası ve **Sıradaki tek iş** güncellenmiştir.
- Sonraki geliştirici, ek karar vermeden tek bir sonraki parçayı anlayabilir.

Commitlerde derleme çıktısı, `.dart_tool/`, gizli bilgi, imza anahtarı veya kişisel hesap verisi ekleme. Zorla push yapma ve kullanıcı değişikliklerini silme.
