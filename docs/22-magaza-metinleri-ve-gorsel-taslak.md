# Mağaza listeleme taslağı — 9 Ekim 2026

Bu metin ve görseller **teknik önizleme taslağıdır**, mağazaya gönderilmedi. Onaylı dinî içerik ve dağıtılabilir ses, canlı servis/gizlilik kararları, destek URL'si ve imzalı paket olmadan genel kullanıcı yayını için kullanılamaz. Ürün sahibi son sürümün gerçek işlevleriyle yeniden onaylar. Gerçek OSM şehir verisi kullanıcı seçimiyle indirilebilir; saha doğrulaması veya güvenli navigasyon değildir.

## Mevcut sürüme sadık Türkçe metin

**Ad:** Hac ve Umre Sesli Rehber

**Kısa açıklama:** Umre ve Hac başlıkları, kişisel takip, prova ve isteğe bağlı çevrimdışı şehir haritası.

**Açıklama taslağı:**

> Umre ve Hac için düzenlenmiş 18 ve 35 başlık envanterini öğrenme veya yolculuk biçiminde inceleyin. Kişisel işaretlerinizi ve manuel tavaf, sa‘y, cemarat sayaçlarını cihazınızda tutun. Kaldığınız başlığa dönebilir; ayrı tutulan, isteğe bağlı eğitim provasını duraklatıp sürdürebilirsiniz. Dilerseniz Mekke ve Medine için OSM kaynaklı çevrimdışı şehir verisi paketlerini indirip yer arama, ayrıntı ve favorileri kullanabilirsiniz. Yazı boyutu, açık/koyu görünüm ve kaynak/lisans ekranı mevcuttur.
>
> Bu sürüm teknik önizlemedir. Dinî metinler ve profil uygulanabilirliği uzman incelemesindedir; onaylı dua/ses ve canlı kafile hizmeti yoktur. OSM kayıtları canlı yoğunluk, kapı açıklığı veya güvenli yürüyüş rotası sağlamaz. Uygulamadaki işaretler ibadet geçerliliği kararı üretmez. Bu sınırlar kaldırılmadan genel kullanıcıya tam rehber vaadiyle sunulmaz.

Adın “Sesli Rehber” olması mevcut sürümde onaylı ses bulunduğu anlamına gelmez; genel yayın kararı öncesi ad/açıklama, gerçek ses varlığına göre gözden geçirilmelidir. Teknik test paketi uygulama mağazasında yayınlanmaz.

## Gerçek simülatör görselleri

Üç RGB PNG, `f9d8d3f` kodunun yerel iPhone 17 Pro / iOS 26.5 debug build'inden, yalnız test verisiyle çekildi. Her biri **1206 × 2622**, alfa kanalı yok. [Apple'ın güncel ekran görüntüsü ölçüleri](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) 6.3 inç iPhone için bu ölçüyü kabul eder. Görsellerde taslak/önizleme sınırları açıkça görünür. [Google Play görsel koşulları](https://support.google.com/googleplay/android-developer/answer/9866151) en boy oranı ve boyut açısından ayrıca Android cihaz görselleri ister; bu iPhone görüntüleri Android mağaza materyali sayılmaz.

Ek [Mekke çevrimdışı harita görseli](store-draft/mekke-cevrimdisi-harita-iphone16.png), PR #1 kodu `a481eec` için [CI 37939054112](https://github.com/NeoTuck/kabe_hac/actions/runs/37939054112) iOS 26.2 / iPhone 16 simülatöründeki gerçek paket indirme ve MapLibre akışından alındı. **1178 × 2556** PNG, SHA-256 `4cd05aec706801584da145d82165491b79409a951dbc91b4f3e85f1dc2ba70a4`. OSM/ODbL atfı, veri zamanı ve navigasyon sınırı ekranın üzerinde görünür. Mağaza teslimi için son imzalı kodda yeni görsel ve platform ölçü doğrulaması gerekir.

| Görsel | Gösterilen gerçek işlev | SHA-256 |
| --- | --- | --- |
| [Umre başlıkları](store-draft/umre-basliklari-iphone17pro.png) | 18 başlık ve taslak uyarısı | `a302162a9e0ff0a53d5e91028df6e3bc6e2e047ff7cafa81bff6d64299c9192f` |
| [İsteğe bağlı prova](store-draft/prova-iphone17pro.png) | Ayrı prova ve onay bekleyen metin durumu | `58c440b7009f0031ca87951d0f4331c91afd5beff6c75aa16efc8461ed1e542a` |
| [Ayarlar](store-draft/ayarlar-iphone17pro.png) | Görünüm ve yazı/ses hızı tercihleri | `49db389db1bc8af2fc75ba2ac3a4c85c1e7aaa15094d91c780f7934fe59a4c32` |

Ayrı Android API 35 / ARM64 emülatöründe profil teknik APK'sından [ana ekran](store-draft/android35-ana-ekran.png) alındı: RGB, 1080 × 1920, SHA-256 `28e0fbdc18c0720f78f401ee6144af8fc93a7f71ae558537585f4773bfb9f5dc`. Bu yalnız bir Android görsel adayıdır; Google Play'in iki ekran ve gerçek yayın paketi şartını tek başına karşılamaz.

Yayın günü görseller, onaylı içerikli imzalı sürümden yeniden çekilir ve her ekranın son paketle eşleşmesi kontrol edilir. İnceleme paketindeki sentetik taslak ses veya canlı kafile varmış gibi görsel eklenmez. Üretim destek kişisi/URL'si, gizlilik bağlantısı, mağaza yaş/ülke beyanı ve Android upload/Apple distribution erişimi gerçek hesap sahibi tarafından tamamlanır.
