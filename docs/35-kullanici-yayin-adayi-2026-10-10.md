# Kullanıcı yayın adayı — 10 Ekim 2026

**11 Ekim güncellemesi:** Başlangıç `df3f3f9` CI [38091307573](https://github.com/NeoTuck/kabe_hac/actions/runs/38091307573) completed/success; sekiz iş sonucu kontrol edildi. Aşağıdaki “CI bekleniyor/in_progress” kayıtları 10 Ekim anına aittir. Yeni koşul kabulü, ortak harita filtresi, profil/sürüm ilerleme koruması ve ses/native regresyon uygulaması [docs/36](36-teknik-yayin-adayi-2026-10-11.md) içinde; eski CI yeni kod kabulü değildir.

Durum: kod incelemeye hazırlanmıştır; dinî/hukuki kabul ve mağaza yayını tamamlanmamıştır. Tek dış girdi/izin/mağaza teslimi [yayın paketi](release-handoff/2026-10-10/README.md) içindedir.

## Kullanıcı davranışı

- PR #2'nin ilk kullanım değişikliği `codex/mvp1-pilot` dalına fast-forward alındı. İlk açılışta Umre öğrenmeye doğrudan başlanır; eski kullanıcı ana ekranda mod, Hac profili ve adım adını görerek devam eder. Kayıt okuma hatası boş yeni kullanıcı gibi gösterilmez. Umre/Hac, öğrenme/yolculuk, üç Hac profili ve prova kapsamı korunur.
- Hazırlık ekranı yalnız cihazdaki rehber, harita ve gerçekten onaylı/izinli ses dosyalarını kontrol eder; hazırlık seçimi kişisel ilerlemeyi değiştirmez. Eksik harita, yer veya ses doğrudan ilgili paket ekranına gider. Mevcut taslaklarla “hazır” denmez. Teknik dosya kontrolü, cihazda açma/dinleme veya dinî/saha kabulü sayılmaz.
- Paket yöneticisi kurulum işaretçisinden ayrı olarak manifest güveni, dosya kümesi, boyut, hash, şema ve aktivasyon tutarlılığını kontrol eder. Açarken tekrar kontrol eder; bozuk dosya açılmaz. Ağ kataloğu başarısızken yerel liste, açma, silme ve önceki sürüme dönme kullanılabilir. İndirme sonucu gerçek doğrulama yapılmadıysa “doğrulandı” demez. Bağlantı, zaman aşımı, alan, eski sürüm, sunucu, güven/bütünlük ve dosya hataları farklı sonraki adımla gösterilir.
- 2.928 OSM yer kaydı, iki şehir geometrisi, Türkçe arama/kategori ve prova korundu; kaynak, tarih ve test/saha ayrımı korunur. Paket açılışı seçilen şehri gösterir. Kritik telefon kaynak kontrolü 180 günü aşarsa doğrudan arama kapanır; dokunma anında ve ekrandayken yeniden kontrol edilir. Bu süre ürün korumasıdır, resmî güncellik veya saha güvenliği garantisi değildir.
- Kafile kapalı kalır; neden, çalışan çevrimdışı özellikler ve Rehber sekmesine dönüş açıklanır. Üyelik yoksa davet koduyla nasıl başlayacağı belirtilir. Sohbet/davet/şikâyet/engel/konum/push/silme altyapısı yeniden kurulmadı. Gerçek test projesi olmadan iki hesap/kafile veya bildirim teslimi kabul edilmedi.
- 18 Umre, 35 Hac, bir dua ve 55 ses kimliği sürüm/hash ile teslim paketine eşlendi. 54 sentetik dosya taslak; Arapça telbiye dosyası eksik. 324 boş dinî/dil/profil/hak/dinleme karar satırı var. Onaylı katalog kaydı için gerçek karar makbuzu ve belge özeti gerekir; değişen metin/profil/ses veya belge eski kabulü geçersiz kılar. Özel imzalı belgeler Git dışında tutulur; yazılım imzanın sahibini doğrulamaz.
- Android compile/target API 36, min API 28; iOS minimum 15 korunur. Normal Android Release ve imzalanan iOS Release içerik kapısına bağlıdır. Anahtar/credential yok. Teknik CI pilotu ve unsigned iOS derlemesi açıkça üretim kabulünden ayrıdır. Güncel resmî mağaza koşulları tek teslim paketinde kaynaklarıyla bulunur.

## Doğrulama ve gerçek sınırlar

Flutter 3.47.6 / Dart 3.13.5 ile kilitli bağımlılıklar kuruldu; lockfile değişmedi. Format ve analiz temiz; tam 219 Flutter testi, 57 Python testi ve 13 Node push çekirdek testi geçti. Yeni kontroller: mevcut Kıran/Hac yolculuk konumu ve işaretler, kayıt okuma hatası, kurulu dosya bozma/silme, açma öncesi tekrar kontrol, yanıltıcı indirme mesajı, ağsız hazırlık, 320 px/%200 yazı ve ses paketine doğrudan geçiş, kritik numara yaş sınırı, tam belge/sürüm/dosya özeti. Yedi Maestro YAML sözdizimi/politika kontrolünden geçti; bu statik kontrol cihaz sonucu değildir. Teknik demo AAC kontrolü geçti; insan sesi/onay değildir.

İlk tam Flutter koşusunda sistemde `libsqlite3.so` geliştirme bağlantısı olmadığı için SQLite kullanan testler başarısızdı. Sistemin gerçek `libsqlite3.so.0` dosyasını geçici test dizinine bağlayıp `LD_LIBRARY_PATH` ile tam tur tekrarlandı ve geçti; uygulama testi kaldırılmadı. Yeni hazırlık testinde gerçek dosya I/O fake async'ten ayrıldı; büyük yazıda kaydırma sonrası frame beklendi. Kritik numara testinde SelectableText'in ikinci Scrollable'ı yerine ana liste seçildi; süre sınırı assertion'ı korundu.

Başlangıçta PR #1 açık/taslak `8cb9c79`, PR #2 açık/taslak `f39d107` idi. PR #1 CI 38045635005 completed/success. PR #2 CI [38088628846](https://github.com/NeoTuck/kabe_hac/actions/runs/38088628846) completed/failure: Flutter, veritabanı, QA ve derlemeler başarılı; gerçek ekran JUnit/session sonucu Android API28/API35 **6/7**, Xcode16.4/iOS18.5 ve Xcode26.2/iOS26.2 **4/7**. Dört ZIP'in GitHub SHA-256 özeti eşleşti. Android prova akışı eski “Nasıl devam etmek istersin?” metnini bekliyordu; iki iOS akışında yeniden açılış sonrası Umre kartının yukarıda kaldığı UI hiyerarşisinde görüldü. Mevcut `Rehbere başla` semantiğiyle bekleme ve yeniden açılışta yukarı kaydırma eklendi. İçerik, harita çizim veya prova assertion'ı kaldırılmadı. Yeni native çalışma henüz kabul edilmemiştir.

Normal üretim gate'i gerçek evidence dizini olmadan exit 2, açık teknik pilot exit 0 verdi. Full preflight **blocked/158**, içerik gate **blocked/145**, MVP kapsam **blocked/546**: taslak içerik, eksik kayıt, hak/gerçek servis/cihaz/imza girdileri bilerek engellenir. Bunlar geçen kullanıcı testinin yerine konmaz. Son fiziksel uçak modu, TalkBack/VoiceOver, ses kesintisi, gerçek FCM/APNs, Auth/RLS/moderasyon/silme ve dağıtım kabulü yapılmadı.

Android yerel derleme sonucu ve son commit CI durumu aşağıda kaydedilmiştir. Linux ortamında Xcode olmadığından yeni iOS derlemesi yerelde yapılmadı.

## Depo ve CI kaydı

Uygulama kodu `a62806452a3474ca6f713c83bc8e1195e8444c93`, dosya ağacı `92d0399ee9fce0602974a9e394cb52df54bbe8f3`. Yerel ağacın 34 yeni/değişen blob'u ve altı değişmeden kopyalanmış çalışma dosyası GitHub nesneleriyle birebir eşleşti. Normal HTTPS Git gönderimi kimlik olmadığı için yapılamadı; yetkili GitHub bağlantısıyla commit oluşturulup `codex/mvp1-pilot` ref'i force kullanmadan ileri taşındı. PR #2 hedef dalına dahil olduğu için GitHub tarafından merged/closed gösteriliyor; PR #1 açık/taslak ve inceleme açıklaması güncel. `main` dalına birleştirme veya mağaza yayını yapılmadı. Yerel commit'ler yedek dalda korundu.

Yeni [CI 38090825147](https://github.com/NeoTuck/kabe_hac/actions/runs/38090825147) ilk kontrolde **in_progress**, conclusion yok. Uzun native işler beklenmedi. Bu belgeye sonraki kanıt commit'i eklendiğinde aynı uygulama kodu için sonuç ayrıca incelenmelidir. Yeni koşu geçmeden önceki başarısız native UI sonucu kapatılmış sayılmaz.

## Son yerel native kanıt

Aynı uygulama koduyla Android debug APK derlemesi geçti (410,2 s): Flutter 3.47.6, JDK 21, Android SDK 36, NDK 28.2.13676358. İlk denemelerde Gradle proxy/distribution hazırlığı ve bir eklentinin ihtiyaç duyduğu Android 35 platformu eksikti; geçici SDK/cache düzeltildi ve gerçek derleme tekrarlandı. Bunlar uygulama assertion'ı atlama veya başarısız derlemeyi geçti sayma değildir. CMake 3.22.1 tamamlandı. Firebase Core'un gelecekteki built-in Kotlin geçiş uyarısı ve bağımlılıkların deprecation uyarıları var; derleme başarılı, lockfile/dependency sürümleri değiştirilmedi.

APK **224.809.255 bayt**, SHA-256 `1b2564778817cf09a4fc09b60adae9ef057e1631ea63bc4e9889246f1fe1c561`. `aapt dump badging` compile/target **36**, minimum **28** doğruladı. `verify_production_assets.py` QA/teknik demo fixture'larının bu APK'da bulunmadığını doğruladı; araç adı üretim lisansı veya dinî kabul vermez. APK debug imzalı teknik inceleme eseridir; dağıtım anahtarı değildir. Yeni iOS derlemesi Linux'ta yapılmadı.

55 katalog ses kimliğinin mevcut **54** dosyası yeniden SHA-256, tek AAC stream ve `ffmpeg -xerror -err_detect explode` tam decode kontrolünden geçti. `A-P-U02.2-AR-01` kayıt dosyası yoktur. Bu kontrol telaffuz, dinleme, insan kökeni veya kullanım hakkı onayı değildir; tüm taslak durumlar korunur. Yeni CI 38090825147 son kontrolde halen **in_progress**; QA/veritabanı işleri başarılı, native kabul sonucu yok. Son kanıt commit'i yalnız bu belge, AGENTS ve tek teslim listesini günceller; uygulama kodu a628064 ile aynıdır.

## 11 Ekim yayın araştırması ve son native kanıt

[docs/39](39-yayin-arastirmasi-ve-paket-kontrolleri-2026-10-11.md) bu tarihli son durumdur. Baseline62f3a41 AndroidAPI28/API35 dokuz ekran ve54 gerçek paketli anlatımı geçti. İki iOS turu sekiz ekran/54 anlatım ile hız düğmesindeki tooltip birleşmesini gösterdi; düzeltme ve eski kodda kırmızı regresyon tamamlandı. Son234Flutter/75Python/format/analyze geçti. Yeni16KB/manifest/AAB CI kabulü açık; genel yayın, içerik/hak/canlı hizmet/cihaz/imza kabulü verilmedi. Önceki CI bekleme kayıtları tarihsel durumdur.

## 11 Ekim Kafile/AAB devam güncellemesi

[docs/40](40-kafile-filtre-ve-aab-devam-2026-10-11.md) son teknik teslimdir: sürümlü sunucu preposting filtresi, kalıcı rejected outbox/SQLite10 ve anlaşılır kaldırma akışı, gerçek AAB-derived APK hizalama denetimi uygulandı. Son238Flutter/82Python/137pgTAP/45SQL/13Node,format/analyze geçti. Baseline2a358c4 Android35 ve iOS18.5 dokuz uygulama +54 anlatım +probe geçti; API28 getconf ve16KB adbd setup hataları ölçüm/UID readback korunarak düzeltildi. Son native/iki yeni gerçek PostgreSQL yarışı açık; eski eksik preposting/AAB ifadeleri tarihsel durumdur.
